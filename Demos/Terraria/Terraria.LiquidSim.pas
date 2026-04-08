unit Terraria.LiquidSim;

{$mode objfpc}{$H+}

{ =============================================================================
  Terraria.LiquidSim — Adapted from Terraria.Water (working implementation)

  DESIGN
  ───────
  Two independent TLiqLevelMap instances share the same simulation algorithm:
    WaterMap — ticks at 20 Hz, FLOW_RATE = 5
    LavaMap  — ticks at  4 Hz, FLOW_RATE = 1

  Each TLiqLevelMap stores per-tile byte values in [0..LIQ_MAX] (= 0..200).
  Liquid is stored SEPARATELY from the FG tile grid — no TILE_WATER / TILE_LAVA
  is ever written into TWorldChunk.FForeground. This avoids every conflict with
  the terrain and decoration pipeline.

  SIMULATION (adapted directly from Terraria.Water.TWaterMap.SimStep)
  ────────────────────────────────────────────────────────────────────
  For each loaded chunk, bottom-to-top, alternating L→R / R→L:

    FALL:     transfer Min(level, LIQ_MAX − below_level) downward (full dump)
    SPREAD:   transfer Min((diff÷2), FLOW_RATE) sideways (half-diff, capped)
    PRESSURE: when level ≥ LIQ_PRESSURE_THRESH, push Min(excess, FLOW_RATE) up

  PASSABILITY
  ────────────
  Only solid terrain tiles (1..TILE_SHRUB-1 = TILE_DIRT..TILE_ICE) block liquid.
  AIR (0), decoration tiles (TILE_SHRUB..), are passable.
  Built once per chunk per step into TPassCache for O(1) lookup.

  LAVA–WATER REACTION
  ────────────────────
  After each pair of water+lava ticks, cells where BOTH levels > 0 turn the
  lava level to 0 and place TILE_STONE in the FG grid.

  RENDERING
  ──────────
  TLiquidRenderer reads WaterMap.GetLevel / LavaMap.GetLevel for each tile.
  Render height (pixels) = Round(level * TILE_SIZE / LIQ_MAX).
  ============================================================================= }

interface

uses
   SysUtils, Math,
   Terraria.Common,
   Terraria.WorldChunk,
   Terraria.ChunkManager;

const
   LIQ_MAX = 200;            { maximum level per cell                    }
   LIQ_PRESSURE_THRESH = 550;{ level at which liquid rises upward        }
   LIQ_MIN_FLOW = 1;         { minimum transfer to avoid micro-flows     }
   WATER_FLOW_RATE = 1000;    { max horizontal transfer per step (water)  }
   LAVA_FLOW_RATE = 500;      { max horizontal transfer per step (lava)   }
   WATER_TICK_RATE: Single = 1.0 / 80.0;{ 30 Hz (was 20)                 }
   LAVA_TICK_RATE: Single = 1.0 / 24.0;  { 6 Hz  (was 4)                  }

   { Drain: partial tiles (0 < level < LIQ_MAX) are removed after 10 s.
     Counter increments ONLY when a cell is STABLE (level unchanged).
     WATER_DRAIN_TICKS = 10 s × 30 Hz = 255 (byte max, ~8.5 s min).
     LAVA_DRAIN_TICKS  = 10 s ×  6 Hz =  60. }
   WATER_DRAIN_TICKS = 555;
   LAVA_DRAIN_TICKS = 120;
   LIQ_BUCKETS = 2048;
   LIQ_P1 = 73856093;
   LIQ_P2 = 19349669;

type
   TLiqPassCache = array[0..CHUNK_TILES_H - 1, 0..CHUNK_TILES_W - 1] of boolean;
   { Snapshot of one chunk's level data; used to detect per-cell movement. }
   TLiqDataSnap = array[0..CHUNK_TILES_H - 1, 0..CHUNK_TILES_W - 1] of byte;

   { ── Per-chunk level storage ─────────────────────────────────────────── }
   TLiqLevelChunk = class
   public
      Data: array[0..CHUNK_TILES_H - 1, 0..CHUNK_TILES_W - 1] of byte;
      { Per-cell counter: how many sim ticks this cell has had 0 < level < LIQ_MAX.
        When it reaches the drain threshold the cell is cleared. }
      DrainAge: array[0..CHUNK_TILES_H - 1, 0..CHUNK_TILES_W - 1] of byte;
      CX, CY: Integer;
      Next: TLiqLevelChunk;   { intrusive linked list in hash bucket }
      HasLiquid: boolean;

      constructor Create(ACX, ACY: Integer);
      function GetLvl(LX, LY: Integer): byte; inline;
      procedure SetLvl(LX, LY: Integer; V: byte); inline;
      procedure UpdateFlag;
   end;

   { ── Hash-table of chunks + simulation ───────────────────────────────── }
   TLiqLevelMap = class
   private
      FBuckets: array[0..LIQ_BUCKETS - 1] of TLiqLevelChunk;
      FManager: TChunkManager;

      function HashKey(ACX, ACY: Integer): Integer; inline;
      function GetOrCreate(ACX, ACY: Integer): TLiqLevelChunk;
      procedure FreeAll;
   public
      { Public chunk lookup — returns nil if no liquid data for this chunk. }
      function FindChunk(ACX, ACY: Integer): TLiqLevelChunk;
      constructor Create(AManager: TChunkManager);
      destructor Destroy; override;

      function GetLevel(WX, WY: Integer): byte;
      procedure SetLevel(WX, WY: Integer; ALevel: byte);
      procedure Clear;

      { One simulation step.
        AFlowRate       : max horizontal transfer per step.
        ALeftToRight    : sweep direction, alternated every tick.
        ADrainThreshold : ticks a partial cell must persist before removal
                          (0 = drain disabled). }
      procedure SimStep(AFlowRate: Integer; ALeftToRight: boolean; ADrainThreshold: byte = 0);
   end;

   { ── Top-level simulator — owns both level maps ──────────────────────── }
   TLiquidSimulator = class
   private
      FManager: TChunkManager;
      FWater: TLiqLevelMap;
      FLava: TLiqLevelMap;
      FWaterAccum: Single;
      FLavaAccum: Single;
      FParity: Integer;   { 0 = L→R tick, 1 = R→L tick }

      { Replace lava cells that touch water with TILE_STONE. }
      procedure ProcessReactions;
   public
      constructor Create(AManager: TChunkManager);
      destructor Destroy; override;

      { Call every frame from TWorldScene.Update. }
      procedure Update(ADelta: Single);

      { Place liquid at a world-tile position (level = LIQ_MAX = full). }
      procedure PlaceWater(WX, WY: Integer; ALevel: Integer = LIQ_MAX);
      procedure PlaceLava(WX, WY: Integer; ALevel: Integer = LIQ_MAX);

      { Discard all liquid data (call before RebuildWorld). }
      procedure Clear;

      property WaterMap: TLiqLevelMap read FWater;
      property LavaMap: TLiqLevelMap read FLava;
   end;

{ Helper used by TLiqLevelMap and TLiquidRenderer. }
function IsPassableForLiquid(ATile: byte): boolean; inline;

implementation

{ =============================================================================
  IsPassableForLiquid
  Only solid TERRAIN tiles (1..TILE_SHRUB-1 = TILE_DIRT..TILE_ICE) block liquid.
  ============================================================================= }
function IsPassableForLiquid(ATile: byte): boolean;
begin
   Result := (ATile = TILE_AIR) or (ATile >= TILE_SHRUB);
end;

{ =============================================================================
  TLiqLevelChunk
  ============================================================================= }

constructor TLiqLevelChunk.Create(ACX, ACY: Integer);
begin
   inherited Create;
   CX := ACX;
   CY := ACY;
   Next := nil;
   HasLiquid := False;
   FillChar(Data, SizeOf(Data), 0);
   FillChar(DrainAge, SizeOf(DrainAge), 0);
end;

function TLiqLevelChunk.GetLvl(LX, LY: Integer): byte;
begin
   if (LX >= 0) and (LX < CHUNK_TILES_W) and (LY >= 0) and (LY < CHUNK_TILES_H) then
      Result := Data[LY][LX]
   else
      Result := 0;
end;

procedure TLiqLevelChunk.SetLvl(LX, LY: Integer; V: byte);
begin
   if (LX >= 0) and (LX < CHUNK_TILES_W) and (LY >= 0) and (LY < CHUNK_TILES_H) then
   begin
      Data[LY][LX] := V;
      if V > 0 then
         HasLiquid := True;
   end;
end;

procedure TLiqLevelChunk.UpdateFlag;
var
   LX, LY: Integer;
begin
   HasLiquid := False;
   for LY := 0 to CHUNK_TILES_H - 1 do
      for LX := 0 to CHUNK_TILES_W - 1 do
         if Data[LY][LX] > 0 then
         begin
            HasLiquid := True;
            Exit;
         end;
end;

{ =============================================================================
  TLiqLevelMap — private
  ============================================================================= }

function TLiqLevelMap.HashKey(ACX, ACY: Integer): Integer;
begin
   Result := ((ACX * LIQ_P1) xor (ACY * LIQ_P2)) and (LIQ_BUCKETS - 1);
   if Result < 0 then
      Result := Result + LIQ_BUCKETS;
end;

function TLiqLevelMap.FindChunk(ACX, ACY: Integer): TLiqLevelChunk;
var
   C: TLiqLevelChunk;
begin
   C := FBuckets[HashKey(ACX, ACY)];
   while Assigned(C) do
   begin
      if (C.CX = ACX) and (C.CY = ACY) then
      begin
         Result := C;
         Exit;
      end;
      C := C.Next;
   end;
   Result := nil;
end;

function TLiqLevelMap.GetOrCreate(ACX, ACY: Integer): TLiqLevelChunk;
var
   Bkt: Integer;
   C: TLiqLevelChunk;
begin
   C := FindChunk(ACX, ACY);
   if Assigned(C) then
   begin
      Result := C;
      Exit;
   end;
   Bkt := HashKey(ACX, ACY);
   C := TLiqLevelChunk.Create(ACX, ACY);
   C.Next := FBuckets[Bkt];
   FBuckets[Bkt] := C;
   Result := C;
end;

procedure TLiqLevelMap.FreeAll;
var
   I: Integer;
   C, N: TLiqLevelChunk;
begin
   for I := 0 to LIQ_BUCKETS - 1 do
   begin
      C := FBuckets[I];
      while Assigned(C) do
      begin
         N := C.Next;
         C.Free;
         C := N;
      end;
      FBuckets[I] := nil;
   end;
end;

{ =============================================================================
  TLiqLevelMap — public
  ============================================================================= }

constructor TLiqLevelMap.Create(AManager: TChunkManager);
begin
   inherited Create;
   FManager := AManager;
   FillChar(FBuckets, SizeOf(FBuckets), 0);
end;

destructor TLiqLevelMap.Destroy;
begin
   FreeAll;
   inherited;
end;

function TLiqLevelMap.GetLevel(WX, WY: Integer): byte;
var
   C: TLiqLevelChunk;
begin
   C := FindChunk(TChunkManager.TileToChunkX(WX), TChunkManager.TileToChunkY(WY));
   if Assigned(C) then
      Result := C.GetLvl(TChunkManager.TileToLocalX(WX), TChunkManager.TileToLocalY(WY))
   else
      Result := 0;
end;

procedure TLiqLevelMap.SetLevel(WX, WY: Integer; ALevel: byte);
var
   C: TLiqLevelChunk;
begin
   C := GetOrCreate(TChunkManager.TileToChunkX(WX), TChunkManager.TileToChunkY(WY));
   C.SetLvl(TChunkManager.TileToLocalX(WX), TChunkManager.TileToLocalY(WY), ALevel);
end;

procedure TLiqLevelMap.Clear;
begin
   FreeAll;
end;

{ =============================================================================
  TLiqLevelMap.SimStep
  ─────────────────────────────────────────────────────────────────────────────
  Adapted directly from Terraria.Water.TWaterMap.SimStep.

  For every loaded chunk that HasLiquid:
    1. Build pass-cache from FG tile passability.
    2. Bottom-to-top, L→R or R→L:
         FALL:     dump Min(level, capacity_below) downward.
         SPREAD:   transfer Min((self−neighbor)÷2, AFlowRate) sideways (both sides).
         PRESSURE: when level ≥ LIQ_PRESSURE_THRESH, push excess upward.
    3. UpdateFlag.

  Chunk-boundary cells look into the adjacent TWaterChunk (or TWorldChunk FG
  for passability when the liquid chunk does not exist).
  ============================================================================= }
procedure TLiqLevelMap.SimStep(AFlowRate: Integer; ALeftToRight: boolean; ADrainThreshold: byte);
const
   MAX_CHUNKS = 512;
var
   AllChunks: array[0..MAX_CHUNKS - 1] of TWorldChunk;
   LiqChunks: array[0..MAX_CHUNKS - 1] of TLiqLevelChunk;
   ChunkCount, I, LX, LY: Integer;
   WC, WCUp, WCDn, WCLt, WCRt: TLiqLevelChunk;
   TChunk: TWorldChunk;
   Pass: TLiqPassCache;
   Snap: TLiqDataSnap;   { snapshot of Data before this tick, for drain }
   Level, NeighLevel, Cap, Diff, Half, Move: Integer;
   PUp, PDn, PLt, PRt: boolean;
   LUp, LDn, LLt, LRt: Integer;
   BX, BY, LastCol, LastRow: Integer;
begin
   ChunkCount := FManager.GetLoadedInRange(-10000, WORLD_MIN_CY - 1, 10000, WORLD_MAX_CY + 1, AllChunks, MAX_CHUNKS);
   if ChunkCount = 0 then
      Exit;

   for I := 0 to ChunkCount - 1 do
      LiqChunks[I] := FindChunk(AllChunks[I].CX, AllChunks[I].CY);

   LastCol := CHUNK_TILES_W - 1;
   LastRow := CHUNK_TILES_H - 1;

   for I := 0 to ChunkCount - 1 do
   begin
      WC := LiqChunks[I];
      if (not Assigned(WC)) or (not WC.HasLiquid) then
         Continue;

      TChunk := AllChunks[I];
      BX := TChunkManager.ChunkToTileX(TChunk.CX);
      BY := TChunkManager.ChunkToTileY(TChunk.CY);

      { Build pass cache for this chunk }
      for LY := 0 to LastRow do
         for LX := 0 to LastCol do
            Pass[LY][LX] := IsPassableForLiquid(TChunk.GetFG(LX, LY));

      WCUp := FindChunk(TChunk.CX, TChunk.CY - 1);
      WCDn := FindChunk(TChunk.CX, TChunk.CY + 1);
      WCLt := FindChunk(TChunk.CX - 1, TChunk.CY);
      WCRt := FindChunk(TChunk.CX + 1, TChunk.CY);

      { Snapshot level data before this tick so we can detect per-cell movement.
        Cells whose level changes this tick are "still flowing" — their drain
        timer is reset so only genuinely stable partial tiles get drained. }
      if ADrainThreshold > 0 then
         System.Move(WC.Data, Snap, SizeOf(Snap));

      for LY := LastRow downto 0 do
      begin
         if ALeftToRight then
         begin
            for LX := 0 to LastCol do
            begin
               Level := WC.Data[LY][LX];
               if (Level = 0) or (not Pass[LY][LX]) then
                  Continue;

               { ── Fall ─────────────────────────────────────────────── }
               if LY < LastRow then
               begin
                  PDn := Pass[LY + 1][LX];
                  LDn := WC.Data[LY + 1][LX];
               end
               else
               if Assigned(WCDn) then
               begin
                  PDn := IsPassableForLiquid(FManager.GetFG(BX + LX, BY + CHUNK_TILES_H));
                  LDn := WCDn.Data[0][LX];
               end
               else
               begin
                  PDn := IsPassableForLiquid(FManager.GetFG(BX + LX, BY + CHUNK_TILES_H));
                  LDn := 0;
               end;

               if PDn then
               begin
                  Move := Min(Level, LIQ_MAX - LDn);
                  if Move >= LIQ_MIN_FLOW then
                  begin
                     WC.Data[LY][LX] := byte(Level - Move);
                     if LY < LastRow then
                        WC.Data[LY + 1][LX] := byte(LDn + Move)
                     else
                     if Assigned(WCDn) then
                     begin
                        WCDn.Data[0][LX] := byte(LDn + Move);
                        WCDn.HasLiquid := True;
                     end
                     else
                     if IsPassableForLiquid(FManager.GetFG(BX + LX, BY + CHUNK_TILES_H)) then
                     begin
                       { Neighbour world chunk is loaded but has no liquid chunk yet.
                         Create it on demand so cross-boundary flow is not lost. }
                        WCDn := GetOrCreate(TChunk.CX, TChunk.CY + 1);
                        WCDn.Data[0][LX] := byte(LDn + Move);
                        WCDn.HasLiquid := True;
                     end;
                     Level := Level - Move;
                  end;
               end;

               { ── Spread left ──────────────────────────────────────── }
               if Level > 0 then
               begin
                  if LX > 0 then
                  begin
                     PLt := Pass[LY][LX - 1];
                     LLt := WC.Data[LY][LX - 1];
                  end
                  else
                  if Assigned(WCLt) then
                  begin
                     PLt := IsPassableForLiquid(FManager.GetFG(BX - 1, BY + LY));
                     LLt := WCLt.Data[LY][LastCol];
                  end
                  else
                  begin
                     PLt := IsPassableForLiquid(FManager.GetFG(BX - 1, BY + LY));
                     LLt := 0;
                  end;

                  if PLt then
                  begin
                     Diff := Level - LLt;
                     if Diff > 1 then
                     begin
                        Half := Min(Diff div 2, AFlowRate);
                        if Half >= LIQ_MIN_FLOW then
                        begin
                           WC.Data[LY][LX] := byte(Level - Half);
                           if LX > 0 then
                              WC.Data[LY][LX - 1] := byte(LLt + Half)
                           else
                           if Assigned(WCLt) then
                           begin
                              WCLt.Data[LY][LastCol] := byte(LLt + Half);
                              WCLt.HasLiquid := True;
                           end
                           else
                           if IsPassableForLiquid(FManager.GetFG(BX - 1, BY + LY)) then
                           begin
                             { Neighbour world chunk is loaded but has no liquid chunk yet.
                               Create it on demand so cross-boundary flow is not lost. }
                              WCLt := GetOrCreate(TChunk.CX - 1, TChunk.CY);
                              WCLt.Data[LY][LastCol] := byte(LLt + Half);
                              WCLt.HasLiquid := True;
                           end;
                           Level := Level - Half;
                        end;
                     end;
                  end;
               end;

               { ── Spread right ─────────────────────────────────────── }
               if Level > 0 then
               begin
                  if LX < LastCol then
                  begin
                     PRt := Pass[LY][LX + 1];
                     LRt := WC.Data[LY][LX + 1];
                  end
                  else
                  if Assigned(WCRt) then
                  begin
                     PRt := IsPassableForLiquid(FManager.GetFG(BX + CHUNK_TILES_W, BY + LY));
                     LRt := WCRt.Data[LY][0];
                  end
                  else
                  begin
                     PRt := IsPassableForLiquid(FManager.GetFG(BX + CHUNK_TILES_W, BY + LY));
                     LRt := 0;
                  end;

                  if PRt then
                  begin
                     Diff := Level - LRt;
                     if Diff > 1 then
                     begin
                        Half := Min(Diff div 2, AFlowRate);
                        if Half >= LIQ_MIN_FLOW then
                        begin
                           WC.Data[LY][LX] := byte(Level - Half);
                           if LX < LastCol then
                              WC.Data[LY][LX + 1] := byte(LRt + Half)
                           else
                           if Assigned(WCRt) then
                           begin
                              WCRt.Data[LY][0] := byte(LRt + Half);
                              WCRt.HasLiquid := True;
                           end
                           else
                           if IsPassableForLiquid(FManager.GetFG(BX + CHUNK_TILES_W, BY + LY)) then
                           begin
                             { Neighbour world chunk is loaded but has no liquid chunk yet.
                               Create it on demand so cross-boundary flow is not lost. }
                              WCRt := GetOrCreate(TChunk.CX + 1, TChunk.CY);
                              WCRt.Data[LY][0] := byte(LRt + Half);
                              WCRt.HasLiquid := True;
                           end;
                           Level := Level - Half;
                        end;
                     end;
                  end;
               end;

               { ── Pressure: rise up ────────────────────────────────── }
               if Level >= LIQ_PRESSURE_THRESH then
               begin
                  if LY > 0 then
                  begin
                     PUp := Pass[LY - 1][LX];
                     LUp := WC.Data[LY - 1][LX];
                  end
                  else
                  if Assigned(WCUp) then
                  begin
                     PUp := IsPassableForLiquid(FManager.GetFG(BX + LX, BY - 1));
                     LUp := WCUp.Data[LastRow][LX];
                  end
                  else
                  begin
                     PUp := IsPassableForLiquid(FManager.GetFG(BX + LX, BY - 1));
                     LUp := 0;
                  end;

                  if PUp then
                  begin
                     Cap := LIQ_MAX - LUp;
                     Move := Min(Level - LIQ_PRESSURE_THRESH, Min(Cap, AFlowRate));
                     if Move >= LIQ_MIN_FLOW then
                     begin
                        WC.Data[LY][LX] := byte(Level - Move);
                        if LY > 0 then
                           WC.Data[LY - 1][LX] := byte(LUp + Move)
                        else
                        if Assigned(WCUp) then
                        begin
                           WCUp.Data[LastRow][LX] := byte(LUp + Move);
                           WCUp.HasLiquid := True;
                        end
                        else
                        if IsPassableForLiquid(FManager.GetFG(BX + LX, BY - 1)) then
                        begin
                          { Neighbour world chunk is loaded but has no liquid chunk yet.
                            Create it on demand so cross-boundary flow is not lost. }
                           WCUp := GetOrCreate(TChunk.CX, TChunk.CY - 1);
                           WCUp.Data[LastRow][LX] := byte(LUp + Move);
                           WCUp.HasLiquid := True;
                        end;
                     end;
                  end;
               end;
            end; { LX L→R }
         end
         else
         begin
            for LX := LastCol downto 0 do
            begin
               Level := WC.Data[LY][LX];
               if (Level = 0) or (not Pass[LY][LX]) then
                  Continue;

               { ── Fall ─────────────────────────────────────────────── }
               if LY < LastRow then
               begin
                  PDn := Pass[LY + 1][LX];
                  LDn := WC.Data[LY + 1][LX];
               end
               else
               if Assigned(WCDn) then
               begin
                  PDn := IsPassableForLiquid(FManager.GetFG(BX + LX, BY + CHUNK_TILES_H));
                  LDn := WCDn.Data[0][LX];
               end
               else
               begin
                  PDn := IsPassableForLiquid(FManager.GetFG(BX + LX, BY + CHUNK_TILES_H));
                  LDn := 0;
               end;

               if PDn then
               begin
                  Move := Min(Level, LIQ_MAX - LDn);
                  if Move >= LIQ_MIN_FLOW then
                  begin
                     WC.Data[LY][LX] := byte(Level - Move);
                     if LY < LastRow then
                        WC.Data[LY + 1][LX] := byte(LDn + Move)
                     else
                     if Assigned(WCDn) then
                     begin
                        WCDn.Data[0][LX] := byte(LDn + Move);
                        WCDn.HasLiquid := True;
                     end
                     else
                     if IsPassableForLiquid(FManager.GetFG(BX + LX, BY + CHUNK_TILES_H)) then
                     begin
                       { Neighbour world chunk is loaded but has no liquid chunk yet.
                         Create it on demand so cross-boundary flow is not lost. }
                        WCDn := GetOrCreate(TChunk.CX, TChunk.CY + 1);
                        WCDn.Data[0][LX] := byte(LDn + Move);
                        WCDn.HasLiquid := True;
                     end;
                     Level := Level - Move;
                  end;
               end;

               { ── Spread right first (reversed pass) ───────────────── }
               if Level > 0 then
               begin
                  if LX < LastCol then
                  begin
                     PRt := Pass[LY][LX + 1];
                     LRt := WC.Data[LY][LX + 1];
                  end
                  else
                  if Assigned(WCRt) then
                  begin
                     PRt := IsPassableForLiquid(FManager.GetFG(BX + CHUNK_TILES_W, BY + LY));
                     LRt := WCRt.Data[LY][0];
                  end
                  else
                  begin
                     PRt := IsPassableForLiquid(FManager.GetFG(BX + CHUNK_TILES_W, BY + LY));
                     LRt := 0;
                  end;

                  if PRt then
                  begin
                     Diff := Level - LRt;
                     if Diff > 1 then
                     begin
                        Half := Min(Diff div 2, AFlowRate);
                        if Half >= LIQ_MIN_FLOW then
                        begin
                           WC.Data[LY][LX] := byte(Level - Half);
                           if LX < LastCol then
                              WC.Data[LY][LX + 1] := byte(LRt + Half)
                           else
                           if Assigned(WCRt) then
                           begin
                              WCRt.Data[LY][0] := byte(LRt + Half);
                              WCRt.HasLiquid := True;
                           end
                           else
                           if IsPassableForLiquid(FManager.GetFG(BX + CHUNK_TILES_W, BY + LY)) then
                           begin
                             { Neighbour world chunk is loaded but has no liquid chunk yet.
                               Create it on demand so cross-boundary flow is not lost. }
                              WCRt := GetOrCreate(TChunk.CX + 1, TChunk.CY);
                              WCRt.Data[LY][0] := byte(LRt + Half);
                              WCRt.HasLiquid := True;
                           end;
                           Level := Level - Half;
                        end;
                     end;
                  end;
               end;

               { ── Spread left ──────────────────────────────────────── }
               if Level > 0 then
               begin
                  if LX > 0 then
                  begin
                     PLt := Pass[LY][LX - 1];
                     LLt := WC.Data[LY][LX - 1];
                  end
                  else
                  if Assigned(WCLt) then
                  begin
                     PLt := IsPassableForLiquid(FManager.GetFG(BX - 1, BY + LY));
                     LLt := WCLt.Data[LY][LastCol];
                  end
                  else
                  begin
                     PLt := IsPassableForLiquid(FManager.GetFG(BX - 1, BY + LY));
                     LLt := 0;
                  end;

                  if PLt then
                  begin
                     Diff := Level - LLt;
                     if Diff > 1 then
                     begin
                        Half := Min(Diff div 2, AFlowRate);
                        if Half >= LIQ_MIN_FLOW then
                        begin
                           WC.Data[LY][LX] := byte(Level - Half);
                           if LX > 0 then
                              WC.Data[LY][LX - 1] := byte(LLt + Half)
                           else
                           if Assigned(WCLt) then
                           begin
                              WCLt.Data[LY][LastCol] := byte(LLt + Half);
                              WCLt.HasLiquid := True;
                           end
                           else
                           if IsPassableForLiquid(FManager.GetFG(BX - 1, BY + LY)) then
                           begin
                             { Neighbour world chunk is loaded but has no liquid chunk yet.
                               Create it on demand so cross-boundary flow is not lost. }
                              WCLt := GetOrCreate(TChunk.CX - 1, TChunk.CY);
                              WCLt.Data[LY][LastCol] := byte(LLt + Half);
                              WCLt.HasLiquid := True;
                           end;
                           Level := Level - Half;
                        end;
                     end;
                  end;
               end;

               { ── Pressure: rise up ────────────────────────────────── }
               if Level >= LIQ_PRESSURE_THRESH then
               begin
                  if LY > 0 then
                  begin
                     PUp := Pass[LY - 1][LX];
                     LUp := WC.Data[LY - 1][LX];
                  end
                  else
                  if Assigned(WCUp) then
                  begin
                     PUp := IsPassableForLiquid(FManager.GetFG(BX + LX, BY - 1));
                     LUp := WCUp.Data[LastRow][LX];
                  end
                  else
                  begin
                     PUp := IsPassableForLiquid(FManager.GetFG(BX + LX, BY - 1));
                     LUp := 0;
                  end;

                  if PUp then
                  begin
                     Cap := LIQ_MAX - LUp;
                     Move := Min(Level - LIQ_PRESSURE_THRESH, Min(Cap, AFlowRate));
                     if Move >= LIQ_MIN_FLOW then
                     begin
                        WC.Data[LY][LX] := byte(Level - Move);
                        if LY > 0 then
                           WC.Data[LY - 1][LX] := byte(LUp + Move)
                        else
                        if Assigned(WCUp) then
                        begin
                           WCUp.Data[LastRow][LX] := byte(LUp + Move);
                           WCUp.HasLiquid := True;
                        end
                        else
                        if IsPassableForLiquid(FManager.GetFG(BX + LX, BY - 1)) then
                        begin
                          { Neighbour world chunk is loaded but has no liquid chunk yet.
                            Create it on demand so cross-boundary flow is not lost. }
                           WCUp := GetOrCreate(TChunk.CX, TChunk.CY - 1);
                           WCUp.Data[LastRow][LX] := byte(LUp + Move);
                           WCUp.HasLiquid := True;
                        end;
                     end;
                  end;
               end;
            end; { LX R→L }
         end;
      end; { LY }


      { ── Drain pass ─────────────────────────────────────────────────────────
        Drain timer logic:
          - Cell is FULL (level = LIQ_MAX) or EMPTY (level = 0):
              → reset DrainAge (timer stopped)
          - Cell level CHANGED vs the pre-tick snapshot (still flowing):
              → reset DrainAge (liquid is moving — not yet settled)
          - Cell is PARTIAL (0 < level < LIQ_MAX) AND STABLE (unchanged):
              → increment DrainAge; when it reaches ADrainThreshold, clear cell.
        This ensures the 10-second timer only starts once the liquid is fully
        settled. Flowing or recently disturbed cells are never drained. }
      if ADrainThreshold > 0 then
      begin
         for LY := 0 to LastRow do
            for LX := 0 to LastCol do
            begin
               LDn := WC.Data[LY][LX];   { current level (reuse LDn) }
               if (LDn = 0) or (LDn = LIQ_MAX) then
               begin
                  { Empty or full — reset timer. }
                  WC.DrainAge[LY][LX] := 0;
               end
               else
               if LDn <> Snap[LY][LX] then
               begin
                  { Level changed this tick — liquid is still moving, reset timer. }
                  WC.DrainAge[LY][LX] := 0;
               end
               else
               begin
                  { Partial AND stable — accumulate drain time. }
                  if WC.DrainAge[LY][LX] < 255 then
                     Inc(WC.DrainAge[LY][LX]);
                  if WC.DrainAge[LY][LX] >= ADrainThreshold then
                  begin
                     WC.Data[LY][LX] := 0;
                     WC.DrainAge[LY][LX] := 0;
                  end;
               end;
            end;
      end;

      WC.UpdateFlag;
   end; { chunk loop }
end;

{ =============================================================================
  TLiquidSimulator
  ============================================================================= }

constructor TLiquidSimulator.Create(AManager: TChunkManager);
begin
   inherited Create;
   FManager := AManager;
   FWater := TLiqLevelMap.Create(AManager);
   FLava := TLiqLevelMap.Create(AManager);
   FWaterAccum := 0;
   FLavaAccum := 0;
   FParity := 0;
end;

destructor TLiquidSimulator.Destroy;
begin
   FWater.Free;
   FLava.Free;
   inherited;
end;

procedure TLiquidSimulator.ProcessReactions;
const
   MAX_CHUNKS = 512;
var
   AllChunks: array[0..MAX_CHUNKS - 1] of TWorldChunk;
   N, I, LX, LY: Integer;
   WX, WY: Integer;
   WCk: TLiqLevelChunk;
   LCk: TLiqLevelChunk;
begin
   N := FManager.GetLoadedInRange(-10000, WORLD_MIN_CY - 1, 10000, WORLD_MAX_CY + 1, AllChunks, MAX_CHUNKS);
   for I := 0 to N - 1 do
   begin
      WCk := FWater.FindChunk(AllChunks[I].CX, AllChunks[I].CY);
      LCk := FLava.FindChunk(AllChunks[I].CX, AllChunks[I].CY);
      if (not Assigned(WCk)) or (not WCk.HasLiquid) then
         Continue;
      if (not Assigned(LCk)) or (not LCk.HasLiquid) then
         Continue;
      for LY := 0 to CHUNK_TILES_H - 1 do
         for LX := 0 to CHUNK_TILES_W - 1 do
            if (WCk.Data[LY][LX] > 0) and (LCk.Data[LY][LX] > 0) then
            begin
               LCk.Data[LY][LX] := 0;   { lava → stone }
               WX := TChunkManager.ChunkToTileX(AllChunks[I].CX) + LX;
               WY := TChunkManager.ChunkToTileY(AllChunks[I].CY) + LY;
               AllChunks[I].SetFG(LX, LY, TILE_STONE);
            end;
      LCk.UpdateFlag;
   end;
end;

procedure TLiquidSimulator.Update(ADelta: Single);
var
   DoWater, DoLava: boolean;
   L2R: boolean;
begin
   FWaterAccum := FWaterAccum + ADelta;
   FLavaAccum := FLavaAccum + ADelta;
   DoWater := FWaterAccum >= WATER_TICK_RATE;
   DoLava := FLavaAccum >= LAVA_TICK_RATE;
   if not DoWater and not DoLava then
      Exit;

   L2R := FParity = 0;

   if DoWater then
   begin
      FWater.SimStep(WATER_FLOW_RATE, L2R, WATER_DRAIN_TICKS);
      FWaterAccum := FWaterAccum - WATER_TICK_RATE;
      if FWaterAccum > WATER_TICK_RATE then
         FWaterAccum := 0;
   end;

   if DoLava then
   begin
      FLava.SimStep(LAVA_FLOW_RATE, L2R, LAVA_DRAIN_TICKS);
      FLavaAccum := FLavaAccum - LAVA_TICK_RATE;
      if FLavaAccum > LAVA_TICK_RATE then
         FLavaAccum := 0;
   end;

   ProcessReactions;

   FParity := 1 - FParity;
end;

procedure TLiquidSimulator.PlaceWater(WX, WY: Integer; ALevel: Integer);
begin
   if ALevel < 0 then
      ALevel := 0;
   if ALevel > LIQ_MAX then
      ALevel := LIQ_MAX;
   FWater.SetLevel(WX, WY, byte(ALevel));
end;

procedure TLiquidSimulator.PlaceLava(WX, WY: Integer; ALevel: Integer);
begin
   if ALevel < 0 then
      ALevel := 0;
   if ALevel > LIQ_MAX then
      ALevel := LIQ_MAX;
   FLava.SetLevel(WX, WY, byte(ALevel));
end;

procedure TLiquidSimulator.Clear;
begin
   FWater.Clear;
   FLava.Clear;
   FWaterAccum := 0;
   FLavaAccum := 0;
   FParity := 0;
end;

end.
