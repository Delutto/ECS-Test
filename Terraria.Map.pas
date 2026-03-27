unit Terraria.Map;

{$mode objfpc}{$H+}

{ TGameMap — stores foreground and background tile layers.

  Foreground  – the solid tiles the player collides with.
  Background  – the "wall" layer behind air tiles (drawn darker).

  Both layers share the same tile-type byte codes defined in Terraria.Common. }

interface

uses
   SysUtils, Terraria.Common;

type
   { Raw row of tile bytes }
   TTileRow = array[0..MAP_WIDTH - 1] of byte;

   { ── TGameMap ─────────────────────────────────────────────────────────── }
   TGameMap = class
   private
      FForeground: array[0..MAP_HEIGHT - 1] of TTileRow;
      FBackground: array[0..MAP_HEIGHT - 1] of TTileRow;
      FSurfaceY: array[0..MAP_WIDTH - 1] of Integer;
      FBiome: array[0..MAP_WIDTH - 1] of byte;
   public
      constructor Create;

      { ── Foreground (solid) layer ─────────────────────────────────────── }
      function GetFG(ACol, ARow: Integer): byte; inline;
      procedure SetFG(ACol, ARow: Integer; ATile: byte); inline;

      { ── Background (wall) layer ──────────────────────────────────────── }
      function GetBG(ACol, ARow: Integer): byte; inline;
      procedure SetBG(ACol, ARow: Integer; ATile: byte); inline;

      { ── Metadata ─────────────────────────────────────────────────────── }
      function GetSurfaceY(ACol: Integer): Integer; inline;
      procedure SetSurfaceY(ACol, ARow: Integer); inline;

      function GetBiome(ACol: Integer): byte; inline;
      procedure SetBiome(ACol: Integer; ABiome: byte); inline;

      { ── Bulk clear ───────────────────────────────────────────────────── }
      procedure Clear;

      { ── Bounds check ─────────────────────────────────────────────────── }
      function InBounds(ACol, ARow: Integer): boolean; inline;
   end;

implementation

constructor TGameMap.Create;
begin
   inherited Create;

   Clear;
end;

procedure TGameMap.Clear;
begin
   FillChar(FForeground, SizeOf(FForeground), TILE_AIR);
   FillChar(FBackground, SizeOf(FBackground), TILE_AIR);
   FillChar(FSurfaceY, SizeOf(FSurfaceY), 0);
   FillChar(FBiome, SizeOf(FBiome), BIOME_PLAINS);
end;

function TGameMap.InBounds(ACol, ARow: Integer): boolean;
begin
   Result := (ACol >= 0) and (ACol < MAP_WIDTH) and (ARow >= 0) and (ARow < MAP_HEIGHT);
end;

{ ── Foreground ─────────────────────────────────────────────────────────── }

function TGameMap.GetFG(ACol, ARow: Integer): byte;
begin
   if InBounds(ACol, ARow) then
      Result := FForeground[ARow][ACol]
   else
      Result := TILE_BEDROCK;
end;

procedure TGameMap.SetFG(ACol, ARow: Integer; ATile: byte);
begin
   if InBounds(ACol, ARow) then
      FForeground[ARow][ACol] := ATile;
end;

{ ── Background ─────────────────────────────────────────────────────────── }

function TGameMap.GetBG(ACol, ARow: Integer): byte;
begin
   if InBounds(ACol, ARow) then
      Result := FBackground[ARow][ACol]
   else
      Result := TILE_BEDROCK;
end;

procedure TGameMap.SetBG(ACol, ARow: Integer; ATile: byte);
begin
   if InBounds(ACol, ARow) then
      FBackground[ARow][ACol] := ATile;
end;

{ ── Metadata ────────────────────────────────────────────────────────────── }

function TGameMap.GetSurfaceY(ACol: Integer): Integer;
begin
   if (ACol >= 0) and (ACol < MAP_WIDTH) then
      Result := FSurfaceY[ACol]
   else
      Result := BASE_SURFACE;
end;

procedure TGameMap.SetSurfaceY(ACol, ARow: Integer);
begin
   if (ACol >= 0) and (ACol < MAP_WIDTH) then
      FSurfaceY[ACol] := ARow;
end;

function TGameMap.GetBiome(ACol: Integer): byte;
begin
   if (ACol >= 0) and (ACol < MAP_WIDTH) then
      Result := FBiome[ACol]
   else
      Result := BIOME_PLAINS;
end;

procedure TGameMap.SetBiome(ACol: Integer; ABiome: byte);
begin
   if (ACol >= 0) and (ACol < MAP_WIDTH) then
      FBiome[ACol] := ABiome;
end;

end.
