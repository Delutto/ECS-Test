unit Terraria.ChunkGenerator;

{$mode objfpc}{$H+}

{ TChunkGenerator — procedural terrain driven by TGenParams.
  Now honours per-biome overrides for depth zones, ore thresholds,
  cave density and surface tile. }

interface

uses
   SysUtils, Math,
   Terraria.Common,
   Terraria.WorldChunk,
   Terraria.ChunkManager,
   Terraria.Noise,
   Terraria.GenParams;

type
   TChunkGenerator = class
   private
      FSeed: longint;
      FParams: TGenParams;
      FManager: TChunkManager;

      function ComputeSurfaceY(TX: Integer): Integer;
      function ComputeBiome(TX: Integer): byte;
      function ForegroundTile(TX, TY, ASurface: Integer; ABiome: byte): byte;
      function IsCaveAt(TX, TY: Integer; ACaveMult: Single): boolean;
      procedure GenerateColumn(AChunk: TWorldChunk; LX, ACX, ACY: Integer);
      procedure PlaceGrassColumn(AChunk: TWorldChunk; LX: Integer);
      procedure FillBackgroundColumn(AChunk: TWorldChunk; LX, ACX, ACY, ASurface: Integer; ABiome: byte);
   public
      constructor Create(AManager: TChunkManager; ASeed: longint);
      procedure GenerateChunk(ACX, ACY: Integer; AChunk: TWorldChunk);
      procedure ApplyParams;
      property Seed: longint read FSeed write FSeed;
      property Params: TGenParams read FParams write FParams;
   end;

implementation

constructor TChunkGenerator.Create(AManager: TChunkManager; ASeed: longint);
begin
   inherited Create;
   FManager := AManager;
   FSeed := ASeed;
   FParams := DefaultGenParams;
   FParams.Seed := ASeed;
end;

procedure TChunkGenerator.ApplyParams;
begin
   ClampGenParams(FParams);
   FSeed := FParams.Seed;
end;

{ ── Surface height (uses biome offsets from per-biome block) ─────────── }

function TChunkGenerator.ComputeSurfaceY(TX: Integer): Integer;
var
   N: Single;
   Biome: byte;
   BP: TBiomeParams;
begin
   N := FBM1D(TX * FParams.SurfaceFreq, FParams.SurfaceOctaves, FParams.SurfaceLacun, FParams.SurfaceGain);
   Biome := ComputeBiome(TX);
   case Biome of
      BIOME_DESERT:
         BP := FParams.BiomeDesert;
      BIOME_FOREST:
         BP := FParams.BiomeForest;
      else
         BP := FParams.BiomePlains;
   end;
   Result := FParams.BaseSurface + BP.SurfaceOffsetY + Round(N * (FParams.SurfaceAmp + BP.SurfaceAmpBonus));
   Result := Max(FParams.MinSurface, Min(FParams.MaxSurface, Result));
end;

{ ── Biome ─────────────────────────────────────────────────────────────── }

function TChunkGenerator.ComputeBiome(TX: Integer): byte;
var
   N: Single;
begin
   N := (FBM1D(TX * FParams.BiomeFreq + 900, FParams.BiomeOctaves) + 1.0) * 0.5;
   if N < FParams.DesertThreshold then
      Result := BIOME_DESERT
   else
   if N < FParams.ForestThreshold then
      Result := BIOME_PLAINS
   else
      Result := BIOME_FOREST;
end;

{ ── Tile assignment — respects per-biome depth and ore overrides ──────── }

function TChunkGenerator.ForegroundTile(TX, TY, ASurface: Integer; ABiome: byte): byte;
var
   Depth: Integer;
   N: Single;
   BP: TBiomeParams;
   EffDirt, EffDirtStone, EffSandstone: Integer;
   EffGranThr, EffMarbThr, EffClayThr, EffGravThr: Single;
begin
   if TY < ASurface then
   begin
      Result := TILE_AIR;
      Exit;
   end;
   Depth := TY - ASurface;

   { Resolve biome-specific overrides }
   case ABiome of
      BIOME_DESERT:
         BP := FParams.BiomeDesert;
      BIOME_FOREST:
         BP := FParams.BiomeForest;
      else
         BP := FParams.BiomePlains;
   end;

   EffDirt := IfThen(BP.DepthDirtOverride > 0, BP.DepthDirtOverride, FParams.DepthDirt);
   EffDirtStone := IfThen(BP.DepthDirtStoneOverride > 0, BP.DepthDirtStoneOverride, FParams.DepthDirtStone);
   EffSandstone := IfThen(BP.SandstoneDepth > 0, BP.SandstoneDepth, FParams.SandstoneExtra);
   EffGranThr := IfThen(BP.GraniteThreshold > 0, BP.GraniteThreshold, FParams.GraniteThreshold);
   EffMarbThr := IfThen(BP.MarbleThreshold > 0, BP.MarbleThreshold, FParams.MarbleThreshold);
   EffClayThr := IfThen(BP.ClayThreshold > 0, BP.ClayThreshold, FParams.ClayThreshold);
   EffGravThr := IfThen(BP.GravelThreshold > 0, BP.GravelThreshold, FParams.GravelThreshold);

   { Surface row — use override tile if set }
   if Depth = 0 then
   begin
      if BP.SurfaceTileOverride > 0 then
      begin
         Result := BP.SurfaceTileOverride;
         Exit;
      end;
      if ABiome = BIOME_DESERT then
         Result := TILE_SAND
      else
         Result := TILE_DIRT;
      Exit;
   end;

   { Shallow sub-surface }
   if Depth <= EffDirt then
   begin
      if ABiome = BIOME_DESERT then
         Result := TILE_SAND
      else
         Result := TILE_DIRT;
      Exit;
   end;

   { Desert sandstone layer }
   if (ABiome = BIOME_DESERT) and (Depth <= EffDirt + EffSandstone) then
   begin
      Result := TILE_SANDSTONE;
      Exit;
   end;

   { Transition zone }
   if Depth <= EffDirtStone then
   begin
      N := ValueNoise2D(TX * 0.18, TY * 0.18);
      if N > (0.4 - Depth * 0.02) then
         Result := TILE_STONE
      else
         Result := TILE_DIRT;
      if (N > EffClayThr) and (Depth < EffDirtStone - 2) then
         Result := TILE_CLAY;
      N := ValueNoise2D(TX * 0.22 + 50, TY * 0.22 + 50);
      if N > EffGravThr then
         Result := TILE_GRAVEL;
      Exit;
   end;

   { Stone zone }
   if Depth <= FParams.DepthStone then
   begin
      Result := TILE_STONE;
      N := FBM2D(TX * FParams.GraniteFreq, TY * FParams.GraniteFreq, 2);
      if N > EffGranThr then
         Result := TILE_GRANITE;
      N := FBM2D(TX * FParams.MarbleFreq + 200, TY * FParams.MarbleFreq + 200, 2);
      if N > EffMarbThr then
         Result := TILE_MARBLE;
      Exit;
   end;

   { Deep zone }
   N := ValueNoise2D(TX * 0.07, TY * 0.07);
   if N > FParams.DeepGraniteRatio then
      Result := TILE_MARBLE
   else
      Result := TILE_GRANITE;

   if TY >= TChunkManager.ChunkToTileY(WORLD_MAX_CY + 1) - FParams.BedrockRows then
      Result := TILE_BEDROCK;
end;

{ ── Cave carving — biome density multiplier ───────────────────────────── }

function TChunkGenerator.IsCaveAt(TX, TY: Integer; ACaveMult: Single): boolean;
var
   N, EffThreshold: Single;
begin
   if ACaveMult <= 0 then
   begin
      Result := False;
      Exit;
   end;
   N := FBM2D(TX * FParams.CaveFreqX, TY * FParams.CaveFreqY, FParams.CaveOctaves);
   { A higher multiplier widens the |N| < threshold band → more caves }
   EffThreshold := Min(0.49, FParams.CaveThreshold * ACaveMult);
   Result := Abs(N) < EffThreshold;
end;

{ ── Per-column generation ─────────────────────────────────────────────── }

procedure TChunkGenerator.GenerateColumn(AChunk: TWorldChunk; LX, ACX, ACY: Integer);
var
   TX, TY, WY, SY: Integer;
   Biome: byte;
   TileVal: byte;
   CaveMult: Single;
   BP: TBiomeParams;
begin
   TX := TChunkManager.ChunkToTileX(ACX) + LX;
   SY := ComputeSurfaceY(TX);
   Biome := ComputeBiome(TX);

   FManager.SetSurfaceY(TX, SY);
   FManager.SetBiome(TX, Biome);

   case Biome of
      BIOME_DESERT:
         BP := FParams.BiomeDesert;
      BIOME_FOREST:
         BP := FParams.BiomeForest;
      else
         BP := FParams.BiomePlains;
   end;
   CaveMult := BP.CaveDensityMult;

   for WY := 0 to CHUNK_TILES_H - 1 do
   begin
      TY := TChunkManager.ChunkToTileY(ACY) + WY;
      TileVal := ForegroundTile(TX, TY, SY, Biome);

      if FParams.CavesEnabled and (TileVal <> TILE_AIR) and (TileVal <> TILE_BEDROCK) and (TY >= SY + FParams.CaveStartDepth) then
         if IsCaveAt(TX, TY, CaveMult) then
            TileVal := TILE_AIR;

      AChunk.SetFG(LX, WY, TileVal);
   end;
end;

procedure TChunkGenerator.FillBackgroundColumn(AChunk: TWorldChunk; LX, ACX, ACY, ASurface: Integer; ABiome: byte);
var
   WY, TY, Depth: Integer;
   WallTile: byte;
   BP: TBiomeParams;
   EffDirt, EffDirtStone: Integer;
begin
   case ABiome of
      BIOME_DESERT:
         BP := FParams.BiomeDesert;
      BIOME_FOREST:
         BP := FParams.BiomeForest;
      else
         BP := FParams.BiomePlains;
   end;
   EffDirt := IfThen(BP.DepthDirtOverride > 0, BP.DepthDirtOverride, FParams.DepthDirt);
   EffDirtStone := IfThen(BP.DepthDirtStoneOverride > 0, BP.DepthDirtStoneOverride, FParams.DepthDirtStone);

   for WY := 0 to CHUNK_TILES_H - 1 do
   begin
      TY := TChunkManager.ChunkToTileY(ACY) + WY;
      Depth := TY - ASurface;

      if TY < ASurface then
      begin
         AChunk.SetBG(LX, WY, TILE_AIR);
         Continue;
      end;

      if Depth <= EffDirt then
         if ABiome = BIOME_DESERT then
            WallTile := TILE_SAND
         else
            WallTile := TILE_DIRT
      else
      if Depth <= EffDirtStone then
         WallTile := TILE_DIRT
      else
         WallTile := TILE_STONE;

      if TY >= TChunkManager.ChunkToTileY(WORLD_MAX_CY + 1) - FParams.BedrockRows then
         WallTile := TILE_BEDROCK;

      AChunk.SetBG(LX, WY, WallTile);
   end;
end;

procedure TChunkGenerator.PlaceGrassColumn(AChunk: TWorldChunk; LX: Integer);
var
   WY: Integer;
begin
   for WY := 0 to CHUNK_TILES_H - 1 do
      if AChunk.GetFG(LX, WY) <> TILE_AIR then
      begin
         if AChunk.GetFG(LX, WY) = TILE_DIRT then
            AChunk.SetFG(LX, WY, TILE_GRASS);
         Break;
      end;
end;

procedure TChunkGenerator.GenerateChunk(ACX, ACY: Integer; AChunk: TWorldChunk);
var
   LX, TX, SY: Integer;
   Biome: byte;
begin
   NoiseSeed(FSeed);
   for LX := 0 to CHUNK_TILES_W - 1 do
      GenerateColumn(AChunk, LX, ACX, ACY);
   for LX := 0 to CHUNK_TILES_W - 1 do
   begin
      TX := TChunkManager.ChunkToTileX(ACX) + LX;
      SY := FManager.GetSurfaceY(TX);
      Biome := FManager.GetBiome(TX);
      FillBackgroundColumn(AChunk, LX, ACX, ACY, SY, Biome);
   end;
   for LX := 0 to CHUNK_TILES_W - 1 do
      PlaceGrassColumn(AChunk, LX);
end;

end.
