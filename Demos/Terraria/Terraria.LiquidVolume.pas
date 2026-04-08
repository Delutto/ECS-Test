unit Terraria.LiquidVolume;

{$mode objfpc}{$H+}

{ =============================================================================
  Terraria.LiquidVolume — Per-tile liquid volume storage

  Each world tile that contains liquid also carries a VOLUME byte (0..LV_MAX).

    LV_MAX  = 8  (= TILE_SIZE pixels)
    0        = empty  (tile is TILE_AIR)
    LV_MAX   = full   (tile is entirely filled)
    1..LV_MAX-1 = partial fill, rendered as bottom-aligned rectangle of
                  that many pixels height

  The volume data lives in TLiquidVolumeChunk objects organised in a
  power-of-two open-addressing hash table identical to TLightMap, so lookup
  is O(1) amortised and memory is only allocated for chunks that actually
  contain liquid.

  Lifecycle is managed externally by TWorldScene:
    • Created after TChunkManager.
    • Cleared (FreeAllChunks) before RebuildWorld.
    • Freed in DoUnload.

  TLiquidPlacer writes volume = LV_MAX when it places a liquid tile.
  TLiquidSimulator reads and writes volume every tick.
  TLiquidRenderer reads volume to compute the pixel height of each quad.
  ============================================================================= }

interface

uses
   SysUtils,
   Terraria.Common,
   Terraria.ChunkManager;

const
   { Maximum volume per cell.  Chosen equal to TILE_SIZE so 1 volume unit = 1 pixel. }
   LV_MAX = 8;
   LV_HASH_BUCKETS = 1024;   { power-of-two for fast mod }
   LV_HASH_P1 = 73856093;
   LV_HASH_P2 = 19349663;

type
   TLiquidVolumeRow = array[0..CHUNK_TILES_W - 1] of byte;
   TLiquidVolumeData = array[0..CHUNK_TILES_H - 1] of TLiquidVolumeRow;

   { -------------------------------------------------------------------------
     TLiquidVolumeChunk — volume data for one CHUNK_TILES_W × CHUNK_TILES_H block.
     Participates in an intrusive singly-linked list per hash bucket.
   ------------------------------------------------------------------------- }
   TLiquidVolumeChunk = class
   public
      Data: TLiquidVolumeData;
      CX, CY: Integer;
      NextInBucket: TLiquidVolumeChunk;

      constructor Create(ACX, ACY: Integer);
      function GetVol(LX, LY: Integer): byte; inline;
      procedure SetVol(LX, LY: Integer; V: byte); inline;
      procedure Fill(AValue: byte);
   end;

   { -------------------------------------------------------------------------
     TLiquidVolumeMap — map of all TLiquidVolumeChunk objects.
     Provides world-tile-coordinate accessors.
   ------------------------------------------------------------------------- }
   TLiquidVolumeMap = class
   private
      FBuckets: array[0..LV_HASH_BUCKETS - 1] of TLiquidVolumeChunk;

      function HashKey(ACX, ACY: Integer): Integer; inline;
      function FindChunk(ACX, ACY: Integer): TLiquidVolumeChunk;
      function GetOrCreateChunk(ACX, ACY: Integer): TLiquidVolumeChunk;
      procedure FreeAllChunks;
   public
      constructor Create;
      destructor Destroy; override;

      { Query / mutate by world-tile coordinates. }
      function GetVolume(WX, WY: Integer): byte;
      procedure SetVolume(WX, WY: Integer; V: byte);

      { Set volume = LV_MAX for every tile of type LiqTile in a rect.
        Called by TLiquidPlacer after bulk-placing tiles. }
      procedure InitFullVolume(WX, WY: Integer);

      { Discard all data (call before RebuildWorld). }
      procedure Clear;
   end;

{ Helper: returns True if ATile is a solid terrain tile that blocks liquid.
  Only tile IDs 1..TILE_SHRUB-1 (i.e. TILE_DIRT..TILE_ICE) block liquid.
  AIR (0), decoration tiles (TILE_SHRUB..TILE_LIQUID_BOUNDARY-1), and other
  liquid tiles (>= TILE_LIQUID_BOUNDARY) are all passable for liquid flow. }
function IsPassableForLiquid(ATile: byte): boolean; inline;

implementation

{ =============================================================================
  IsPassableForLiquid
  ============================================================================= }

function IsPassableForLiquid(ATile: byte): boolean;
begin
   { Solid terrain = IDs [1 .. TILE_SHRUB-1] = [1..13]. Block liquid.
     Everything else (AIR=0, decorations 14-25, liquids 26-28) is passable. }
   Result := (ATile = TILE_AIR) or (ATile >= TILE_SHRUB);
end;

{ =============================================================================
  TLiquidVolumeChunk
  ============================================================================= }

constructor TLiquidVolumeChunk.Create(ACX, ACY: Integer);
begin
   inherited Create;
   CX := ACX;
   CY := ACY;
   NextInBucket := nil;
   FillChar(Data, SizeOf(Data), 0);
end;

function TLiquidVolumeChunk.GetVol(LX, LY: Integer): byte;
begin
   Result := Data[LY][LX];
end;

procedure TLiquidVolumeChunk.SetVol(LX, LY: Integer; V: byte);
begin
   Data[LY][LX] := V;
end;

procedure TLiquidVolumeChunk.Fill(AValue: byte);
begin
   FillChar(Data, SizeOf(Data), AValue);
end;

{ =============================================================================
  TLiquidVolumeMap
  ============================================================================= }

function TLiquidVolumeMap.HashKey(ACX, ACY: Integer): Integer;
begin
   Result := ((ACX * LV_HASH_P1) xor (ACY * LV_HASH_P2)) and (LV_HASH_BUCKETS - 1);
end;

function TLiquidVolumeMap.FindChunk(ACX, ACY: Integer): TLiquidVolumeChunk;
var
   C: TLiquidVolumeChunk;
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

function TLiquidVolumeMap.GetOrCreateChunk(ACX, ACY: Integer): TLiquidVolumeChunk;
var
   Bkt: Integer;
   C: TLiquidVolumeChunk;
begin
   C := FindChunk(ACX, ACY);
   if Assigned(C) then
   begin
      Result := C;
      Exit;
   end;
   Bkt := HashKey(ACX, ACY);
   C := TLiquidVolumeChunk.Create(ACX, ACY);
   C.NextInBucket := FBuckets[Bkt];
   FBuckets[Bkt] := C;
   Result := C;
end;

procedure TLiquidVolumeMap.FreeAllChunks;
var
   I: Integer;
   C, N: TLiquidVolumeChunk;
begin
   for I := 0 to LV_HASH_BUCKETS - 1 do
   begin
      C := FBuckets[I];
      while Assigned(C) do
      begin
         N := C.NextInBucket;
         C.Free;
         C := N;
      end;
      FBuckets[I] := nil;
   end;
end;

constructor TLiquidVolumeMap.Create;
begin
   inherited Create;
   FillChar(FBuckets, SizeOf(FBuckets), 0);
end;

destructor TLiquidVolumeMap.Destroy;
begin
   FreeAllChunks;
   inherited;
end;

function TLiquidVolumeMap.GetVolume(WX, WY: Integer): byte;
var
   CX, CY: Integer;
   C: TLiquidVolumeChunk;
begin
   CX := TChunkManager.TileToChunkX(WX);
   CY := TChunkManager.TileToChunkY(WY);
   C := FindChunk(CX, CY);
   if not Assigned(C) then
   begin
      Result := 0;
      Exit;
   end;
   Result := C.GetVol(TChunkManager.TileToLocalX(WX), TChunkManager.TileToLocalY(WY));
end;

procedure TLiquidVolumeMap.SetVolume(WX, WY: Integer; V: byte);
var
   CX, CY: Integer;
   C: TLiquidVolumeChunk;
begin
   CX := TChunkManager.TileToChunkX(WX);
   CY := TChunkManager.TileToChunkY(WY);
   if V = 0 then
   begin
      { Optimisation: don't create a chunk just to store 0. }
      C := FindChunk(CX, CY);
      if Assigned(C) then
         C.SetVol(TChunkManager.TileToLocalX(WX),
            TChunkManager.TileToLocalY(WY), 0);
   end
   else
   begin
      C := GetOrCreateChunk(CX, CY);
      C.SetVol(TChunkManager.TileToLocalX(WX),
         TChunkManager.TileToLocalY(WY), V);
   end;
end;

procedure TLiquidVolumeMap.InitFullVolume(WX, WY: Integer);
begin
   SetVolume(WX, WY, LV_MAX);
end;

procedure TLiquidVolumeMap.Clear;
begin
   FreeAllChunks;
end;

end.
