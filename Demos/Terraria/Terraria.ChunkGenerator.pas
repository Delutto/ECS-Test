unit Terraria.ChunkGenerator;

{$mode objfpc}{$H+}

{ TChunkGenerator — procedural terrain + vegetation + cave decorations.

  BIOME SEGMENT MAP
  ─────────────────
  ComputeBiome(TX) has been replaced by a lazy biome-segment map
  (TBiomeSegmentMap).  Instead of evaluating FBM noise independently at
  every column, the generator now maintains a sorted list of contiguous
  biome segments.  Each segment covers [StartX .. EndX) and its width is
  clamped to the [MinBiomeWidth .. MaxBiomeWidth] range configured in the
  matching TBiomeParams.

  Segment generation algorithm
  ────────────────────────────
  1.  Start at X = 0.  Use FBM noise (same formula as before) at the
      segment midpoint to choose a preferred biome type.
  2.  Pick a seeded-random width in [MinWidth .. MaxWidth] for that biome
      using a fast LCG keyed on the segment index.
  3.  Extend the list leftward and rightward as new columns are queried.

  This makes biome transitions deterministic (same seed → same world) and
  gives the user direct control over biome extents via the editor sliders
  without changing any other system. }

interface

uses
   SysUtils, Math,
   Terraria.Common,
   Terraria.WorldChunk,
   Terraria.ChunkManager,
   Terraria.Noise,
   Terraria.GenParams;

   { ── Biome segment map ──────────────────────────────────────────────────── }

type
   TBiomeSegment = record
      StartX: Integer;   { inclusive }
      EndX: Integer;     { exclusive }
      Biome: byte;
   end;

   { Dynamic array of non-overlapping segments sorted ascending by StartX.
     Segment 0 always starts at or before the origin (X=0). }
   TBiomeSegmentArray = array of TBiomeSegment;

   { TBiomeSegmentMap — lazy, infinite, seed-deterministic biome layout.

     Call GetBiome(WorldX) at any world tile X; the map expands its
     coverage automatically.  Call Reset to discard cached segments when
     the generator parameters change (e.g. Regenerate pressed). }
   TBiomeSegmentMap = class
   private
      FSegments: TBiomeSegmentArray;
      FCount: Integer;
      FSeed: longint;
      FNextIdx: Integer;   { segment index counter for LCG keying }

      { Sample the FBM-based biome preference at world tile X.
        Identical formula as the old ComputeBiome. }
      function NoiseBiomeAt(TX: Integer; const P: TGenParams): byte;

      { Width for a given biome type using a seeded LCG.
        SegIdx is the segment's sequential index (used as LCG seed input). }
      function SegmentWidth(ABiome: byte; ASegIdx: Integer; const P: TGenParams): Integer;

      { Grow the segment list one step to the right. }
      procedure ExtendRight(const P: TGenParams);

      { Grow the segment list one step to the left. }
      procedure ExtendLeft(const P: TGenParams);
   public
      constructor Create(ASeed: longint);

      { Rebuild from scratch (call after params / seed change). }
      procedure Reset(ASeed: longint);

      { Return biome byte for world tile TX, generating segments as needed. }
      function GetBiome(TX: Integer; const P: TGenParams): byte;
   end;

   { ── TChunkGenerator ─────────────────────────────────────────────────────── }

type
   TChunkGenerator = class
   private
      FSeed: longint;
      FParams: TGenParams;
      FManager: TChunkManager;
      FBiomeMap: TBiomeSegmentMap;   { lazy segment map }

      { Terrain }
      function ComputeSurfaceY(TX: Integer): Integer;
      function GetSegmentBiome(TX: Integer): byte;   { replaces ComputeBiome }
      function ForegroundTile(TX, TY, ASurface: Integer; ABiome: byte): byte;
      function IsCaveAt(TX, TY: Integer; ACaveMult: Single): boolean;
      procedure GenerateColumn(AChunk: TWorldChunk; LX, ACX, ACY: Integer);
      procedure PlaceGrassColumn(AChunk: TWorldChunk; LX, ACY, ASurface: Integer);
      procedure FillBackgroundColumn(AChunk: TWorldChunk; LX, ACX, ACY, ASurface: Integer; ABiome: byte);

      { Vegetation }
      procedure PlantTree(AChunk: TWorldChunk; LX, SurfLY, TX, OriginTY: Integer; const V: TVegetationParams);
      procedure PlantShrub(AChunk: TWorldChunk; LX, SurfLY: Integer);
      procedure PlantCactus(AChunk: TWorldChunk; LX, SurfLY, TX, OriginTY: Integer; const V: TVegetationParams);
      procedure PlantVegetationForColumn(AChunk: TWorldChunk; LX, ACX, ACY: Integer);

      { Cave decorations }
      procedure PlaceCaveDecor(AChunk: TWorldChunk; LX, ACX, ACY: Integer);

      { Shared helpers }
      function SurfaceLocalY(AChunk: TWorldChunk; LX: Integer): Integer;
      function TileIsAir(AChunk: TWorldChunk; LX, LY: Integer): boolean; inline;
      function TileIsSolid(AChunk: TWorldChunk; LX, LY: Integer): boolean; inline;
      function TileIsDirt(AChunk: TWorldChunk; LX, LY: Integer): boolean; inline;
      function TileIsStone(AChunk: TWorldChunk; LX, LY: Integer): boolean; inline;
      procedure SafeSetFG(AChunk: TWorldChunk; LX, LY: Integer; ATile: byte);
      procedure SetFGWorld(WX, WY: Integer; ATile: byte);
   public
      constructor Create(AManager: TChunkManager; ASeed: longint);
      destructor Destroy; override;
      procedure GenerateChunk(ACX, ACY: Integer; AChunk: TWorldChunk);
      procedure ApplyParams;
      property Seed: longint read FSeed write FSeed;
      property Params: TGenParams read FParams write FParams;
   end;

implementation

uses
   P2D.Utils.Logger;

{ ==========================================================================
  TBiomeSegmentMap
  ========================================================================== }

   { ── LCG constants (Knuth MMIX) ─────────────────────────────────────────── }
const
   LCG_A = 6364136223846793005;
   LCG_C = 1442695040888963407;

{ Mixes seed + segment index into a pseudo-random 32-bit value. }
function LCGRand(ASeed: longint; AIdx: Integer): cardinal;
var
   S: int64;
begin
   S := int64(ASeed) * LCG_A + int64(AIdx) * LCG_C + LCG_C;
   S := S xor (S shr 33);
   Result := cardinal(S and $FFFFFFFF);
end;

constructor TBiomeSegmentMap.Create(ASeed: longint);
begin
   inherited Create;
   FSeed := ASeed;
   FCount := 0;
   FNextIdx := 0;
   SetLength(FSegments, 64);
end;

procedure TBiomeSegmentMap.Reset(ASeed: longint);
begin
   FSeed := ASeed;
   FCount := 0;
   FNextIdx := 0;
end;

function TBiomeSegmentMap.NoiseBiomeAt(TX: Integer; const P: TGenParams): byte;
var
   N: Single;
begin
   N := (FBM1D(TX * P.BiomeFreq + 900, P.BiomeOctaves) + 1.0) * 0.5;
   if N < P.DesertThreshold then
      Result := BIOME_DESERT
   else
   if N < P.ForestThreshold then
      Result := BIOME_PLAINS
   else
      Result := BIOME_FOREST;
end;

function TBiomeSegmentMap.SegmentWidth(ABiome: byte; ASegIdx: Integer; const P: TGenParams): Integer;
var
   BP: TBiomeParams;
   Range: Integer;
   Rnd: cardinal;
begin
   case ABiome of
      BIOME_DESERT:
         BP := P.BiomeDesert;
      BIOME_FOREST:
         BP := P.BiomeForest;
      else
         BP := P.BiomePlains;
   end;
   { Guarantee max >= min after clamping in ClampGenParams }
   Range := BP.MaxBiomeWidth - BP.MinBiomeWidth;
   if Range <= 0 then
   begin
      Result := BP.MinBiomeWidth;
      Exit;
   end;
   Rnd := LCGRand(FSeed, ASegIdx);
   Result := BP.MinBiomeWidth + Integer(Rnd mod cardinal(Range + 1));
end;

procedure TBiomeSegmentMap.ExtendRight(const P: TGenParams);
var
   NewStart, MidX, Width: Integer;
   Biome: byte;
   Seg: TBiomeSegment;
begin
   if FCount = 0 then
   begin
      { Bootstrap: build first segment anchored at X = 0 }
      Biome := NoiseBiomeAt(0, P);
      Width := SegmentWidth(Biome, FNextIdx, P);
      Inc(FNextIdx);
      Seg.StartX := 0;
      Seg.EndX := Width;
      Seg.Biome := Biome;
      if FCount >= Length(FSegments) then
         SetLength(FSegments, Length(FSegments) * 2);
      FSegments[0] := Seg;
      FCount := 1;
      Exit;
   end;
   { Extend one segment to the right }
   NewStart := FSegments[FCount - 1].EndX;
   MidX := NewStart + 1;
   Biome := NoiseBiomeAt(MidX, P);
   Width := SegmentWidth(Biome, FNextIdx, P);
   Inc(FNextIdx);
   Seg.StartX := NewStart;
   Seg.EndX := NewStart + Width;
   Seg.Biome := Biome;
   if FCount >= Length(FSegments) then
      SetLength(FSegments, Length(FSegments) * 2);
   FSegments[FCount] := Seg;
   Inc(FCount);
end;

procedure TBiomeSegmentMap.ExtendLeft(const P: TGenParams);
var
   NewEnd, MidX, Width: Integer;
   Biome: byte;
   Seg: TBiomeSegment;
   I: Integer;
begin
   { Extend one segment to the left }
   NewEnd := FSegments[0].StartX;
   MidX := NewEnd - 1;
   { Use a negative index offset to keep left-side indices distinct from
     right-side ones: use -(FNextIdx+1) mapped to a positive LCG input. }
   Biome := NoiseBiomeAt(MidX, P);
   Width := SegmentWidth(Biome, -(FNextIdx + 1), P);
   Inc(FNextIdx);
   Seg.StartX := NewEnd - Width;
   Seg.EndX := NewEnd;
   Seg.Biome := Biome;
   { Shift existing segments right by one to prepend }
   if FCount >= Length(FSegments) then
      SetLength(FSegments, Length(FSegments) * 2);
   for I := FCount downto 1 do
      FSegments[I] := FSegments[I - 1];
   FSegments[0] := Seg;
   Inc(FCount);
end;

function TBiomeSegmentMap.GetBiome(TX: Integer; const P: TGenParams): byte;
var
   Lo, Hi, Mid: Integer;
begin
   { Ensure at least one segment exists }
   if FCount = 0 then
      ExtendRight(P);

   { Expand right until TX is covered }
   while TX >= FSegments[FCount - 1].EndX do
      ExtendRight(P);

   { Expand left until TX is covered }
   while TX < FSegments[0].StartX do
      ExtendLeft(P);

   { Binary search for the segment containing TX }
   Lo := 0;
   Hi := FCount - 1;
   while Lo < Hi do
   begin
      Mid := (Lo + Hi) div 2;
      if FSegments[Mid].EndX <= TX then
         Lo := Mid + 1
      else
         Hi := Mid;
   end;
   Result := FSegments[Lo].Biome;
end;

{ ==========================================================================
  TChunkGenerator — helpers (unchanged from original)
  ========================================================================== }

procedure TChunkGenerator.SetFGWorld(WX, WY: Integer; ATile: byte);
var
   CY: Integer;
begin
   CY := TChunkManager.TileToChunkY(WY);
   if (CY < WORLD_MIN_CY) or (CY > WORLD_MAX_CY) then
      Exit;
   FManager.SetFG(WX, WY, ATile);
end;

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

procedure TChunkGenerator.SafeSetFG(AChunk: TWorldChunk; LX, LY: Integer; ATile: byte);
begin
   if AChunk.InLocalBounds(LX, LY) then
      AChunk.SetFG(LX, LY, ATile);
end;

{ ==========================================================================
  Constructor / Destructor / ApplyParams
  ========================================================================== }

constructor TChunkGenerator.Create(AManager: TChunkManager; ASeed: longint);
begin
   inherited Create;
   FManager := AManager;
   FSeed := ASeed;
   FParams := DefaultGenParams;
   FParams.Seed := ASeed;
   FBiomeMap := TBiomeSegmentMap.Create(ASeed);
end;

destructor TChunkGenerator.Destroy;
begin
   FBiomeMap.Free;
   inherited;
end;

procedure TChunkGenerator.ApplyParams;
begin
   ClampGenParams(FParams);
   FSeed := FParams.Seed;
   { Reset the segment cache so the new min/max-width settings take effect
     on the next GenerateChunk call. }
   FBiomeMap.Reset(FSeed);
end;

{ ==========================================================================
  Biome / surface computation
  ========================================================================== }

{ GetSegmentBiome replaces the old per-column ComputeBiome.
  All callers (ComputeSurfaceY, GenerateColumn, FillBackgroundColumn,
  PlantVegetationForColumn, PlaceCaveDecor) now go through here. }
function TChunkGenerator.GetSegmentBiome(TX: Integer): byte;
begin
   Result := FBiomeMap.GetBiome(TX, FParams);
end;

function TChunkGenerator.ComputeSurfaceY(TX: Integer): Integer;
var
   N: Single;
   Biome: byte;
   BP: TBiomeParams;
begin
   N := FBM1D(TX * FParams.SurfaceFreq, FParams.SurfaceOctaves, FParams.SurfaceLacun, FParams.SurfaceGain);
   Biome := GetSegmentBiome(TX);
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

{ ==========================================================================
  Tile generation (unchanged from original)
  ========================================================================== }

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
   Biome := GetSegmentBiome(TX);
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

procedure TChunkGenerator.PlaceGrassColumn(AChunk: TWorldChunk; LX, ACY, ASurface: Integer);
var
   LY, TY, ChunkOriginTY: Integer;
begin
   ChunkOriginTY := TChunkManager.ChunkToTileY(ACY);
   for LY := 0 to CHUNK_TILES_H - 1 do
      if AChunk.GetFG(LX, LY) <> TILE_AIR then
      begin
         TY := ChunkOriginTY + LY;
         if (TY = ASurface) and (AChunk.GetFG(LX, LY) = TILE_DIRT) then
            AChunk.SetFG(LX, LY, TILE_GRASS);
         Break;
      end;
end;

{ ==========================================================================
  Vegetation (unchanged)
  ========================================================================== }

procedure TChunkGenerator.PlantVegetationForColumn(AChunk: TWorldChunk; LX, ACX, ACY: Integer);
var
   TX: Integer;
   Biome: byte;
   V: TVegetationParams;
   SLY: Integer;
   TY, OriginTY: Integer;
   N: Single;
   Lc: Integer;
   CanPlace: boolean;
   SurfTile: byte;
begin
   TX := TChunkManager.ChunkToTileX(ACX) + LX;
   OriginTY := TChunkManager.ChunkToTileY(ACY);
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
      Exit;
   TY := OriginTY + SLY;
   if TY <> FManager.GetSurfaceY(TX) then
      Exit;
   if SLY = 0 then
      Exit;

   if V.TreeEnabled then
   begin
      N := (ValueNoise1D(TX * V.TreeNoiseFreq + FSeed * 0.001) + 1.0) * 0.5;
      if N < V.TreeNoiseThresh then
      begin
         CanPlace := True;
         for Lc := Max(0, LX - 2) to Min(CHUNK_TILES_W - 1, LX + 2) do
            if (Lc <> LX) and (AChunk.GetFG(Lc, SLY - 1) in [TILE_TREE_TRUNK, TILE_CACTUS]) then
            begin
               CanPlace := False;
               Break;
            end;
         if CanPlace then
            PlantTree(AChunk, LX, SLY, TX, OriginTY, V);
      end;
   end;

   if V.ShrubEnabled and TileIsAir(AChunk, LX, SLY - 1) then
   begin
      SurfTile := AChunk.GetFG(LX, SLY);
      if (SurfTile = TILE_GRASS) or (SurfTile = TILE_DIRT) or (SurfTile = TILE_SAND) then
      begin
         N := (ValueNoise1D(TX * V.ShrubNoiseFreq + FSeed * 0.007 + 333) + 1.0) * 0.5;
         if N < V.ShrubNoiseThresh then
            PlantShrub(AChunk, LX, SLY);
      end;
   end;

   if V.CactusEnabled and TileIsAir(AChunk, LX, SLY - 1) then
   begin
      N := (ValueNoise1D(TX * V.CactusNoiseFreq + FSeed * 0.003 + 777) + 1.0) * 0.5;
      if N < V.CactusNoiseThresh then
         PlantCactus(AChunk, LX, SLY, TX, OriginTY, V);
   end;
end;

procedure TChunkGenerator.PlantTree(AChunk: TWorldChunk; LX, SurfLY, TX, OriginTY: Integer; const V: TVegetationParams);
var
   TrunkH, R, H, DX, DY: Integer;
   TrunkBottomWY, TrunkTopWY, WY: Integer;
   CanopyWX, CanopyWY: Integer;
   LocalX, LocalY: Integer;
begin
   if SurfLY <= 0 then
      Exit;
   if not TileIsAir(AChunk, LX, SurfLY - 1) then
      Exit;
   TrunkH := V.TreeMinHeight + (Abs(Round(ValueNoise1D(LX * 7.3 + FSeed * 0.01) * 100)) mod Max(1, V.TreeMaxHeight - V.TreeMinHeight + 1));
   TrunkH := Max(V.TreeMinHeight, Min(V.TreeMaxHeight, TrunkH));
   TrunkBottomWY := OriginTY + SurfLY - 1;
   TrunkTopWY := TrunkBottomWY - TrunkH;
   if TrunkTopWY < TChunkManager.ChunkToTileY(WORLD_MIN_CY) then
      TrunkTopWY := TChunkManager.ChunkToTileY(WORLD_MIN_CY);
   for WY := TrunkTopWY to TrunkBottomWY do
   begin
      LocalX := LX;
      LocalY := WY - OriginTY;
      if AChunk.InLocalBounds(LocalX, LocalY) then
         AChunk.SetFG(LocalX, LocalY, TILE_TREE_TRUNK)
      else
         SetFGWorld(TX, WY, TILE_TREE_TRUNK);
   end;
   R := V.TreeCanopyRadius;
   H := V.TreeCanopyHeight;
   for DY := -H to H do
      for DX := -R to R do
      begin
         if (DX * DX * H * H + DY * DY * R * R) > (R * R * H * H) then
            Continue;
         CanopyWX := TX + DX;
         CanopyWY := TrunkTopWY + DY;
         LocalX := CanopyWX - TX + LX;
         LocalY := CanopyWY - OriginTY;
         if AChunk.InLocalBounds(LocalX, LocalY) then
         begin
            if TileIsAir(AChunk, LocalX, LocalY) then
               AChunk.SetFG(LocalX, LocalY, TILE_TREE_LEAF);
         end
         else
            SetFGWorld(CanopyWX, CanopyWY, TILE_TREE_LEAF);
      end;
end;

procedure TChunkGenerator.PlantShrub(AChunk: TWorldChunk; LX, SurfLY: Integer);
begin
   if SurfLY <= 0 then
      Exit;
   if not TileIsAir(AChunk, LX, SurfLY - 1) then
      Exit;
   SafeSetFG(AChunk, LX, SurfLY - 1, TILE_SHRUB);
end;

procedure TChunkGenerator.PlantCactus(AChunk: TWorldChunk; LX, SurfLY, TX, OriginTY: Integer; const V: TVegetationParams);
var
   CactH, LY, MidY, TopY: Integer;
   GrowLeft: boolean;
   NArmChance: Single;
   WYbase: Integer;
begin
   if SurfLY <= 1 then
      Exit;
   if not TileIsAir(AChunk, LX, SurfLY - 1) then
      Exit;
   CactH := V.CactusMinHeight + (Abs(Round(ValueNoise1D(LX * 11.7 + FSeed * 0.02) * 100)) mod Max(1, V.CactusMaxHeight - V.CactusMinHeight + 1));
   CactH := Max(V.CactusMinHeight, Min(V.CactusMaxHeight, CactH));
   for LY := SurfLY - 1 downto Max(0, SurfLY - CactH) do
      SafeSetFG(AChunk, LX, LY, TILE_CACTUS);
   if V.CactusArmChance > 0 then
   begin
      NArmChance := (ValueNoise1D(LX * 3.3 + FSeed * 0.03) + 1.0) * 0.5;
      if NArmChance < V.CactusArmChance then
      begin
         MidY := SurfLY - 1 - CactH div 2;
         if MidY >= 0 then
         begin
            GrowLeft := ValueNoise1D(LX * 17.1 + FSeed) > 0;
            WYbase := OriginTY + MidY;
            if GrowLeft then
            begin
               SetFGWorld(TX - 1, WYbase, TILE_CACTUS);
               SetFGWorld(TX - 1, WYbase - 1, TILE_CACTUS_TOP);
            end
            else
            begin
               SetFGWorld(TX + 1, WYbase, TILE_CACTUS);
               SetFGWorld(TX + 1, WYbase - 1, TILE_CACTUS_TOP);
            end;
         end;
      end;
   end;
   TopY := Max(0, SurfLY - CactH);
   SafeSetFG(AChunk, LX, TopY, TILE_CACTUS_TOP);
end;

{ ==========================================================================
  Cave decorations (unchanged)
  ========================================================================== }

procedure TChunkGenerator.PlaceCaveDecor(AChunk: TWorldChunk; LX, ACX, ACY: Integer);
var
   LY, TX, TY, Len, I: Integer;
   CD: TCaveDecoParams;
   N: Single;
   SurfTY: Integer;
   DepthBelowSurf: Integer;
begin
   CD := FParams.CaveDecor;
   TX := TChunkManager.ChunkToTileX(ACX) + LX;
   SurfTY := FManager.GetSurfaceY(TX);
   for LY := 1 to CHUNK_TILES_H - 2 do
   begin
      TY := TChunkManager.ChunkToTileY(ACY) + LY;
      DepthBelowSurf := TY - SurfTY;
      if DepthBelowSurf < FParams.CaveStartDepth then
         Continue;
      if not TileIsAir(AChunk, LX, LY) then
         Continue;

      if TileIsSolid(AChunk, LX, LY - 1) then
      begin
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
         if CD.MossEnabled and TileIsStone(AChunk, LX, LY - 1) then
         begin
            N := (ValueNoise1D(TX * CD.MossNoiseFreq + LY * 1.9 + FSeed * 0.03 + 2000) + 1.0) * 0.5;
            if N < CD.MossDensity then
               SafeSetFG(AChunk, LX, LY, TILE_MOSS);
         end;
      end;

      if TileIsSolid(AChunk, LX, LY + 1) then
      begin
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
         if CD.MushEnabled and (DepthBelowSurf >= CD.MushMinDepth) and TileIsAir(AChunk, LX, LY - 1) then
         begin
            N := (ValueNoise1D(TX * 0.9 + LY * 6.2 + FSeed * 0.07 + 4000) + 1.0) * 0.5;
            if N < CD.MushDensity then
               SafeSetFG(AChunk, LX, LY, TILE_MUSHROOM);
         end;
      end;
   end;
end;

{ ==========================================================================
  GenerateChunk
  ========================================================================== }

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
   begin
      TX := TChunkManager.ChunkToTileX(ACX) + LX;
      SY := FManager.GetSurfaceY(TX);
      PlaceGrassColumn(AChunk, LX, ACY, SY);
   end;

   for LX := 0 to CHUNK_TILES_W - 1 do
      PlantVegetationForColumn(AChunk, LX, ACX, ACY);

   if FParams.CavesEnabled then
      for LX := 0 to CHUNK_TILES_W - 1 do
         PlaceCaveDecor(AChunk, LX, ACX, ACY);
end;

end.
