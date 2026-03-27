unit Terraria.Generator;

{$mode objfpc}{$H+}

{ TTerrainGenerator — fills a TGameMap with procedurally generated terrain.

  PIPELINE
  ─────────
  1. Seed the noise with a random or user-supplied seed.
  2. Build a 1D height map (surface Y row per column).
  3. Assign biomes left-to-right with a slow noise pass.
  4. Fill foreground tiles column-by-column:
       • air above surface
       • grass / sand at the exact surface row
       • dirt / sand / sandstone near surface
       • mixed dirt+stone transition zone
       • pure stone, granite, marble deep underground
       • bedrock at the very bottom
  5. Carve worm-like caves using 2D noise thresholding.
  6. Fill the background (wall) layer based on depth / biome.
  7. Post-process: convert the topmost solid dirt tile in each column to grass (simulating natural surface vegetation). }

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

      { ── Internal generation passes ─────────────────────────────────────── }
      procedure BuildHeightMap(AMap: TGameMap);
      procedure BuildBiomeMap(AMap: TGameMap);
      procedure FillTiles(AMap: TGameMap);
      procedure CarveCaves(AMap: TGameMap);
      procedure FillBackground(AMap: TGameMap);
      procedure PlaceGrass(AMap: TGameMap);

      { ── Per-column helpers ──────────────────────────────────────────────── }
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

{ ── 1. Height map ─────────────────────────────────────────────────────────── }

procedure TTerrainGenerator.BuildHeightMap(AMap: TGameMap);
var
   X, SY: Integer;
   N: Single;
begin
   for X := 0 to MAP_WIDTH - 1 do
   begin
      { 4 octaves of FBM for smooth hills + small surface detail }
      N := FBM1D(X * 0.008, 4, 2.0, 0.55);
      SY := BASE_SURFACE + Round(N * SURFACE_AMP);
      SY := Max(MIN_SURFACE, Min(MAX_SURFACE, SY));
      AMap.SetSurfaceY(X, SY);
   end;
end;

{ ── 2. Biome map ──────────────────────────────────────────────────────────── }

procedure TTerrainGenerator.BuildBiomeMap(AMap: TGameMap);
var
   X: Integer;
   N: Single;
   Biome: byte;
begin
   for X := 0 to MAP_WIDTH - 1 do
   begin
      { Very slow, smooth noise for wide biome transitions }
      N := (FBM1D(X * 0.003 + 900, 2) + 1.0) * 0.5; { 0..1 }
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

{ ── 3. Primary tile fill ──────────────────────────────────────────────────── }

function TTerrainGenerator.ForegroundTile(ACol, ARow, ASurface: Integer; ABiome: byte): byte;
var
   Depth: Integer;
   N: Single;
begin
   { ── Above surface ─ }
   if ARow < ASurface then
   begin
      Result := TILE_AIR;
      Exit;
   end;

   Depth := ARow - ASurface;

   { ── Surface row ── }
   if Depth = 0 then
   begin
      case ABiome of
         BIOME_DESERT:
            Result := TILE_SAND;
         else
            Result := TILE_DIRT; { will become grass in post-process }
      end;
      Exit;
   end;

   { ── Shallow sub-surface (dirt / sand zone) ─ }
   if Depth <= DEPTH_DIRT then
   begin
      case ABiome of
         BIOME_DESERT:
            Result := TILE_SAND;
         else
            Result := TILE_DIRT;
      end;
      Exit;
   end;

   { ── Desert sandstone layer ── }
   if (ABiome = BIOME_DESERT) and (Depth <= DEPTH_DIRT + 8) then
   begin
      Result := TILE_SANDSTONE;
      Exit;
   end;

   { ── Transition zone: dirt + stone mix ── }
   if Depth <= DEPTH_DIRT_STONE then
   begin
      { Use 2D noise to determine dirt vs stone patches }
      N := ValueNoise2D(ACol * 0.18, ARow * 0.18);
      { More stone as we go deeper in this zone }
      if N > (0.4 - Depth * 0.02) then
         Result := TILE_STONE
      else
         Result := TILE_DIRT;
      { Clay pockets near transition ─ }
      if (N > 0.62) and (Depth < DEPTH_DIRT_STONE - 2) then
         Result := TILE_CLAY;
      { Gravel pockets ─ }
      N := ValueNoise2D(ACol * 0.22 + 50, ARow * 0.22 + 50);
      if N > 0.68 then
         Result := TILE_GRAVEL;
      Exit;
   end;

   { ── Stone zone ── }
   if Depth <= DEPTH_STONE then
   begin
      Result := TILE_STONE;
      { Granite and marble veins using 2D noise }
      N := FBM2D(ACol * 0.06, ARow * 0.06, 2);
      if (N > 0.55) then
         Result := TILE_GRANITE;
      N := FBM2D(ACol * 0.05 + 200, ARow * 0.05 + 200, 2);
      if (N > 0.62) then
         Result := TILE_MARBLE;
      Exit;
   end;

   { ── Deep zone: mostly granite with marble ── }
   N := ValueNoise2D(ACol * 0.07, ARow * 0.07);
   if N > 0.3 then
      Result := TILE_MARBLE
   else
      Result := TILE_GRANITE;

   { ── Bedrock at the very bottom ── }
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

{ ── 4. Cave carving ───────────────────────────────────────────────────────── }

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
      { Worm-cave: two overlapping noise fields;
        carve where their absolute difference is small }
         N := FBM2D(X * 0.045, Y * 0.055, 3);
         if Abs(N) < CAVE_THRESHOLD then
            AMap.SetFG(X, Y, TILE_AIR);
      end;
   end;
end;

{ ── 5. Background (wall) layer ────────────────────────────────────────────── }

procedure TTerrainGenerator.FillBackground(AMap: TGameMap);
var
   X, Y, SY, Depth: Integer;
   Biome: byte;
   WallTile: byte;
begin
   for X := 0 to MAP_WIDTH - 1 do
   begin
      SY := AMap.GetSurfaceY(X);
      Biome := AMap.GetBiome(X);

      { Sky background: air }
      for Y := 0 to SY - 1 do
         AMap.SetBG(X, Y, TILE_AIR);

      { Underground background }
      for Y := SY to MAP_HEIGHT - 1 do
      begin
         Depth := Y - SY;

         if Depth <= DEPTH_DIRT then
            case Biome of
               BIOME_DESERT:
                  WallTile := TILE_SAND;
               else
                  WallTile := TILE_DIRT;
            end
         else
         if Depth <= DEPTH_DIRT_STONE then
            WallTile := TILE_DIRT
         else
            WallTile := TILE_STONE;

         if Y >= MAP_HEIGHT - 3 then
            WallTile := TILE_BEDROCK;

         AMap.SetBG(X, Y, WallTile);
      end;
   end;
end;

{ ── 6. Grass post-process ─────────────────────────────────────────────────── }

procedure TTerrainGenerator.PlaceGrass(AMap: TGameMap);
var
   X, Y: Integer;
begin
  { For every column, find the topmost non-air foreground tile.
    If it is dirt, convert it to grass. }
   for X := 0 to MAP_WIDTH - 1 do
      for Y := 0 to MAP_HEIGHT - 1 do
         if AMap.GetFG(X, Y) <> TILE_AIR then
         begin
            if AMap.GetFG(X, Y) = TILE_DIRT then
               AMap.SetFG(X, Y, TILE_GRASS);
            Break; { only the topmost tile }
         end;
end;

{ ── Public entry point ────────────────────────────────────────────────────── }

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
