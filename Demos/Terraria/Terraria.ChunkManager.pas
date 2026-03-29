
unit Terraria.ChunkManager;
{$mode objfpc}{$H+}
{ TChunkManager — infinite-world spatial hash map.

  DESIGN
  ──────
  • World is logically infinite in the X axis, bounded in Y by
    [WORLD_MIN_CY .. WORLD_MAX_CY] (chunk-row limits).
  • Chunks are stored in a fixed-size open-addressing hash table with
    separate chaining (intrusive singly-linked list per bucket).
  • Load/unload policy:
      – Chunks inside the VIEW_RADIUS (in chunk units) around the camera
        chunk are kept alive.
      – Chunks outside UNLOAD_RADIUS are freed (tiles discarded).
      – Generation is triggered synchronously the first time a chunk is
        requested and not yet loaded.

  SPATIAL HASH
  ────────────
  key   = (CX * HASH_P1) xor (CY * HASH_P2)   (both are primes)
  bucket = key mod HASH_BUCKETS                (power-of-two for fast mod)

  WORLD TILE COORDINATE HELPERS (static class methods, inlined)
  ─────────────────────────────
  TileToChunk(TX)  → chunk coord    CX = TX div CHUNK_TILES_W
  TileToLocal(TX)  → local  coord   LX = TX mod CHUNK_TILES_W
  ChunkToTile(CX)  → first tile     TX = CX * CHUNK_TILES_W  }

interface

uses
   SysUtils, Math,
   Terraria.Common,
   Terraria.WorldChunk;

const
   { ── Hash table size (power of two) ─────────────────────────── }
   HASH_BUCKETS = 1024;
   HASH_MASK = HASH_BUCKETS - 1;
   HASH_P1 = 73856093;
   HASH_P2 = 19349663;

   { ── Chunk management radii (in chunk units) ─────────────────── }
   VIEW_RADIUS = 6;    { load   within this many chunks of camera }
   UNLOAD_RADIUS = 8;    { unload beyond this many chunks of camera }

   { ── World Y extent ──────────────────────────────────────────── }
   WORLD_MIN_CY = 0;
   WORLD_MAX_CY = 7;    { 8 chunk rows × 32 tiles = 256 tiles tall }

   { ── Surface / bedrock row in world-tile coords ───────────────── }
   WORLD_SURFACE_TILE = 48;   { matches BASE_SURFACE in Terraria.Common }
   WORLD_BEDROCK_TILE = CHUNK_TILES_H * (WORLD_MAX_CY + 1) - 3;

type
   { Callback: called whenever a chunk needs its tiles filled }
   TChunkGenerateProc = procedure(ACX, ACY: Integer; AChunk: TWorldChunk) of object;

   { ── TChunkManager ─────────────────────────────────────────────────────── }
   TChunkManager = class
   private
      FBuckets: array[0..HASH_BUCKETS - 1] of TWorldChunk;
      FLoadedCount: Integer;
      FTotalCreated: Integer;
      FOnGenerate: TChunkGenerateProc;
      FSeed: longint;
      FStreamingDirty: boolean;   { set when any chunk loads or unloads }

      function HashKey(ACX, ACY: Integer): Integer; inline;
      function FindChunk(ACX, ACY: Integer): TWorldChunk;
      function CreateChunk(ACX, ACY: Integer): TWorldChunk;
      procedure RemoveFromBucket(AChunk: TWorldChunk);
   public
      constructor Create(ASeed: longint = 0);
      destructor Destroy; override;

      { ── Core access ─────────────────────────────────────────────── }
      { Returns chunk (generating if needed); never returns nil }
      function GetOrCreate(ACX, ACY: Integer): TWorldChunk;
      { Returns existing chunk or nil without generating }
      function FindLoaded(ACX, ACY: Integer): TWorldChunk;

      { ── World-tile access (convenience, spans chunk boundary) ───── }
      function GetFG(TX, TY: Integer): byte;
      procedure SetFG(TX, TY: Integer; ATile: byte);
      function GetBG(TX, TY: Integer): byte;
      procedure SetBG(TX, TY: Integer; ATile: byte);

      { ── Metadata per column (surface Y + biome) ─────────────────── }
      function GetSurfaceY(TX: Integer): Integer;
      procedure SetSurfaceY(TX, TY: Integer);
      function GetBiome(TX: Integer): byte;
      procedure SetBiome(TX: Integer; ABiome: byte);

      { ── Streaming ───────────────────────────────────────────────── }
      { Call once per frame with camera chunk coords to load/unload }
      procedure UpdateStreaming(CCX, CCY: Integer);

      { ── Chunk coord helpers (static) ────────────────────────────── }
      class function TileToChunkX(TX: Integer): Integer; static; inline;
      class function TileToChunkY(TY: Integer): Integer; static; inline;
      class function TileToLocalX(TX: Integer): Integer; static; inline;
      class function TileToLocalY(TY: Integer): Integer; static; inline;
      class function ChunkToTileX(CX: Integer): Integer; static; inline;
      class function ChunkToTileY(CY: Integer): Integer; static; inline;

      { ── Enumeration (for renderer) ────────────────────────────────── }
      { Fills AOut with pointers to chunks within the given chunk range.
      Returns the number of chunks written (up to AMaxOut). }
      function GetLoadedInRange(CX0, CY0, CX1, CY1: Integer; out AOut: array of TWorldChunk; AMaxOut: Integer): Integer;

      { ── Stats ────────────────────────────────────────────────────── }
      property LoadedCount: Integer read FLoadedCount;
      property TotalCreated: Integer read FTotalCreated;
      property OnGenerate: TChunkGenerateProc read FOnGenerate write FOnGenerate;
      property Seed: longint read FSeed write FSeed;
      { True if any chunk was loaded or unloaded since the last
        ClearStreamingDirty call. Use this to decide when to recompute
        lighting instead of comparing LoadedCount (which can be unchanged
        when equal numbers of chunks load and unload in the same frame). }
      property StreamingDirty: boolean read FStreamingDirty;
      procedure ClearStreamingDirty;

   private
    { Per-column metadata stored in a small side-hash (TX → byte).
      We only store values for the surface and biome columns we've seen.
      Hash table size = column coverage of 16 view radii chunks. }
      FSurfaceY: array[0..4095] of smallint;   { -1 = unknown }
      FBiomeTile: array[0..4095] of byte;
      FSurfaceYSet: array[0..4095] of boolean;

      function ColMetaIdx(TX: Integer): Integer; inline;
   end;

implementation

uses
   Terraria.Noise;

   { ── Col-metadata helpers ──────────────────────────────────────────────── }

function TChunkManager.ColMetaIdx(TX: Integer): Integer;
begin
   { Wrap into [0..4095] }
   Result := ((TX mod 4096) + 4096) mod 4096;
end;

function TChunkManager.GetSurfaceY(TX: Integer): Integer;
var
   I: Integer;
begin
   I := ColMetaIdx(TX);
   if FSurfaceYSet[I] then
      Result := FSurfaceY[I]
   else
      Result := WORLD_SURFACE_TILE;
end;

procedure TChunkManager.SetSurfaceY(TX, TY: Integer);
var
   I: Integer;
begin
   I := ColMetaIdx(TX);
   FSurfaceY[I] := TY;
   FSurfaceYSet[I] := True;
end;

function TChunkManager.GetBiome(TX: Integer): byte;
begin
   Result := FBiomeTile[ColMetaIdx(TX)];
end;

procedure TChunkManager.SetBiome(TX: Integer; ABiome: byte);
begin
   FBiomeTile[ColMetaIdx(TX)] := ABiome;
end;

{ ── Hash helpers ──────────────────────────────────────────────────────── }

function TChunkManager.HashKey(ACX, ACY: Integer): Integer;
begin
   Result := ((ACX * HASH_P1) xor (ACY * HASH_P2)) and HASH_MASK;
   if Result < 0 then
      Result := Result + HASH_BUCKETS;
end;

function TChunkManager.FindChunk(ACX, ACY: Integer): TWorldChunk;
var
   C: TWorldChunk;
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

function TChunkManager.CreateChunk(ACX, ACY: Integer): TWorldChunk;
var
   K: Integer;
begin
   Result := TWorldChunk.Create(ACX, ACY);
   K := HashKey(ACX, ACY);
   Result.NextInBucket := FBuckets[K];
   FBuckets[K] := Result;
   Inc(FLoadedCount);
   Inc(FTotalCreated);
   FStreamingDirty := True;
end;

procedure TChunkManager.RemoveFromBucket(AChunk: TWorldChunk);
var
   K: Integer;
   Prev, C: TWorldChunk;
begin
   K := HashKey(AChunk.CX, AChunk.CY);
   Prev := nil;
   C := FBuckets[K];
   while Assigned(C) do
   begin
      if C = AChunk then
      begin
         if Assigned(Prev) then
            Prev.NextInBucket := C.NextInBucket
         else
            FBuckets[K] := C.NextInBucket;
         Dec(FLoadedCount);
         Exit;
      end;
      Prev := C;
      C := C.NextInBucket;
   end;
end;

{ ── Constructor / Destructor ──────────────────────────────────────────── }

constructor TChunkManager.Create(ASeed: longint);
begin
   inherited Create;
   FSeed := ASeed;
   FLoadedCount := 0;
   FTotalCreated := 0;
   FillChar(FBuckets, SizeOf(FBuckets), 0);
   FillChar(FSurfaceY, SizeOf(FSurfaceY), 0);
   FillChar(FSurfaceYSet, SizeOf(FSurfaceYSet), 0);
   FillChar(FBiomeTile, SizeOf(FBiomeTile), BIOME_PLAINS);
end;

destructor TChunkManager.Destroy;
var
   I: Integer;
   C, Next: TWorldChunk;
begin
   for I := 0 to HASH_BUCKETS - 1 do
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
   inherited;
end;

{ ── Core chunk access ─────────────────────────────────────────────────── }

function TChunkManager.GetOrCreate(ACX, ACY: Integer): TWorldChunk;
begin
   { Clamp Y to world limits }
   if ACY < WORLD_MIN_CY then
      ACY := WORLD_MIN_CY;
   if ACY > WORLD_MAX_CY then
      ACY := WORLD_MAX_CY;

   Result := FindChunk(ACX, ACY);
   if not Assigned(Result) then
   begin
      Result := CreateChunk(ACX, ACY);
      { Call the user-supplied generator callback }
      if Assigned(FOnGenerate) then
         FOnGenerate(ACX, ACY, Result);
   end;
end;

function TChunkManager.FindLoaded(ACX, ACY: Integer): TWorldChunk;
begin
   Result := FindChunk(ACX, ACY);
end;

{ ── World-tile convenience accessors ──────────────────────────────────── }

function TChunkManager.GetFG(TX, TY: Integer): byte;
var
   C: TWorldChunk;
begin
   C := GetOrCreate(TileToChunkX(TX), TileToChunkY(TY));
   Result := C.GetFG(TileToLocalX(TX), TileToLocalY(TY));
end;

procedure TChunkManager.SetFG(TX, TY: Integer; ATile: byte);
var
   C: TWorldChunk;
begin
   C := GetOrCreate(TileToChunkX(TX), TileToChunkY(TY));
   C.SetFG(TileToLocalX(TX), TileToLocalY(TY), ATile);
   C.Dirty := True;
end;

function TChunkManager.GetBG(TX, TY: Integer): byte;
var
   C: TWorldChunk;
begin
   C := GetOrCreate(TileToChunkX(TX), TileToChunkY(TY));
   Result := C.GetBG(TileToLocalX(TX), TileToLocalY(TY));
end;

procedure TChunkManager.SetBG(TX, TY: Integer; ATile: byte);
var
   C: TWorldChunk;
begin
   C := GetOrCreate(TileToChunkX(TX), TileToChunkY(TY));
   C.SetBG(TileToLocalX(TX), TileToLocalY(TY), ATile);
   C.Dirty := True;
end;

{ ── Streaming ─────────────────────────────────────────────────────────── }

procedure TChunkManager.UpdateStreaming(CCX, CCY: Integer);
var
   I: Integer;
   C, Next, Prev: TWorldChunk;
   Dist: Integer;
   DX, DY, TX, TY: Integer;
begin
   { Unload chunks that are too far from the camera chunk }
   for I := 0 to HASH_BUCKETS - 1 do
   begin
      Prev := nil;
      C := FBuckets[I];
      while Assigned(C) do
      begin
         Next := C.NextInBucket;
         Dist := Max(Abs(C.CX - CCX), Abs(C.CY - CCY));
         if Dist > UNLOAD_RADIUS then
         begin
            { Remove from bucket chain }
            if Assigned(Prev) then
               Prev.NextInBucket := Next
            else
               FBuckets[I] := Next;
            C.Free;
            Dec(FLoadedCount);
            FStreamingDirty := True;
            { Prev stays the same — we already updated the chain }
         end
         else
            Prev := C;
         C := Next;
      end;
   end;

   { Pre-load chunks within VIEW_RADIUS (triggers generation if missing) }
   for DY := -VIEW_RADIUS to VIEW_RADIUS do
      for DX := -VIEW_RADIUS to VIEW_RADIUS do
      begin
         TX := CCX + DX;
         TY := CCY + DY;
         if (TY >= WORLD_MIN_CY) and (TY <= WORLD_MAX_CY) then
            GetOrCreate(TX, TY);
      end;
end;

{ ── Range enumeration (for renderer) ─────────────────────────────────── }

function TChunkManager.GetLoadedInRange(CX0, CY0, CX1, CY1: Integer; out AOut: array of TWorldChunk; AMaxOut: Integer): Integer;
var
   I: Integer;
   C: TWorldChunk;
begin
   Result := 0;
   for I := 0 to HASH_BUCKETS - 1 do
   begin
      C := FBuckets[I];
      while Assigned(C) and (Result < AMaxOut) do
      begin
         if (C.CX >= CX0) and (C.CX <= CX1) and (C.CY >= CY0) and (C.CY <= CY1) then
         begin
            AOut[Result] := C;
            Inc(Result);
         end;
         C := C.NextInBucket;
      end;
      if Result >= AMaxOut then
         Break;
   end;
end;

{ ── Coord helpers ─────────────────────────────────────────────────────── }

class function TChunkManager.TileToChunkX(TX: Integer): Integer;
begin
   { Correct floor division for negative coords }
   if TX >= 0 then
      Result := TX div CHUNK_TILES_W
   else
      Result := (TX - CHUNK_TILES_W + 1) div CHUNK_TILES_W;
end;

class function TChunkManager.TileToChunkY(TY: Integer): Integer;
begin
   if TY >= 0 then
      Result := TY div CHUNK_TILES_H
   else
      Result := (TY - CHUNK_TILES_H + 1) div CHUNK_TILES_H;
end;

class function TChunkManager.TileToLocalX(TX: Integer): Integer;
begin
   Result := ((TX mod CHUNK_TILES_W) + CHUNK_TILES_W) mod CHUNK_TILES_W;
end;

class function TChunkManager.TileToLocalY(TY: Integer): Integer;
begin
   Result := ((TY mod CHUNK_TILES_H) + CHUNK_TILES_H) mod CHUNK_TILES_H;
end;

class function TChunkManager.ChunkToTileX(CX: Integer): Integer;
begin
   Result := CX * CHUNK_TILES_W;
end;

class function TChunkManager.ChunkToTileY(CY: Integer): Integer;
begin
   Result := CY * CHUNK_TILES_H;
end;


procedure TChunkManager.ClearStreamingDirty;
begin
   FStreamingDirty := False;
end;

end.
