unit Terraria.WorldChunk;

{$mode objfpc}{$H+}

{ TWorldChunk — a fixed-size rectangular block of tile data.

  Layout constants (from Terraria.ChunkManager):
    CHUNK_TILES_W = 32   tiles per chunk horizontally
    CHUNK_TILES_H = 32   tiles per chunk vertically

  Each chunk stores two byte arrays:
    FForeground – solid tiles (gameplay layer)
    FBackground – wall tiles  (decoration layer)

  Chunks know their grid position (CX, CY) in chunk coordinates.
  World tile coordinates: tile_x = CX * CHUNK_TILES_W + local_x }

interface

uses
   SysUtils,
   Terraria.Common;

type
   TChunkTileRow = array[0..CHUNK_TILES_W - 1] of byte;

   TWorldChunk = class
   private
      FCX, FCY: Integer;    { chunk grid coords }
      FDirty: boolean;
      FForeground: array[0..CHUNK_TILES_H - 1] of TChunkTileRow;
      FBackground: array[0..CHUNK_TILES_H - 1] of TChunkTileRow;
   public
      { Next pointer for intrusive linked-list inside hash buckets }
      NextInBucket: TWorldChunk;

      constructor Create(ACX, ACY: Integer);

      { Tile access — local coords [0..CHUNK_TILES_W-1, 0..CHUNK_TILES_H-1] }
      function GetFG(LX, LY: Integer): byte; inline;
      procedure SetFG(LX, LY: Integer; ATile: byte); inline;
      function GetBG(LX, LY: Integer): byte; inline;
      procedure SetBG(LX, LY: Integer; ATile: byte); inline;

      { Fill entire chunk with a single tile value }
      procedure FillFG(ATile: byte);
      procedure FillBG(ATile: byte);

      function InLocalBounds(LX, LY: Integer): boolean; inline;

      property CX: Integer read FCX;
      property CY: Integer read FCY;
      property Dirty: boolean read FDirty write FDirty;
   end;

implementation

constructor TWorldChunk.Create(ACX, ACY: Integer);
begin
   inherited Create;
   FCX := ACX;
   FCY := ACY;
   FDirty := False;
   NextInBucket := nil;
   FillFG(TILE_AIR);
   FillBG(TILE_AIR);
end;

function TWorldChunk.InLocalBounds(LX, LY: Integer): boolean;
begin
   Result := (LX >= 0) and (LX < CHUNK_TILES_W) and (LY >= 0) and (LY < CHUNK_TILES_H);
end;

function TWorldChunk.GetFG(LX, LY: Integer): byte;
begin
   if InLocalBounds(LX, LY) then
      Result := FForeground[LY][LX]
   else
      Result := TILE_BEDROCK;
end;

procedure TWorldChunk.SetFG(LX, LY: Integer; ATile: byte);
begin
   if InLocalBounds(LX, LY) then
      FForeground[LY][LX] := ATile;
end;

function TWorldChunk.GetBG(LX, LY: Integer): byte;
begin
   if InLocalBounds(LX, LY) then
      Result := FBackground[LY][LX]
   else
      Result := TILE_BEDROCK;
end;

procedure TWorldChunk.SetBG(LX, LY: Integer; ATile: byte);
begin
   if InLocalBounds(LX, LY) then
      FBackground[LY][LX] := ATile;
end;

procedure TWorldChunk.FillFG(ATile: byte);
begin
   FillChar(FForeground, SizeOf(FForeground), ATile);
end;

procedure TWorldChunk.FillBG(ATile: byte);
begin
   FillChar(FBackground, SizeOf(FBackground), ATile);
end;

end.
