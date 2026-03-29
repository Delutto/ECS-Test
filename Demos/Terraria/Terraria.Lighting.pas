unit Terraria.Lighting;

{$mode objfpc}{$H+}

{ =============================================================================
  Terraria.Lighting — Cellular-Automata / Flood-Fill 2D Lighting
  =============================================================================

  ALGORITHM
  ─────────
  Multi-source BFS (Dijkstra-flavoured) operating on world-tile coordinates.

  1.  Every loaded tile is initialised to AmbientLight (R=G=B=Ambient).
  2.  SEEDING — two source types are enqueued at their maximum brightness:
        a) Sky columns: the tile at the global surface row (SY) of every
           column in the loaded area is seeded with (SkyR, SkyG, SkyB).
           Tiles strictly above the surface (pure sky) are set directly
           without going through BFS because they never change.
        b) Block emitters: any foreground tile whose ID appears in the
           emitter table (mushrooms, and any tile IDs the caller adds) is
           seeded with its configured RGB + brightness.
  3.  BFS PROPAGATION — each node (WX, WY, R, G, B) dequeued:
        •  For each of the four cardinal neighbours:
             falloff  ←  GetFalloff(neighbour_tile)   (air / decor / solid)
             newR/G/B ←  max(0, queued_value − falloff)
        •  If any channel of (newR,newG,newB) exceeds the channel currently
           stored at the neighbour, update the stored value and re-enqueue.
        •  Stale items (queued value < stored value) are silently discarded
           on dequeue — this keeps the queue bounded and correct.
  4.  The result is written into a hash table of TLightChunk objects that
      mirror the structure of TChunkManager's hash table.

  INTEGRATION
  ───────────
  •  Call ComputeLighting once after the initial stream and whenever the
     loaded set changes (e.g. after UpdateStreaming if LoadedCount changed).
  •  Pass the TLightMap pointer to TChunkRenderSystem.LightMap so the
     renderer can tint each tile by its computed (R,G,B) light value.

  SETTINGS (TLightSettings)
  ─────────────────────────
  All parameters are exposed and can be edited live via TGenEditor's
  new Lighting section.  DefaultLightSettings provides sane Terraria-like
  starting values.
  ============================================================================= }

interface

uses
   SysUtils, Math,
   Terraria.Common,
   Terraria.WorldChunk,
   Terraria.ChunkManager;

{ ---------------------------------------------------------------------------
  TLightSettings
--------------------------------------------------------------------------- }
type
   PLightSettings = ^TLightSettings;

   TLightSettings = record
      Enabled: boolean;

      { Sky light colour at the surface row }
      SkyR, SkyG, SkyB: byte;

      { Minimum brightness everywhere (prevents total darkness) }
      AmbientLight: byte;

      { Light attenuation per tile traversed }
      FalloffAir: byte;   { through air tiles }
      FalloffSolid: byte;   { through solid terrain }
      FalloffDecor: byte;   { through vegetation / decor tiles }

      { Mushroom (cave) emitter }
      MushroomBrightness: byte;
      MushroomR, MushroomG, MushroomB: byte;

      { Future generic emitter slot (tile ID + colour) }
      EmitterTileID: byte;
      EmitterBrightness: byte;
      EmitterR, EmitterG, EmitterB: byte;

      { If true, background (wall) tiles receive 60 % of the light value
        that the foreground at the same position has.  Purely visual. }
      DimBackground: boolean;
      BackgroundDimFactor: Single;   { 0..1, default 0.55 }
   end;

function DefaultLightSettings: TLightSettings;

{ ---------------------------------------------------------------------------
  Light storage
--------------------------------------------------------------------------- }
type
   TRGBLight = packed record
      R, G, B: byte;
   end;

const
   LIGHT_MAX = 255;

type
   TLightChunkRow = array[0..CHUNK_TILES_W - 1] of TRGBLight;
   TLightChunkData = array[0..CHUNK_TILES_H - 1] of TLightChunkRow;

   TLightChunk = class
   public
      Data: TLightChunkData;
      CX, CY: Integer;
      NextInBucket: TLightChunk;
      constructor Create(ACX, ACY: Integer);
      procedure Fill(AR, AG, AB: byte);
      function GetLight(LX, LY: Integer): TRGBLight; inline;
      procedure SetLight(LX, LY: Integer; const ALight: TRGBLight); inline;
   end;

{ ---------------------------------------------------------------------------
  TLightMap
--------------------------------------------------------------------------- }
type
   TLightQueueItem = packed record
      WX, WY: smallint;
      R, G, B: byte;
      _pad: byte;
   end;

   TLightMap = class
   private
      FBuckets: array[0..LM_HASH_BUCKETS - 1] of TLightChunk;
      FSettings: TLightSettings;
      FManager: TChunkManager;

      { BFS queue (circular) }
      FQueue: array of TLightQueueItem;
      FQHead, FQTail: Integer;

      function HashKey(ACX, ACY: Integer): Integer; inline;
      function FindChunk(ACX, ACY: Integer): TLightChunk;
      function GetOrCreateChunk(ACX, ACY: Integer): TLightChunk;
      procedure SetLightWorld(WX, WY: Integer; const L: TRGBLight);
      function GetFalloff(WX, WY: Integer): byte;
      procedure Enqueue(WX, WY: Integer; AR, AG, AB: byte);
      procedure BFSPropagate;
      procedure FreeAllChunks;
   public
      constructor Create(AManager: TChunkManager);
      destructor Destroy; override;

      { Full recompute for all currently loaded chunks }
      procedure ComputeLighting;

      { Frees all light chunks (call before RebuildWorld) }
      procedure Clear;

      { Query }
      function GetLight(WX, WY: Integer): TRGBLight;
      { Returns max(R,G,B) as a single byte (useful for monochrome tint) }
      function GetLightByte(WX, WY: Integer): byte; inline;

      property Settings: TLightSettings read FSettings write FSettings;
   end;

implementation

{ =============================================================================
  DefaultLightSettings
  ============================================================================= }

function DefaultLightSettings: TLightSettings;
begin
   Result.Enabled := True;
   Result.SkyR := 255;
   Result.SkyG := 240;
   Result.SkyB := 200;
   Result.AmbientLight := 8;
   Result.FalloffAir := 6;
   Result.FalloffSolid := 42;
   Result.FalloffDecor := 14;
   Result.MushroomBrightness := 110;
   Result.MushroomR := 80;
   Result.MushroomG := 200;
   Result.MushroomB := 255;
   Result.EmitterTileID := 0;
   Result.EmitterBrightness := 0;
   Result.EmitterR := 255;
   Result.EmitterG := 200;
   Result.EmitterB := 80;
   Result.DimBackground := True;
   Result.BackgroundDimFactor := 0.55;
end;

{ =============================================================================
  TLightChunk
  ============================================================================= }

constructor TLightChunk.Create(ACX, ACY: Integer);
begin
   inherited Create;
   CX := ACX;
   CY := ACY;
   NextInBucket := nil;
   FillChar(Data, SizeOf(Data), 0);
end;

procedure TLightChunk.Fill(AR, AG, AB: byte);
var
   LX, LY: Integer;
begin
   for LY := 0 to CHUNK_TILES_H - 1 do
      for LX := 0 to CHUNK_TILES_W - 1 do
      begin
         Data[LY][LX].R := AR;
         Data[LY][LX].G := AG;
         Data[LY][LX].B := AB;
      end;
end;

function TLightChunk.GetLight(LX, LY: Integer): TRGBLight;
begin
   Result := Data[LY][LX];
end;

procedure TLightChunk.SetLight(LX, LY: Integer; const ALight: TRGBLight);
begin
   Data[LY][LX] := ALight;
end;

{ =============================================================================
  TLightMap — private helpers
  ============================================================================= }

function TLightMap.HashKey(ACX, ACY: Integer): Integer;
begin
   Result := ((ACX * LM_HASH_P1) xor (ACY * LM_HASH_P2)) and (LM_HASH_BUCKETS - 1);
end;

function TLightMap.FindChunk(ACX, ACY: Integer): TLightChunk;
var
   C: TLightChunk;
begin
   C := FBuckets[HashKey(ACX, ACY)];
   while Assigned(C) do
   begin
      if (C.CX = ACX) and (C.CY = ACY) then
      begin
         Result := C;
         Exit;
      end;
      C := C.NextInBucket;
   end;
   Result := nil;
end;

function TLightMap.GetOrCreateChunk(ACX, ACY: Integer): TLightChunk;
var
   Bkt: Integer;
   C: TLightChunk;
begin
   C := FindChunk(ACX, ACY);
   if Assigned(C) then
   begin
      Result := C;
      Exit;
   end;
   Bkt := HashKey(ACX, ACY);
   C := TLightChunk.Create(ACX, ACY);
   C.NextInBucket := FBuckets[Bkt];
   FBuckets[Bkt] := C;
   Result := C;
end;

procedure TLightMap.SetLightWorld(WX, WY: Integer; const L: TRGBLight);
var
   CX, CY, LX, LY: Integer;
   Chunk: TLightChunk;
begin
   CX := TChunkManager.TileToChunkX(WX);
   CY := TChunkManager.TileToChunkY(WY);
   LX := TChunkManager.TileToLocalX(WX);
   LY := TChunkManager.TileToLocalY(WY);
   Chunk := FindChunk(CX, CY);
   if Assigned(Chunk) then
      Chunk.SetLight(LX, LY, L);
end;

function TLightMap.GetFalloff(WX, WY: Integer): byte;
var
   Tile: byte;
begin
   Tile := FManager.GetFG(WX, WY);
   if Tile = TILE_AIR then
      Result := FSettings.FalloffAir
   else
   if Tile >= TILE_SHRUB then
      Result := FSettings.FalloffDecor
   else
      Result := FSettings.FalloffSolid;
end;

procedure TLightMap.Enqueue(WX, WY: Integer; AR, AG, AB: byte);
var
   NextTail: Integer;
begin
   NextTail := (FQTail + 1) mod LM_QUEUE_CAP;
   if NextTail = FQHead then
      Exit;  { queue full — silently drop (rare edge case) }
   FQueue[FQTail].WX := WX;
   FQueue[FQTail].WY := WY;
   FQueue[FQTail].R := AR;
   FQueue[FQTail].G := AG;
   FQueue[FQTail].B := AB;
   FQTail := NextTail;
end;

{ ---------------------------------------------------------------------------
  BFSPropagate — core flood fill
  Processes every item in the queue.  For each neighbour:
    new_channel = queued_channel - falloff(neighbour)
  If any new_channel > existing stored channel, update storage and re-enqueue.
  Stale items (queued value already superseded by a brighter source) are
  discarded cheaply on dequeue via the "still better?" check.
--------------------------------------------------------------------------- }

procedure TLightMap.BFSPropagate;
const
   DX: array[0..3] of smallint = (-1, 1, 0, 0);
   DY: array[0..3] of smallint = (0, 0, -1, 1);
var
   Item: TLightQueueItem;
   D, NWX, NWY: Integer;
   Falloff, ExR, ExG, ExB: byte;
   NR, NG, NB: Integer;
   Existing: TRGBLight;
   Stored: TRGBLight;
   NCX, NCY, NLX, NLY: Integer;
   NChunk: TLightChunk;
   NL: TRGBLight;
   Improved: boolean;
begin
   while FQHead <> FQTail do
   begin
      Item := FQueue[FQHead];
      FQHead := (FQHead + 1) mod LM_QUEUE_CAP;

      { Discard stale items }
      Stored := GetLight(Item.WX, Item.WY);
      if (Item.R < Stored.R) or (Item.G < Stored.G) or (Item.B < Stored.B) then
      begin
         { Only skip if ALL channels are not better — partial improvement
           from a different source direction must still propagate. }
         if (Item.R <= Stored.R) and (Item.G <= Stored.G) and (Item.B <= Stored.B) then
            Continue;
      end;

      for D := 0 to 3 do
      begin
         NWX := Item.WX + DX[D];
         NWY := Item.WY + DY[D];

         { Look up the neighbour's light chunk; skip if not loaded }
         NCX := TChunkManager.TileToChunkX(NWX);
         NCY := TChunkManager.TileToChunkY(NWY);
         NChunk := FindChunk(NCX, NCY);
         if not Assigned(NChunk) then
            Continue;

         Falloff := GetFalloff(NWX, NWY);

         NR := Integer(Item.R) - Falloff;
         NG := Integer(Item.G) - Falloff;
         NB := Integer(Item.B) - Falloff;
         if NR < 0 then
            NR := 0;
         if NG < 0 then
            NG := 0;
         if NB < 0 then
            NB := 0;
         if (NR = 0) and (NG = 0) and (NB = 0) then
            Continue;

         NLX := TChunkManager.TileToLocalX(NWX);
         NLY := TChunkManager.TileToLocalY(NWY);
         Existing := NChunk.GetLight(NLX, NLY);

         Improved := (NR > Existing.R) or (NG > Existing.G) or (NB > Existing.B);
         if not Improved then
            Continue;

         NL.R := byte(Max(NR, Integer(Existing.R)));
         NL.G := byte(Max(NG, Integer(Existing.G)));
         NL.B := byte(Max(NB, Integer(Existing.B)));
         NChunk.SetLight(NLX, NLY, NL);
         Enqueue(NWX, NWY, NL.R, NL.G, NL.B);
      end;
   end;
end;

procedure TLightMap.FreeAllChunks;
var
   I: Integer;
   C, Next: TLightChunk;
begin
   for I := 0 to LM_HASH_BUCKETS - 1 do
   begin
      C := FBuckets[I];
      while Assigned(C) do
      begin
         Next := C.NextInBucket;
         C.Free;
         C := Next;
      end;
      FBuckets[I] := nil;
   end;
end;

{ =============================================================================
  TLightMap — public
  ============================================================================= }

constructor TLightMap.Create(AManager: TChunkManager);
begin
   inherited Create;
   FManager := AManager;
   FSettings := DefaultLightSettings;
   FillChar(FBuckets, SizeOf(FBuckets), 0);
   SetLength(FQueue, LM_QUEUE_CAP);
   FQHead := 0;
   FQTail := 0;
end;

destructor TLightMap.Destroy;
begin
   FreeAllChunks;
   inherited;
end;

procedure TLightMap.Clear;
begin
   FreeAllChunks;
   FQHead := 0;
   FQTail := 0;
end;

{ ---------------------------------------------------------------------------
  ComputeLighting — full recompute for all currently loaded chunks.

  Pass 1 — allocate / reset light chunks.
  Pass 2 — seed sky columns (above surface → full sky; at surface → queue).
  Pass 3 — seed block emitters.
  Pass 4 — BFS propagation.
--------------------------------------------------------------------------- }

procedure TLightMap.ComputeLighting;
var
   AllChunks: array[0..MAX_ALL_CHUNKS - 1] of TWorldChunk;
   ChunkCount, I: Integer;
   Chunk: TWorldChunk;
   LChunk: TLightChunk;
   LX, LY, WX, WY, SY, WYTop: Integer;
   Amb: byte;
   SkyLight: TRGBLight;
   EmitLight: TRGBLight;
   TileID: byte;
   EmBright: byte;
begin
   if not FSettings.Enabled then
      Exit;

   { Collect all loaded world chunks }
   ChunkCount := FManager.GetLoadedInRange(-10000, WORLD_MIN_CY - 1, 10000, WORLD_MAX_CY + 1, AllChunks, MAX_ALL_CHUNKS);
   if ChunkCount = 0 then
      Exit;

   { Free ALL existing light chunks before recomputing.
     This removes stale data for world chunks that have been unloaded since
     the last ComputeLighting call.  Without this, light values from old
     chunk positions bleed onto newly-loaded chunks that occupy the same
     hash bucket or world coordinates, causing shadow artefacts on surface
     tiles when the camera pans horizontally. }
   FreeAllChunks;

   Amb := FSettings.AmbientLight;
   SkyLight.R := FSettings.SkyR;
   SkyLight.G := FSettings.SkyG;
   SkyLight.B := FSettings.SkyB;

   { Reset BFS queue }
   FQHead := 0;
   FQTail := 0;

   { ── Pass 1: reset light chunks to ambient ── }
   for I := 0 to ChunkCount - 1 do
   begin
      Chunk := AllChunks[I];
      LChunk := GetOrCreateChunk(Chunk.CX, Chunk.CY);
      LChunk.Fill(Amb, Amb, Amb);
   end;

   { ── Pass 2: sky light ── }
   for I := 0 to ChunkCount - 1 do
   begin
      Chunk := AllChunks[I];
      LChunk := FindChunk(Chunk.CX, Chunk.CY);
      { World Y of top row of this chunk }
      WYTop := TChunkManager.ChunkToTileY(Chunk.CY);
      for LX := 0 to CHUNK_TILES_W - 1 do
      begin
         WX := TChunkManager.ChunkToTileX(Chunk.CX) + LX;
         SY := FManager.GetSurfaceY(WX);
         { For every row in this chunk column }
         for LY := 0 to CHUNK_TILES_H - 1 do
         begin
            WY := WYTop + LY;
            if WY < SY then
            begin
               { Pure sky — set directly, do NOT enqueue (no propagation
                 needed for tiles that are already at max brightness) }
               LChunk.SetLight(LX, LY, SkyLight);
            end
            else
            if WY = SY then
            begin
               { Surface row: set to sky brightness and seed BFS }
               LChunk.SetLight(LX, LY, SkyLight);
               Enqueue(WX, WY, SkyLight.R, SkyLight.G, SkyLight.B);
            end;
            { Below surface: already at ambient, BFS will update later }
         end;
      end;
   end;

   { ── Pass 3: block emitters ── }
   for I := 0 to ChunkCount - 1 do
   begin
      Chunk := AllChunks[I];
      LChunk := FindChunk(Chunk.CX, Chunk.CY);
      for LY := 0 to CHUNK_TILES_H - 1 do
         for LX := 0 to CHUNK_TILES_W - 1 do
         begin
            TileID := Chunk.GetFG(LX, LY);
            EmBright := 0;

            if TileID = TILE_MUSHROOM then
            begin
               EmBright := FSettings.MushroomBrightness;
               EmitLight.R := FSettings.MushroomR;
               EmitLight.G := FSettings.MushroomG;
               EmitLight.B := FSettings.MushroomB;
            end
            else
            if (FSettings.EmitterTileID > 0) and (TileID = FSettings.EmitterTileID) then
            begin
               EmBright := FSettings.EmitterBrightness;
               EmitLight.R := FSettings.EmitterR;
               EmitLight.G := FSettings.EmitterG;
               EmitLight.B := FSettings.EmitterB;
            end;

            if EmBright = 0 then
               Continue;

            WX := TChunkManager.ChunkToTileX(Chunk.CX) + LX;
            WY := TChunkManager.ChunkToTileY(Chunk.CY) + LY;

            EmitLight.R := byte(Min(255, Round(EmitLight.R * EmBright / 255)));
            EmitLight.G := byte(Min(255, Round(EmitLight.G * EmBright / 255)));
            EmitLight.B := byte(Min(255, Round(EmitLight.B * EmBright / 255)));

            { Only update if this emitter is brighter than current value }
            if (EmitLight.R > LChunk.Data[LY][LX].R) or (EmitLight.G > LChunk.Data[LY][LX].G) or (EmitLight.B > LChunk.Data[LY][LX].B) then
            begin
               LChunk.SetLight(LX, LY, EmitLight);
               Enqueue(WX, WY, EmitLight.R, EmitLight.G, EmitLight.B);
            end;
         end;
   end;

   { ── Pass 4: BFS propagation ── }
   BFSPropagate;
end;

{ ---------------------------------------------------------------------------
  Query
--------------------------------------------------------------------------- }

function TLightMap.GetLight(WX, WY: Integer): TRGBLight;
var
   CX, CY, LX, LY: Integer;
   Chunk: TLightChunk;
   Amb: byte;
begin
   CX := TChunkManager.TileToChunkX(WX);
   CY := TChunkManager.TileToChunkY(WY);
   Chunk := FindChunk(CX, CY);
   if not Assigned(Chunk) then
   begin
      Amb := FSettings.AmbientLight;
      Result.R := Amb;
      Result.G := Amb;
      Result.B := Amb;
      Exit;
   end;
   LX := TChunkManager.TileToLocalX(WX);
   LY := TChunkManager.TileToLocalY(WY);
   Result := Chunk.GetLight(LX, LY);
end;

function TLightMap.GetLightByte(WX, WY: Integer): byte;
var
   L: TRGBLight;
begin
   L := GetLight(WX, WY);
   Result := byte(Max(Integer(L.R), Max(Integer(L.G), Integer(L.B))));
end;

end.
