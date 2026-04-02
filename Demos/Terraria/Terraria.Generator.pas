unit Terraria.Generator;

{$mode objfpc}{$H+}

{ TTerrainGenerator - fills a TGameMap with procedurally generated terrain.

  PIPELINE
  ---------
  1. Seed the noise with a random or user-supplied seed.
  2. Build a 1D height map (surface Y row per column).
  3. Assign biomes left-to-right with a slow noise pass.
  4. Fill foreground tiles column-by-column.
  5. Carve worm-like caves using 2D noise thresholding.
  6. Fill the background (wall) layer: mirrors what ForegroundTile would
     place at each position, so cave walls always show the correct material
     (granite caves have granite walls, marble caves have marble walls, etc.).
  7. Post-process: convert the topmost solid dirt tile in each column to grass. }

interface

uses
   SysUtils, Math,
   Terraria.Common,
   Terraria.Map,
   Terraria.Noise;

type
   TTerrainGenerator = class
   private
      FSeed: longint;

      procedure BuildHeightMap(AMap: TGameMap);
      procedure BuildBiomeMap(AMap: TGameMap);
      procedure FillTiles(AMap: TGameMap);
      procedure CarveCaves(AMap: TGameMap);
      procedure FillBackground(AMap: TGameMap);
      procedure PlaceGrass(AMap: TGameMap);

      function ForegroundTile(ACol, ARow, ASurface: Integer; ABiome: byte): byte;
   public
      constructor Create(ASeed: longint = 0);
      procedure Generate(AMap: TGameMap);
      property Seed: longint read FSeed write FSeed;
   end;

implementation

constructor TTerrainGenerator.Create(ASeed: longint);
begin
   inherited Create;
   if ASeed = 0 then
      FSeed := Trunc(Now * 86400) mod $7FFFFF
   else
      FSeed := ASeed;
end;

{ 1. Height map }

procedure TTerrainGenerator.BuildHeightMap(AMap: TGameMap);
var
   X, SY: Integer;
   N: Single;
begin
   for X := 0 to MAP_WIDTH - 1 do
   begin
      N := FBM1D(X * 0.008, 4, 2.0, 0.55);
      SY := BASE_SURFACE + Round(N * SURFACE_AMP);
      SY := Max(MIN_SURFACE, Min(MAX_SURFACE, SY));
      AMap.SetSurfaceY(X, SY);
   end;
end;

{ 2. Biome map }

procedure TTerrainGenerator.BuildBiomeMap(AMap: TGameMap);
var
   X: Integer;
   N: Single;
   Biome: byte;
begin
   for X := 0 to MAP_WIDTH - 1 do
   begin
      N := (FBM1D(X * 0.003 + 900, 2) + 1.0) * 0.5;
      if N < 0.30 then
         Biome := BIOME_DESERT
      else
      if N < 0.68 then
         Biome := BIOME_PLAINS
      else
         Biome := BIOME_FOREST;
      AMap.SetBiome(X, Biome);
   end;
end;

{ 3. Primary tile fill }

function TTerrainGenerator.ForegroundTile(ACol, ARow, ASurface: Integer; ABiome: byte): byte;
var
   Depth: Integer;
   N: Single;
begin
   if ARow < ASurface then
   begin
      Result := TILE_AIR;
      Exit;
   end;

   Depth := ARow - ASurface;

   if Depth = 0 then
   begin
      case ABiome of
         BIOME_DESERT: Result := TILE_SAND;
         else          Result := TILE_DIRT;
      end;
      Exit;
   end;

   if Depth <= DEPTH_DIRT then
   begin
      case ABiome of
         BIOME_DESERT: Result := TILE_SAND;
         else          Result := TILE_DIRT;
      end;
      Exit;
   end;

   if (ABiome = BIOME_DESERT) and (Depth <= DEPTH_DIRT + 8) then
   begin
      Result := TILE_SANDSTONE;
      Exit;
   end;

   if Depth <= DEPTH_DIRT_STONE then
   begin
      N := ValueNoise2D(ACol * 0.18, ARow * 0.18);
      if N > (0.4 - Depth * 0.02) then
         Result := TILE_STONE
      else
         Result := TILE_DIRT;
      if (N > 0.62) and (Depth < DEPTH_DIRT_STONE - 2) then
         Result := TILE_CLAY;
      N := ValueNoise2D(ACol * 0.22 + 50, ARow * 0.22 + 50);
      if N > 0.68 then
         Result := TILE_GRAVEL;
      Exit;
   end;

   if Depth <= DEPTH_STONE then
   begin
      Result := TILE_STONE;
      N := FBM2D(ACol * 0.06, ARow * 0.06, 2);
      if N > 0.55 then
         Result := TILE_GRANITE;
      N := FBM2D(ACol * 0.05 + 200, ARow * 0.05 + 200, 2);
      if N > 0.62 then
         Result := TILE_MARBLE;
      Exit;
   end;

   N := ValueNoise2D(ACol * 0.07, ARow * 0.07);
   if N > 0.3 then
      Result := TILE_MARBLE
   else
      Result := TILE_GRANITE;

   if ARow >= MAP_HEIGHT - 3 then
      Result := TILE_BEDROCK;
end;

procedure TTerrainGenerator.FillTiles(AMap: TGameMap);
var
   X, Y, SY: Integer;
   Biome: byte;
begin
   for X := 0 to MAP_WIDTH - 1 do
   begin
      SY := AMap.GetSurfaceY(X);
      Biome := AMap.GetBiome(X);
      for Y := 0 to MAP_HEIGHT - 1 do
         AMap.SetFG(X, Y, ForegroundTile(X, Y, SY, Biome));
   end;
end;

{ 4. Cave carving }

procedure TTerrainGenerator.CarveCaves(AMap: TGameMap);
var
   X, Y, SY: Integer;
   N: Single;
begin
   for X := 0 to MAP_WIDTH - 1 do
   begin
      SY := AMap.GetSurfaceY(X);
      for Y := SY + CAVE_START_DEPTH to MAP_HEIGHT - 4 do
      begin
         if AMap.GetFG(X, Y) = TILE_BEDROCK then
            Continue;
         N := FBM2D(X * 0.045, Y * 0.055, 3);
         if Abs(N) < CAVE_THRESHOLD then
            AMap.SetFG(X, Y, TILE_AIR);
      end;
   end;
end;

{ 5. Background (wall) layer
  ---------------------------------------------------------------------------
  FIX: Each background tile is derived from ForegroundTile() - the same
  biome-aware, depth-zoned, noise-driven function used for the foreground
  layer - without the cave-carving step applied on top.

  This guarantees that a cave carved through granite will expose granite
  walls behind it, a cave through marble exposes marble walls, clay pockets
  show clay walls, sandstone zones show sandstone walls, and so on.

  Previously this procedure used a simplified depth-only table (dirt up to
  DEPTH_DIRT, dirt up to DEPTH_DIRT_STONE, then stone everywhere), which
  meant every cave in the stone zone showed stone walls regardless of the
  actual vein material (granite, marble, etc.) at that coordinate. }

procedure TTerrainGenerator.FillBackground(AMap: TGameMap);
var
   X, Y, SY: Integer;
   Biome: byte;
   WallTile: byte;
begin
   for X := 0 to MAP_WIDTH - 1 do
   begin
      SY := AMap.GetSurfaceY(X);
      Biome := AMap.GetBiome(X);

      { Sky background: always air }
      for Y := 0 to SY - 1 do
         AMap.SetBG(X, Y, TILE_AIR);

      { Underground background: use ForegroundTile to get the correct
        material for this coordinate, bypassing cave carving.
        The surface row itself (Depth=0) correctly becomes dirt or sand wall,
        which is appropriate for cave entrances near the surface. }
      for Y := SY to MAP_HEIGHT - 1 do
      begin
         WallTile := ForegroundTile(X, Y, SY, Biome);
         AMap.SetBG(X, Y, WallTile);
      end;
   end;
end;

{ 6. Grass post-process }

procedure TTerrainGenerator.PlaceGrass(AMap: TGameMap);
var
   X, Y: Integer;
begin
   for X := 0 to MAP_WIDTH - 1 do
      for Y := 0 to MAP_HEIGHT - 1 do
         if AMap.GetFG(X, Y) <> TILE_AIR then
         begin
            if AMap.GetFG(X, Y) = TILE_DIRT then
               AMap.SetFG(X, Y, TILE_GRASS);
            Break;
         end;
end;

{ Public entry point }

procedure TTerrainGenerator.Generate(AMap: TGameMap);
begin
   AMap.Clear;
   NoiseSeed(FSeed);
   BuildHeightMap(AMap);
   BuildBiomeMap(AMap);
   FillTiles(AMap);
   CarveCaves(AMap);
   FillBackground(AMap);
   PlaceGrass(AMap);
end;

end.
