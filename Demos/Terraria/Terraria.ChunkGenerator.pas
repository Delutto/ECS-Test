unit Terraria.ChunkGenerator;

{$mode objfpc}{$H+}

{ TChunkGenerator — procedural terrain + vegetation + cave decorations.

  GENERATION PIPELINE PER CHUNK
  ──────────────────────────────
  1. GenerateColumn        – solid tiles (terrain + biome depth zones)
  2. FillBackgroundColumn  – wall tiles behind air
  3. PlaceGrassColumn      – topmost dirt → grass
  4. PlantVegetation       – trees, shrubs, cacti on the surface
  5. PlaceCaveDecor        – roots/vines (ceiling), stalactites/stalagmites,
                             mushrooms (floor), moss patches
  6. PlaceVegetationForColumn – helper driving passes 4+5 per column

  ALGORITHM NOTES
  ────────────────
  • All placement uses value-noise for irregular spacing rather than simple
    random chance, so vegetation clusters naturally without tiling artefacts.
  • Trees are written top-down:  canopy first, then trunk downward into the
    surface row.  This lets a single column pass handle the full tree.
  • Cacti grow upward from the sand surface; arms branch off at mid-height.
  • Cave decorations are placed only inside air tiles adjacent to solid tiles:
    roots/vines from dirt ceilings, stalactites from stone ceilings,
    stalagmites from stone floors, mushrooms on flat stone/dirt floors,
    moss on ceiling/wall stone.
  • The foreground layer is used for all decorations (they are rendered
    as translucent overlays by TChunkRenderSystem). }

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

      { Terrain }
      function ComputeSurfaceY(TX: Integer): Integer;
      function ComputeBiome(TX: Integer): byte;
      function ForegroundTile(TX, TY, ASurface: Integer; ABiome: byte): byte;
      function IsCaveAt(TX, TY: Integer; ACaveMult: Single): boolean;
      procedure GenerateColumn(AChunk: TWorldChunk; LX, ACX, ACY: Integer);
      procedure PlaceGrassColumn(AChunk: TWorldChunk; LX: Integer);
      procedure FillBackgroundColumn(AChunk: TWorldChunk; LX, ACX, ACY, ASurface: Integer; ABiome: byte);

      { Vegetation }
      procedure PlantTree(AChunk: TWorldChunk; LX, SurfLY: Integer; const V: TVegetationParams);
      procedure PlantShrub(AChunk: TWorldChunk; LX, SurfLY: Integer);
      procedure PlantCactus(AChunk: TWorldChunk; LX, SurfLY: Integer; const V: TVegetationParams);
      procedure PlantVegetationForColumn(AChunk: TWorldChunk; LX, ACX, ACY: Integer);

      { Cave decorations }
      procedure PlaceCaveDecor(AChunk: TWorldChunk; LX, ACX, ACY: Integer);

      { Shared helpers }
      function SurfaceLocalY(AChunk: TWorldChunk; LX: Integer): Integer;
      function TileIsAir(AChunk: TWorldChunk; LX, LY: Integer): boolean; inline;
      function TileIsSolid(AChunk: TWorldChunk; LX, LY: Integer): boolean; inline;
      function TileIsDirt(AChunk: TWorldChunk; LX, LY: Integer): boolean; inline;
      function TileIsStone(AChunk: TWorldChunk; LX, LY: Integer): boolean; inline;
      { Safe set — clamps to chunk bounds, does nothing if LY out of range }
      procedure SafeSetFG(AChunk: TWorldChunk; LX, LY: Integer; ATile: byte);
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

{ ── Shared tile helpers ────────────────────────────────────────────────── }

function TChunkGenerator.TileIsAir(AChunk: TWorldChunk; LX, LY: Integer): boolean;
begin
   Result := AChunk.InLocalBounds(LX, LY) and (AChunk.GetFG(LX, LY) = TILE_AIR);
end;

function TChunkGenerator.TileIsSolid(AChunk: TWorldChunk; LX, LY: Integer): boolean;
var
   T: byte;
begin
   if not AChunk.InLocalBounds(LX, LY) then
   begin
      Result := True;
      Exit;
   end;
   T := AChunk.GetFG(LX, LY);
   Result := (T <> TILE_AIR) and (T < TILE_SHRUB);
end;

function TChunkGenerator.TileIsDirt(AChunk: TWorldChunk; LX, LY: Integer): boolean;
var
   T: byte;
begin
   if not AChunk.InLocalBounds(LX, LY) then
   begin
      Result := False;
      Exit;
   end;
   T := AChunk.GetFG(LX, LY);
   Result := (T = TILE_DIRT) or (T = TILE_GRASS) or (T = TILE_CLAY) or (T = TILE_GRAVEL);
end;

function TChunkGenerator.TileIsStone(AChunk: TWorldChunk; LX, LY: Integer): boolean;
var
   T: byte;
begin
   if not AChunk.InLocalBounds(LX, LY) then
   begin
      Result := False;
      Exit;
   end;
   T := AChunk.GetFG(LX, LY);
   Result := (T = TILE_STONE) or (T = TILE_GRANITE) or (T = TILE_MARBLE) or (T = TILE_SANDSTONE) or (T = TILE_BEDROCK);
end;

procedure TChunkGenerator.SafeSetFG(AChunk: TWorldChunk; LX, LY: Integer; ATile: byte);
begin
   if AChunk.InLocalBounds(LX, LY) then
      AChunk.SetFG(LX, LY, ATile);
end;

{ ── Find the top-most non-air local Y in a column (−1 if all air) ──────── }

function TChunkGenerator.SurfaceLocalY(AChunk: TWorldChunk; LX: Integer): Integer;
var
   LY: Integer;
begin
   Result := -1;
   for LY := 0 to CHUNK_TILES_H - 1 do
      if AChunk.GetFG(LX, LY) <> TILE_AIR then
      begin
         Result := LY;
         Exit;
      end;
end;

{ ── Terrain generation (unchanged from previous version) ───────────────── }

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
   if Depth <= EffDirt then
   begin
      if ABiome = BIOME_DESERT then
         Result := TILE_SAND
      else
         Result := TILE_DIRT;
      Exit;
   end;
   if (ABiome = BIOME_DESERT) and (Depth <= EffDirt + EffSandstone) then
   begin
      Result := TILE_SANDSTONE;
      Exit;
   end;
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
   N := ValueNoise2D(TX * 0.07, TY * 0.07);
   if N > FParams.DeepGraniteRatio then
      Result := TILE_MARBLE
   else
      Result := TILE_GRANITE;
   if TY >= TChunkManager.ChunkToTileY(WORLD_MAX_CY + 1) - FParams.BedrockRows then
      Result := TILE_BEDROCK;
end;

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
   EffThreshold := Min(0.49, FParams.CaveThreshold * ACaveMult);
   Result := Abs(N) < EffThreshold;
end;

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

{ ── VEGETATION ─────────────────────────────────────────────────────────── }

procedure TChunkGenerator.PlantShrub(AChunk: TWorldChunk; LX, SurfLY: Integer);
{ Single-tile shrub directly above the surface row }
begin
   if SurfLY <= 0 then
      Exit;
   if not TileIsAir(AChunk, LX, SurfLY - 1) then
      Exit;
   SafeSetFG(AChunk, LX, SurfLY - 1, TILE_SHRUB);
end;

procedure TChunkGenerator.PlantTree(AChunk: TWorldChunk; LX, SurfLY: Integer; const V: TVegetationParams);
{ Grows a deciduous tree upward from SurfLY-1.
  Trunk: 1-wide column of TILE_TREE_TRUNK.
  Canopy: filled oval of TILE_TREE_LEAF centred on the trunk top. }
var
   TrunkH, CX, CY, R, H, DX, DY, LY: Integer;
   NTop, Lx2, Ly2: Integer;
begin
   if SurfLY <= 0 then
      Exit;
   if not TileIsAir(AChunk, LX, SurfLY - 1) then
      Exit;

   { random-ish height from noise }
   TrunkH := V.TreeMinHeight + (Abs(Round(ValueNoise1D(LX * 7.3 + FSeed * 0.01) * 100)) mod Max(1, V.TreeMaxHeight - V.TreeMinHeight + 1));
   TrunkH := Max(V.TreeMinHeight, Min(V.TreeMaxHeight, TrunkH));

   NTop := SurfLY - 1 - TrunkH;   { local Y of trunk top }
   if NTop < 0 then
      TrunkH := SurfLY - 1;   { clamp to chunk top }
   NTop := SurfLY - 1 - TrunkH;
   if NTop < 0 then
      NTop := 0;

   { Trunk }
   for LY := NTop to SurfLY - 1 do
      SafeSetFG(AChunk, LX, LY, TILE_TREE_TRUNK);

   { Canopy — oval }
   R := V.TreeCanopyRadius;
   H := V.TreeCanopyHeight;
   CX := LX;
   CY := NTop;   { canopy centred at trunk top }

   for DY := -H to H do
      for DX := -(R) to R do
      begin
         { Oval test: (DX/R)^2 + (DY/H)^2 <= 1 }
         if (DX * DX * H * H + DY * DY * R * R) <= (R * R * H * H) then
         begin
            Lx2 := CX + DX;
            Ly2 := CY + DY;
            if AChunk.InLocalBounds(Lx2, Ly2) and TileIsAir(AChunk, Lx2, Ly2) then
               SafeSetFG(AChunk, Lx2, Ly2, TILE_TREE_LEAF);
         end;
      end;
end;

procedure TChunkGenerator.PlantCactus(AChunk: TWorldChunk; LX, SurfLY: Integer; const V: TVegetationParams);
{ Grows a cactus upward.  May sprout one arm (horizontal 1-tile extension)
  at roughly mid-height on either side. }
var
   CactH, LY, MidY, ArmY, TopY: Integer;
   GrowLeft: boolean;
   NArmChance: Single;
begin
   if SurfLY <= 1 then
      Exit;
   if not TileIsAir(AChunk, LX, SurfLY - 1) then
      Exit;

   CactH := V.CactusMinHeight + (Abs(Round(ValueNoise1D(LX * 11.7 + FSeed * 0.02) * 100)) mod Max(1, V.CactusMaxHeight - V.CactusMinHeight + 1));
   CactH := Max(V.CactusMinHeight, Min(V.CactusMaxHeight, CactH));

   for LY := SurfLY - 1 downto Max(0, SurfLY - CactH) do
      SafeSetFG(AChunk, LX, LY, TILE_CACTUS);

   { Arm }
   if V.CactusArmChance > 0 then
   begin
      NArmChance := (ValueNoise1D(LX * 3.3 + FSeed * 0.03) + 1.0) * 0.5;
      if NArmChance < V.CactusArmChance then
      begin
         MidY := SurfLY - 1 - CactH div 2;
         if MidY >= 0 then
         begin
            GrowLeft := ValueNoise1D(LX * 17.1 + FSeed) > 0;
            ArmY := MidY;
            if GrowLeft then
            begin
               SafeSetFG(AChunk, LX - 1, ArmY, TILE_CACTUS);
               SafeSetFG(AChunk, LX - 1, ArmY - 1, TILE_CACTUS_TOP);
            end
            else
            begin
               SafeSetFG(AChunk, LX + 1, ArmY, TILE_CACTUS);
               SafeSetFG(AChunk, LX + 1, ArmY - 1, TILE_CACTUS_TOP);
            end;
         end;
      end;
   end;

   { Cactus top cap }
   TopY := Max(0, SurfLY - CactH);
   SafeSetFG(AChunk, LX, TopY, TILE_CACTUS_TOP);
end;

procedure TChunkGenerator.PlantVegetationForColumn(AChunk: TWorldChunk; LX, ACX, ACY: Integer);
var
   TX: Integer;
   Biome: byte;
   V: TVegetationParams;
   SLY: Integer;   { surface local Y inside the chunk }
   N: Single;
   Lc: Integer;
   CanPlace: Boolean;
begin
   TX := TChunkManager.ChunkToTileX(ACX) + LX;
   Biome := FManager.GetBiome(TX);

   case Biome of
      BIOME_DESERT:
         V := FParams.VegDesert;
      BIOME_FOREST:
         V := FParams.VegForest;
      else
         V := FParams.VegPlains;
   end;

   SLY := SurfaceLocalY(AChunk, LX);
   if SLY < 0 then
      Exit;   { entire column is air — nothing to plant on }

   { Only grow vegetation when this chunk row contains the surface }
   if SLY = 0 then
      Exit;   { surface is above this chunk row }

   { ── Trees ── }
   if V.TreeEnabled then
   begin
      N := (ValueNoise1D(TX * V.TreeNoiseFreq + FSeed * 0.001) + 1.0) * 0.5;
      if N < V.TreeNoiseThresh then
      begin
         { Ensure adjacent columns are clear (3-tile gap rule) }
         CanPlace := True;
         for Lc := Max(0, LX - 2) to Min(CHUNK_TILES_W - 1, LX + 2) do
            if (Lc <> LX) and (AChunk.GetFG(Lc, SLY - 1) in [TILE_TREE_TRUNK, TILE_CACTUS]) then
            begin
               CanPlace := False;
               Break;
            end;
         if CanPlace then
            PlantTree(AChunk, LX, SLY, V);
      end;
   end;

   { ── Shrubs / ferns (only if column has no tree trunk above surface) ── }
   if V.ShrubEnabled and TileIsAir(AChunk, LX, SLY - 1) then
   begin
      N := (ValueNoise1D(TX * V.ShrubNoiseFreq + FSeed * 0.007 + 333) + 1.0) * 0.5;
      if N < V.ShrubNoiseThresh then
         PlantShrub(AChunk, LX, SLY);
   end;

   { ── Cacti ── }
   if V.CactusEnabled and TileIsAir(AChunk, LX, SLY - 1) then
   begin
      N := (ValueNoise1D(TX * V.CactusNoiseFreq + FSeed * 0.003 + 777) + 1.0) * 0.5;
      if N < V.CactusNoiseThresh then
         PlantCactus(AChunk, LX, SLY, V);
   end;
end;

{ ── CAVE DECORATIONS ────────────────────────────────────────────────────── }

procedure TChunkGenerator.PlaceCaveDecor(AChunk: TWorldChunk; LX, ACX, ACY: Integer);
var
   LY, TX, WY, TY, Len, I: Integer;
   CD: TCaveDecoParams;
   N: Single;
   SurfTY: Integer;   { surface in world coords for this column }
   Biome: byte;
   DepthBelowSurf: Integer;
begin
   CD := FParams.CaveDecor;
   TX := TChunkManager.ChunkToTileX(ACX) + LX;
   SurfTY := FManager.GetSurfaceY(TX);
   Biome := FManager.GetBiome(TX);

   for LY := 1 to CHUNK_TILES_H - 2 do
   begin
      TY := TChunkManager.ChunkToTileY(ACY) + LY;
      DepthBelowSurf := TY - SurfTY;
      if DepthBelowSurf < FParams.CaveStartDepth then
         Continue;

      { Only work in air tiles }
      if not TileIsAir(AChunk, LX, LY) then
         Continue;

      { ── Ceiling decorations (tile above is solid) ── }
      if TileIsSolid(AChunk, LX, LY - 1) then
      begin
         { Roots hang from dirt/clay ceilings }
         if CD.RootsEnabled and TileIsDirt(AChunk, LX, LY - 1) then
         begin
            N := (ValueNoise1D(TX * CD.RootsNoiseFreq + LY * 2.3 + FSeed * 0.02) + 1.0) * 0.5;
            if N < CD.RootsDensity then
            begin
               Len := CD.RootsMinLen + Abs(Round(N * 100)) mod Max(1, CD.RootsMaxLen - CD.RootsMinLen + 1);
               for I := 0 to Len - 1 do
                  if TileIsAir(AChunk, LX, LY + I) then
                     SafeSetFG(AChunk, LX, LY + I, TILE_ROOT)
                  else
                     Break;
            end;
         end;

         { Vines hang from stone/granite ceilings (deeper) }
         if CD.VinesEnabled and TileIsStone(AChunk, LX, LY - 1) and (DepthBelowSurf > FParams.DepthDirt + 4) then
         begin
            N := (ValueNoise1D(TX * CD.VinesNoiseFreq + LY * 3.1 + FSeed * 0.04 + 500) + 1.0) * 0.5;
            if N < CD.VinesDensity then
            begin
               Len := CD.VinesMinLen + Abs(Round(N * 100)) mod Max(1, CD.VinesMaxLen - CD.VinesMinLen + 1);
               for I := 0 to Len - 1 do
                  if TileIsAir(AChunk, LX, LY + I) then
                     SafeSetFG(AChunk, LX, LY + I, TILE_VINE)
                  else
                     Break;
            end;
         end;

         { Stalactites hang from stone ceilings }
         if CD.StalEnabled and TileIsStone(AChunk, LX, LY - 1) then
         begin
            N := (ValueNoise1D(TX * CD.StalNoiseFreq + LY * 5.7 + FSeed * 0.05 + 1000) + 1.0) * 0.5;
            if N < CD.StalDensity then
            begin
               Len := CD.StalMinLen + Abs(Round(N * 100)) mod Max(1, CD.StalMaxLen - CD.StalMinLen + 1);
               for I := 0 to Len - 1 do
                  if TileIsAir(AChunk, LX, LY + I) then
                     SafeSetFG(AChunk, LX, LY + I, TILE_STALACTITE)
                  else
                     Break;
            end;
         end;

         { Moss on stone ceiling }
         if CD.MossEnabled and TileIsStone(AChunk, LX, LY - 1) then
         begin
            N := (ValueNoise1D(TX * CD.MossNoiseFreq + LY * 1.9 + FSeed * 0.03 + 2000) + 1.0) * 0.5;
            if N < CD.MossDensity then
               SafeSetFG(AChunk, LX, LY, TILE_MOSS);
         end;
      end;

      { ── Floor decorations (tile below is solid) ── }
      if TileIsSolid(AChunk, LX, LY + 1) then
      begin
         { Stalagmites grow from stone floor }
         if CD.StalEnabled and TileIsStone(AChunk, LX, LY + 1) then
         begin
            N := (ValueNoise1D(TX * CD.StalNoiseFreq + LY * 4.4 + FSeed * 0.06 + 3000) + 1.0) * 0.5;
            if N < (CD.StalDensity * 0.6) then
            begin
               Len := CD.StalMinLen + Abs(Round(N * 100)) mod Max(1, CD.StalMaxLen - CD.StalMinLen + 1);
               for I := 0 to Len - 1 do
                  if TileIsAir(AChunk, LX, LY - I) then
                     SafeSetFG(AChunk, LX, LY - I, TILE_STALAGMITE)
                  else
                     Break;
            end;
         end;

         { Mushrooms on flat floor (must have 2 air tiles above) }
         if CD.MushEnabled and (DepthBelowSurf >= CD.MushMinDepth) and TileIsAir(AChunk, LX, LY - 1) then
         begin
            N := (ValueNoise1D(TX * 0.9 + LY * 6.2 + FSeed * 0.07 + 4000) + 1.0) * 0.5;
            if N < CD.MushDensity then
               SafeSetFG(AChunk, LX, LY, TILE_MUSHROOM);
         end;
      end;
   end;
end;

{ ── Public entry point ───────────────────────────────────────────────── }

procedure TChunkGenerator.GenerateChunk(ACX, ACY: Integer; AChunk: TWorldChunk);
var
   LX, TX, SY: Integer;
   Biome: byte;
begin
   NoiseSeed(FSeed);

   { Pass 1: solid tiles }
   for LX := 0 to CHUNK_TILES_W - 1 do
      GenerateColumn(AChunk, LX, ACX, ACY);

   { Pass 2: background walls }
   for LX := 0 to CHUNK_TILES_W - 1 do
   begin
      TX := TChunkManager.ChunkToTileX(ACX) + LX;
      SY := FManager.GetSurfaceY(TX);
      Biome := FManager.GetBiome(TX);
      FillBackgroundColumn(AChunk, LX, ACX, ACY, SY, Biome);
   end;

   { Pass 3: grass on topmost dirt }
   for LX := 0 to CHUNK_TILES_W - 1 do
      PlaceGrassColumn(AChunk, LX);

   { Pass 4: surface vegetation }
   for LX := 0 to CHUNK_TILES_W - 1 do
      PlantVegetationForColumn(AChunk, LX, ACX, ACY);

   { Pass 5: cave decorations }
   if FParams.CavesEnabled then
      for LX := 0 to CHUNK_TILES_W - 1 do
         PlaceCaveDecor(AChunk, LX, ACX, ACY);
end;

end.
