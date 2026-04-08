unit Terraria.ChunkGenerator;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math, Terraria.Common, Terraria.WorldChunk, Terraria.ChunkManager, Terraria.Noise, Terraria.GenParams, Terraria.Liquid;

type
   TBiomeSegment = record
      StartX, EndX: Integer;
      Biome: byte;
   end;
   TBiomeSegmentArray = array of TBiomeSegment;

   TBiomeSegmentMap = class
   private
      FSegs: TBiomeSegmentArray;
      FCount, FNextIdx: Integer;
      FSeed: longint;
      function NoiseBiomeAt(TX: Integer; const P: TGenParams): byte;
      function SegWidth(B: byte; Idx: Integer; const P: TGenParams): Integer;
      procedure ExtRight(const P: TGenParams);
      procedure ExtLeft(const P: TGenParams);
   public
      constructor Create(S: longint);
      procedure Reset(S: longint);
      function GetBiome(TX: Integer; const P: TGenParams): byte;
   end;

   TChunkGenerator = class
   private
      FSeed: longint;
      FParams: TGenParams;
      FManager: TChunkManager;
      FBiomeMap: TBiomeSegmentMap;
      FLiquidPlacer: TLiquidPlacer;
      function ComputeSurfaceY(TX: Integer): Integer;
      function GetSegmentBiome(TX: Integer): byte;
      function ForegroundTile(TX, TY, _AS: Integer; AB: byte): byte;
      function IsCaveAt(TX, TY, ASY: Integer; ACM: Single): boolean;
      procedure GenerateColumn(AC: TWorldChunk; LX, ACX, ACY: Integer);
      procedure PlaceGrassColumn(AC: TWorldChunk; LX, ACY, _AS: Integer);
      procedure FillBGColumn(AC: TWorldChunk; LX, ACX, ACY, _AS: Integer; AB: byte);
      procedure PlantTree(AC: TWorldChunk; LX, SLY, TX, OTY: Integer; const V: TVegetationParams);
      procedure PlantShrub(AC: TWorldChunk; LX, SLY: Integer);
      procedure PlantCactus(AC: TWorldChunk; LX, SLY, TX, OTY: Integer; const V: TVegetationParams);
      procedure PlantVeg(AC: TWorldChunk; LX, ACX, ACY: Integer);
      procedure PlaceCaveDecor(AC: TWorldChunk; LX, ACX, ACY: Integer);
      function SurfLY(AC: TWorldChunk; LX: Integer): Integer;
      function IsAir(AC: TWorldChunk; LX, LY: Integer): boolean; inline;
      function IsSolid(AC: TWorldChunk; LX, LY: Integer): boolean; inline;
      function IsDirt(AC: TWorldChunk; LX, LY: Integer): boolean; inline;
      function IsStone(AC: TWorldChunk; LX, LY: Integer): boolean; inline;
      procedure SafeSet(AC: TWorldChunk; LX, LY: Integer; T: byte);
      procedure SetWorld(WX, WY: Integer; T: byte);
   public
      constructor Create(AM: TChunkManager; S: longint);
      destructor Destroy; override;
      procedure GenerateChunk(ACX, ACY: Integer; AC: TWorldChunk);
      procedure ApplyParams;
      property Seed: longint read FSeed write FSeed;
      property Params: TGenParams read FParams write FParams;
      property LiquidPlacer: TLiquidPlacer read FLiquidPlacer;
   end;

implementation

uses
   P2D.Utils.Logger;

const
   LCA = 6364136223846793005;
   LCC = 1442695040888963407;

function LCGR(S: longint; I: Integer): cardinal;
var
   V: int64;
begin
   V := int64(S) * LCA + int64(I) * LCC + LCC;
   V := V xor (V shr 33);
   Result := cardinal(V and $FFFFFFFF);
end;

constructor TBiomeSegmentMap.Create(S: longint);
begin
   inherited Create;
   FSeed := S;
   FCount := 0;
   FNextIdx := 0;
   SetLength(FSegs, 64);
end;

procedure TBiomeSegmentMap.Reset(S: longint);
begin
   FSeed := S;
   FCount := 0;
   FNextIdx := 0;
end;

function TBiomeSegmentMap.NoiseBiomeAt(TX: Integer; const P: TGenParams): byte;
var
   N: Single;
begin
   N := (FBM1D(TX * P.BiomeFreq + 900, P.BiomeOctaves) + 1) * 0.5;
   if N < P.DesertThreshold then
      Result := BIOME_DESERT
   else
   if N < P.ForestThreshold then
      Result := BIOME_PLAINS
   else
      Result := BIOME_FOREST;
end;

function TBiomeSegmentMap.SegWidth(B: byte; Idx: Integer; const P: TGenParams): Integer;
var
   BP: TBiomeParams;
   R: Integer;
   Rn: cardinal;
begin
   case B of
      BIOME_DESERT:
         BP := P.BiomeDesert;
      BIOME_FOREST:
         BP := P.BiomeForest;
      else
         BP := P.BiomePlains;
   end;
   R := BP.MaxBiomeWidth - BP.MinBiomeWidth;
   if R <= 0 then
   begin
      Result := BP.MinBiomeWidth;
      Exit;
   end;
   Rn := LCGR(FSeed, Idx);
   Result := BP.MinBiomeWidth + Integer(Rn mod cardinal(R + 1));
end;

procedure TBiomeSegmentMap.ExtRight(const P: TGenParams);
var
   NS, MX, W: Integer;
   B: byte;
   Sg: TBiomeSegment;
begin
   if FCount = 0 then
   begin
      B := NoiseBiomeAt(0, P);
      W := SegWidth(B, FNextIdx, P);
      Inc(FNextIdx);
      Sg.StartX := 0;
      Sg.EndX := W;
      Sg.Biome := B;
      if FCount >= Length(FSegs) then
         SetLength(FSegs, Length(FSegs) * 2);
      FSegs[0] := Sg;
      FCount := 1;
      Exit;
   end;
   NS := FSegs[FCount - 1].EndX;
   MX := NS + 1;
   B := NoiseBiomeAt(MX, P);
   W := SegWidth(B, FNextIdx, P);
   Inc(FNextIdx);
   Sg.StartX := NS;
   Sg.EndX := NS + W;
   Sg.Biome := B;
   if FCount >= Length(FSegs) then
      SetLength(FSegs, Length(FSegs) * 2);
   FSegs[FCount] := Sg;
   Inc(FCount);
end;

procedure TBiomeSegmentMap.ExtLeft(const P: TGenParams);
var
   NE, MX, W, I: Integer;
   B: byte;
   Sg: TBiomeSegment;
begin
   NE := FSegs[0].StartX;
   MX := NE - 1;
   B := NoiseBiomeAt(MX, P);
   W := SegWidth(B, -(FNextIdx + 1), P);
   Inc(FNextIdx);
   Sg.StartX := NE - W;
   Sg.EndX := NE;
   Sg.Biome := B;
   if FCount >= Length(FSegs) then
      SetLength(FSegs, Length(FSegs) * 2);
   for I := FCount downto 1 do
      FSegs[I] := FSegs[I - 1];
   FSegs[0] := Sg;
   Inc(FCount);
end;

function TBiomeSegmentMap.GetBiome(TX: Integer; const P: TGenParams): byte;
var
   Lo, Hi, Mid: Integer;
begin
   if FCount = 0 then
      ExtRight(P);
   while TX >= FSegs[FCount - 1].EndX do
      ExtRight(P);
   while TX < FSegs[0].StartX do
      ExtLeft(P);
   Lo := 0;
   Hi := FCount - 1;
   while Lo < Hi do
   begin
      Mid := (Lo + Hi) div 2;
      if FSegs[Mid].EndX <= TX then
         Lo := Mid + 1
      else
         Hi := Mid;
   end;
   Result := FSegs[Lo].Biome;
end;

procedure TChunkGenerator.SetWorld(WX, WY: Integer; T: byte);
var
   CY: Integer;
begin
   CY := TChunkManager.TileToChunkY(WY);
   if (CY < WORLD_MIN_CY) or (CY > WORLD_MAX_CY) then
      Exit;
   FManager.SetFG(WX, WY, T);
end;

function TChunkGenerator.IsAir(AC: TWorldChunk; LX, LY: Integer): boolean;
begin
   Result := AC.InLocalBounds(LX, LY) and (AC.GetFG(LX, LY) = TILE_AIR);
end;

function TChunkGenerator.IsSolid(AC: TWorldChunk; LX, LY: Integer): boolean;
var
   T: byte;
begin
   if not AC.InLocalBounds(LX, LY) then
   begin
      Result := True;
      Exit;
   end;
   T := AC.GetFG(LX, LY);
   Result := (T <> TILE_AIR) and (T < TILE_SHRUB);
end;

function TChunkGenerator.IsDirt(AC: TWorldChunk; LX, LY: Integer): boolean;
var
   T: byte;
begin
   if not AC.InLocalBounds(LX, LY) then
   begin
      Result := False;
      Exit;
   end;
   T := AC.GetFG(LX, LY);
   Result := (T = TILE_DIRT) or (T = TILE_GRASS) or (T = TILE_CLAY) or (T = TILE_GRAVEL);
end;

function TChunkGenerator.IsStone(AC: TWorldChunk; LX, LY: Integer): boolean;
var
   T: byte;
begin
   if not AC.InLocalBounds(LX, LY) then
   begin
      Result := False;
      Exit;
   end;
   T := AC.GetFG(LX, LY);
   Result := (T = TILE_STONE) or (T = TILE_GRANITE) or (T = TILE_MARBLE) or (T = TILE_SANDSTONE) or (T = TILE_BEDROCK);
end;

function TChunkGenerator.SurfLY(AC: TWorldChunk; LX: Integer): Integer;
var
   LY: Integer;
begin
   Result := -1;
   for LY := 0 to CHUNK_TILES_H - 1 do
      if AC.GetFG(LX, LY) <> TILE_AIR then
      begin
         Result := LY;
         Exit;
      end;
end;

procedure TChunkGenerator.SafeSet(AC: TWorldChunk; LX, LY: Integer; T: byte);
begin
   if AC.InLocalBounds(LX, LY) then
      AC.SetFG(LX, LY, T);
end;

constructor TChunkGenerator.Create(AM: TChunkManager; S: longint);
begin
   inherited Create;
   FManager := AM;
   FSeed := S;
   FParams := DefaultGenParams;
   FParams.Seed := S;
   FBiomeMap := TBiomeSegmentMap.Create(S);
   FLiquidPlacer := TLiquidPlacer.Create(AM, @FParams.Liquid, S);
end;

destructor TChunkGenerator.Destroy;
begin
   FLiquidPlacer.Free;
   FBiomeMap.Free;
   inherited;
end;

procedure TChunkGenerator.ApplyParams;
begin
   ClampGenParams(FParams);
   FSeed := FParams.Seed;
   FBiomeMap.Reset(FSeed);
   NoiseSeed(FSeed);
   if Assigned(FLiquidPlacer) then
      FLiquidPlacer.Seed := FSeed;
end;

function TChunkGenerator.GetSegmentBiome(TX: Integer): byte;
begin
   Result := FBiomeMap.GetBiome(TX, FParams);
end;

function TChunkGenerator.ComputeSurfaceY(TX: Integer): Integer;
var
   N: Single;
   Bi: byte;
   BP: TBiomeParams;
begin
   N := FBM1D(TX * FParams.SurfaceFreq, FParams.SurfaceOctaves, FParams.SurfaceLacun, FParams.SurfaceGain);
   Bi := GetSegmentBiome(TX);
   case Bi of
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

function TChunkGenerator.IsCaveAt(TX, TY, ASY: Integer; ACM: Single): boolean;
const
   TWX = 5.2;
   TWY = 1.3;
   CX1 = 3.7;
   CY1 = 8.1;
   CX2 = 11.4;
   CY2 = 2.6;
   MAXT = 0.49;
var
   WF, MCD, DF, WX, WY, TX2, TY2, TN, TT, CWX, CWY, CX, CY2V, CN, CT: Single;
begin
   Result := False;
   if ACM <= 0 then
      Exit;
   MCD := FParams.DepthStone - FParams.CaveStartDepth;
   if MCD < 1 then
      MCD := 1;
   DF := (TY - ASY - FParams.CaveStartDepth) / MCD;
   if DF < 0 then
      DF := 0;
   if DF > 1 then
      DF := 1;
   WF := FParams.CaveWarpFreq;
   WX := FBM2D(TX * WF, TY * WF, 2) * FParams.CaveWarpStrength;
   WY := FBM2D(TX * WF + TWX, TY * WF + TWY, 2) * FParams.CaveWarpStrength;
   TX2 := TX + WX;
   TY2 := TY + WY;
   TN := FBM2D(TX2 * FParams.CaveFreqX, TY2 * FParams.CaveFreqY, FParams.CaveOctaves);
   TT := FParams.CaveThreshold + (FParams.CaveThresholdDeep - FParams.CaveThreshold) * DF;
   TT := TT * ACM;
   if TT > MAXT then
      TT := MAXT;
   Result := Abs(TN) < TT;
   if FParams.ChamberEnabled and not Result then
   begin
      CWX := FBM2D(TX * WF + CX1, TY * WF + CY1, 2) * FParams.ChamberWarpStrength;
      CWY := FBM2D(TX * WF + CX2, TY * WF + CY2, 2) * FParams.ChamberWarpStrength;
      CX := TX + CWX;
      CY2V := TY + CWY;
      CN := FBM2D(CX * FParams.ChamberFreq, CY2V * FParams.ChamberFreq, FParams.ChamberOctaves);
      CT := FParams.ChamberThreshold * ACM;
      if CT > MAXT then
         CT := MAXT;
      Result := Abs(CN) < CT;
   end;
end;

function TChunkGenerator.ForegroundTile(TX, TY, _AS: Integer; AB: byte): byte;
var
   D: Integer;
   N: Single;
   BP: TBiomeParams;
   ED, EDS, ESS: Integer;
   EGT, EMT, ECT, EGvT: Single;
begin
   if TY < _AS then
   begin
      Result := TILE_AIR;
      Exit;
   end;
   D := TY - _AS;
   case AB of
      BIOME_DESERT:
         BP := FParams.BiomeDesert;
      BIOME_FOREST:
         BP := FParams.BiomeForest;
      else
         BP := FParams.BiomePlains;
   end;
   ED := IfThen(BP.DepthDirtOverride > 0, BP.DepthDirtOverride, FParams.DepthDirt);
   EDS := IfThen(BP.DepthDirtStoneOverride > 0, BP.DepthDirtStoneOverride, FParams.DepthDirtStone);
   ESS := IfThen(BP.SandstoneDepth > 0, BP.SandstoneDepth, FParams.SandstoneExtra);
   EGT := IfThen(BP.GraniteThreshold > 0, BP.GraniteThreshold, FParams.GraniteThreshold);
   EMT := IfThen(BP.MarbleThreshold > 0, BP.MarbleThreshold, FParams.MarbleThreshold);
   ECT := IfThen(BP.ClayThreshold > 0, BP.ClayThreshold, FParams.ClayThreshold);
   EGvT := IfThen(BP.GravelThreshold > 0, BP.GravelThreshold, FParams.GravelThreshold);
   if D = 0 then
   begin
      if BP.SurfaceTileOverride > 0 then
      begin
         Result := BP.SurfaceTileOverride;
         Exit;
      end;
      if AB = BIOME_DESERT then
         Result := TILE_SAND
      else
         Result := TILE_DIRT;
      Exit;
   end;
   if D <= ED then
   begin
      if AB = BIOME_DESERT then
         Result := TILE_SAND
      else
         Result := TILE_DIRT;
      Exit;
   end;
   if (AB = BIOME_DESERT) and (D <= ED + ESS) then
   begin
      Result := TILE_SANDSTONE;
      Exit;
   end;
   if D <= EDS then
   begin
      N := ValueNoise2D(TX * 0.18, TY * 0.18);
      if N > (0.4 - D * 0.02) then
         Result := TILE_STONE
      else
         Result := TILE_DIRT;
      if (N > ECT) and (D < EDS - 2) then
         Result := TILE_CLAY;
      N := ValueNoise2D(TX * 0.22 + 50, TY * 0.22 + 50);
      if N > EGvT then
         Result := TILE_GRAVEL;
      Exit;
   end;
   if D <= FParams.DepthStone then
   begin
      Result := TILE_STONE;
      N := FBM2D(TX * FParams.GraniteFreq, TY * FParams.GraniteFreq, 2);
      if N > EGT then
         Result := TILE_GRANITE;
      N := FBM2D(TX * FParams.MarbleFreq + 200, TY * FParams.MarbleFreq + 200, 2);
      if N > EMT then
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

procedure TChunkGenerator.GenerateColumn(AC: TWorldChunk; LX, ACX, ACY: Integer);
var
   TX, TY, WY, SY: Integer;
   Bi: byte;
   TV: byte;
   CM: Single;
   BP: TBiomeParams;
begin
   TX := TChunkManager.ChunkToTileX(ACX) + LX;
   SY := ComputeSurfaceY(TX);
   Bi := GetSegmentBiome(TX);
   FManager.SetSurfaceY(TX, SY);
   FManager.SetBiome(TX, Bi);
   case Bi of
      BIOME_DESERT:
         BP := FParams.BiomeDesert;
      BIOME_FOREST:
         BP := FParams.BiomeForest;
      else
         BP := FParams.BiomePlains;
   end;
   CM := BP.CaveDensityMult;
   for WY := 0 to CHUNK_TILES_H - 1 do
   begin
      TY := TChunkManager.ChunkToTileY(ACY) + WY;
      TV := ForegroundTile(TX, TY, SY, Bi);
      if FParams.CavesEnabled and (TV <> TILE_AIR) and (TV <> TILE_BEDROCK) and (TY >= SY + FParams.CaveStartDepth) then
         if IsCaveAt(TX, TY, SY, CM) then
            TV := TILE_AIR;
      AC.SetFG(LX, WY, TV);
   end;
end;

procedure TChunkGenerator.FillBGColumn(AC: TWorldChunk; LX, ACX, ACY, _AS: Integer; AB: byte);
var
   WY, TY, TX: Integer;
   WT: byte;
begin
   TX := TChunkManager.ChunkToTileX(ACX) + LX;
   for WY := 0 to CHUNK_TILES_H - 1 do
   begin
      TY := TChunkManager.ChunkToTileY(ACY) + WY;
      if TY < _AS then
      begin
         AC.SetBG(LX, WY, TILE_AIR);
         Continue;
      end;
      WT := ForegroundTile(TX, TY, _AS, AB);
      if WT = TILE_AIR then
         WT := TILE_STONE;
      AC.SetBG(LX, WY, WT);
   end;
end;

procedure TChunkGenerator.PlaceGrassColumn(AC: TWorldChunk; LX, ACY, _AS: Integer);
var
   LY, TY, OTY: Integer;
begin
   OTY := TChunkManager.ChunkToTileY(ACY);
   for LY := 0 to CHUNK_TILES_H - 1 do
      if AC.GetFG(LX, LY) <> TILE_AIR then
      begin
         TY := OTY + LY;
         if (TY = _AS) and (AC.GetFG(LX, LY) = TILE_DIRT) then
            AC.SetFG(LX, LY, TILE_GRASS);
         Break;
      end;
end;

procedure TChunkGenerator.PlantVeg(AC: TWorldChunk; LX, ACX, ACY: Integer);
var
   TX, OTY: Integer;
   Bi: byte;
   V: TVegetationParams;
   SL2, TY, Lc: Integer;
   N: Single;
   CP: boolean;
   ST: byte;
begin
   TX := TChunkManager.ChunkToTileX(ACX) + LX;
   OTY := TChunkManager.ChunkToTileY(ACY);
   Bi := FManager.GetBiome(TX);
   case Bi of
      BIOME_DESERT:
         V := FParams.VegDesert;
      BIOME_FOREST:
         V := FParams.VegForest;
      else
         V := FParams.VegPlains;
   end;
   SL2 := SurfLY(AC, LX);
   if SL2 < 0 then
      Exit;
   TY := OTY + SL2;
   if TY <> FManager.GetSurfaceY(TX) then
      Exit;
   if SL2 = 0 then
      Exit;
   if V.TreeEnabled then
   begin
      N := (ValueNoise1D(TX * V.TreeNoiseFreq + FSeed * 0.001) + 1) * 0.5;
      if N < V.TreeNoiseThresh then
      begin
         CP := True;
         for Lc := Max(0, LX - 2) to Min(CHUNK_TILES_W - 1, LX + 2) do
            if (Lc <> LX) and (AC.GetFG(Lc, SL2 - 1) in [TILE_TREE_TRUNK, TILE_CACTUS]) then
            begin
               CP := False;
               Break;
            end;
         if CP then
            PlantTree(AC, LX, SL2, TX, OTY, V);
      end;
   end;
   if V.ShrubEnabled and IsAir(AC, LX, SL2 - 1) then
   begin
      ST := AC.GetFG(LX, SL2);
      if (ST = TILE_GRASS) or (ST = TILE_DIRT) or (ST = TILE_SAND) then
      begin
         N := (ValueNoise1D(TX * V.ShrubNoiseFreq + FSeed * 0.007 + 333) + 1) * 0.5;
         if N < V.ShrubNoiseThresh then
            PlantShrub(AC, LX, SL2);
      end;
   end;
   if V.CactusEnabled and IsAir(AC, LX, SL2 - 1) then
   begin
      N := (ValueNoise1D(TX * V.CactusNoiseFreq + FSeed * 0.003 + 777) + 1) * 0.5;
      if N < V.CactusNoiseThresh then
         PlantCactus(AC, LX, SL2, TX, OTY, V);
   end;
end;

procedure TChunkGenerator.PlantTree(AC: TWorldChunk; LX, SLY, TX, OTY: Integer; const V: TVegetationParams);
var
   TH, R, H, DX, DY, TBW, TTW, WY, CWX, CWY, LX2, LY2: Integer;
begin
   if SLY <= 0 then
      Exit;
   if not IsAir(AC, LX, SLY - 1) then
      Exit;
   TH := V.TreeMinHeight + (Abs(Round(ValueNoise1D(LX * 7.3 + FSeed * 0.01) * 100)) mod Max(1, V.TreeMaxHeight - V.TreeMinHeight + 1));
   TH := Max(V.TreeMinHeight, Min(V.TreeMaxHeight, TH));
   TBW := OTY + SLY - 1;
   TTW := TBW - TH;
   if TTW < TChunkManager.ChunkToTileY(WORLD_MIN_CY) then
      TTW := TChunkManager.ChunkToTileY(WORLD_MIN_CY);
   for WY := TTW to TBW do
   begin
      LX2 := LX;
      LY2 := WY - OTY;
      if AC.InLocalBounds(LX2, LY2) then
         AC.SetFG(LX2, LY2, TILE_TREE_TRUNK)
      else
         SetWorld(TX, WY, TILE_TREE_TRUNK);
   end;
   R := V.TreeCanopyRadius;
   H := V.TreeCanopyHeight;
   for DY := -H to H do
      for DX := -R to R do
      begin
         if (DX * DX * H * H + DY * DY * R * R) > (R * R * H * H) then
            Continue;
         CWX := TX + DX;
         CWY := TTW + DY;
         LX2 := CWX - TX + LX;
         LY2 := CWY - OTY;
         if AC.InLocalBounds(LX2, LY2) then
         begin
            if IsAir(AC, LX2, LY2) then
               AC.SetFG(LX2, LY2, TILE_TREE_LEAF);
         end
         else
            SetWorld(CWX, CWY, TILE_TREE_LEAF);
      end;
end;

procedure TChunkGenerator.PlantShrub(AC: TWorldChunk; LX, SLY: Integer);
begin
   if SLY <= 0 then
      Exit;
   if not IsAir(AC, LX, SLY - 1) then
      Exit;
   SafeSet(AC, LX, SLY - 1, TILE_SHRUB);
end;

procedure TChunkGenerator.PlantCactus(AC: TWorldChunk; LX, SLY, TX, OTY: Integer; const V: TVegetationParams);
var
   CH, LY, MY, TY2: Integer;
   NA: Single;
   GL: boolean;
   WYB: Integer;
begin
   if SLY <= 1 then
      Exit;
   if not IsAir(AC, LX, SLY - 1) then
      Exit;
   CH := V.CactusMinHeight + (Abs(Round(ValueNoise1D(LX * 11.7 + FSeed * 0.02) * 100)) mod Max(1, V.CactusMaxHeight - V.CactusMinHeight + 1));
   CH := Max(V.CactusMinHeight, Min(V.CactusMaxHeight, CH));
   for LY := SLY - 1 downto Max(0, SLY - CH) do
      SafeSet(AC, LX, LY, TILE_CACTUS);
   if V.CactusArmChance > 0 then
   begin
      NA := (ValueNoise1D(LX * 3.3 + FSeed * 0.03) + 1) * 0.5;
      if NA < V.CactusArmChance then
      begin
         MY := SLY - 1 - CH div 2;
         if MY >= 0 then
         begin
            GL := ValueNoise1D(LX * 17.1 + FSeed) > 0;
            WYB := OTY + MY;
            if GL then
            begin
               SetWorld(TX - 1, WYB, TILE_CACTUS);
               SetWorld(TX - 1, WYB - 1, TILE_CACTUS_TOP);
            end
            else
            begin
               SetWorld(TX + 1, WYB, TILE_CACTUS);
               SetWorld(TX + 1, WYB - 1, TILE_CACTUS_TOP);
            end;
         end;
      end;
   end;
   TY2 := Max(0, SLY - CH);
   SafeSet(AC, LX, TY2, TILE_CACTUS_TOP);
end;

procedure TChunkGenerator.PlaceCaveDecor(AC: TWorldChunk; LX, ACX, ACY: Integer);
var
   LY, TX, TY, Len, I: Integer;
   CD: TCaveDecoParams;
   N: Single;
   STY, DBS: Integer;
begin
   CD := FParams.CaveDecor;
   TX := TChunkManager.ChunkToTileX(ACX) + LX;
   STY := FManager.GetSurfaceY(TX);
   for LY := 1 to CHUNK_TILES_H - 2 do
   begin
      TY := TChunkManager.ChunkToTileY(ACY) + LY;
      DBS := TY - STY;
      if DBS < FParams.CaveStartDepth then
         Continue;
      if not IsAir(AC, LX, LY) then
         Continue;
      if IsSolid(AC, LX, LY - 1) then
      begin
         if CD.RootsEnabled and IsDirt(AC, LX, LY - 1) then
         begin
            N := (ValueNoise1D(TX * CD.RootsNoiseFreq + LY * 2.3 + FSeed * 0.02) + 1) * 0.5;
            if N < CD.RootsDensity then
            begin
               Len := CD.RootsMinLen + Abs(Round(N * 100)) mod Max(1, CD.RootsMaxLen - CD.RootsMinLen + 1);
               for I := 0 to Len - 1 do
                  if IsAir(AC, LX, LY + I) then
                     SafeSet(AC, LX, LY + I, TILE_ROOT)
                  else
                     Break;
            end;
         end;
         if CD.VinesEnabled and IsStone(AC, LX, LY - 1) and (DBS > FParams.DepthDirt + 4) then
         begin
            N := (ValueNoise1D(TX * CD.VinesNoiseFreq + LY * 3.1 + FSeed * 0.04 + 500) + 1) * 0.5;
            if N < CD.VinesDensity then
            begin
               Len := CD.VinesMinLen + Abs(Round(N * 100)) mod Max(1, CD.VinesMaxLen - CD.VinesMinLen + 1);
               for I := 0 to Len - 1 do
                  if IsAir(AC, LX, LY + I) then
                     SafeSet(AC, LX, LY + I, TILE_VINE)
                  else
                     Break;
            end;
         end;
         if CD.StalEnabled and IsStone(AC, LX, LY - 1) then
         begin
            N := (ValueNoise1D(TX * CD.StalNoiseFreq + LY * 5.7 + FSeed * 0.05 + 1000) + 1) * 0.5;
            if N < CD.StalDensity then
            begin
               Len := CD.StalMinLen + Abs(Round(N * 100)) mod Max(1, CD.StalMaxLen - CD.StalMinLen + 1);
               for I := 0 to Len - 1 do
                  if IsAir(AC, LX, LY + I) then
                     SafeSet(AC, LX, LY + I, TILE_STALACTITE)
                  else
                     Break;
            end;
         end;
         if CD.MossEnabled and IsStone(AC, LX, LY - 1) then
         begin
            N := (ValueNoise1D(TX * CD.MossNoiseFreq + LY * 1.9 + FSeed * 0.03 + 2000) + 1) * 0.5;
            if N < CD.MossDensity then
               SafeSet(AC, LX, LY, TILE_MOSS);
         end;
      end;
      if IsSolid(AC, LX, LY + 1) then
      begin
         if CD.StalEnabled and IsStone(AC, LX, LY + 1) then
         begin
            N := (ValueNoise1D(TX * CD.StalNoiseFreq + LY * 4.4 + FSeed * 0.06 + 3000) + 1) * 0.5;
            if N < (CD.StalDensity * 0.6) then
            begin
               Len := CD.StalMinLen + Abs(Round(N * 100)) mod Max(1, CD.StalMaxLen - CD.StalMinLen + 1);
               for I := 0 to Len - 1 do
                  if IsAir(AC, LX, LY - I) then
                     SafeSet(AC, LX, LY - I, TILE_STALAGMITE)
                  else
                     Break;
            end;
         end;
         if CD.MushEnabled and (DBS >= CD.MushMinDepth) and IsAir(AC, LX, LY - 1) then
         begin
            N := (ValueNoise1D(TX * 0.9 + LY * 6.2 + FSeed * 0.07 + 4000) + 1) * 0.5;
            if N < CD.MushDensity then
               SafeSet(AC, LX, LY, TILE_MUSHROOM);
         end;
      end;
   end;
end;

procedure TChunkGenerator.GenerateChunk(ACX, ACY: Integer; AC: TWorldChunk);
var
   LX, TX, SY: Integer;
   Bi: byte;
begin
   NoiseSeed(FSeed);
   for LX := 0 to CHUNK_TILES_W - 1 do
      GenerateColumn(AC, LX, ACX, ACY);
   for LX := 0 to CHUNK_TILES_W - 1 do
   begin
      TX := TChunkManager.ChunkToTileX(ACX) + LX;
      SY := FManager.GetSurfaceY(TX);
      Bi := FManager.GetBiome(TX);
      FillBGColumn(AC, LX, ACX, ACY, SY, Bi);
   end;
   for LX := 0 to CHUNK_TILES_W - 1 do
   begin
      TX := TChunkManager.ChunkToTileX(ACX) + LX;
      SY := FManager.GetSurfaceY(TX);
      PlaceGrassColumn(AC, LX, ACY, SY);
   end;
   for LX := 0 to CHUNK_TILES_W - 1 do
      PlantVeg(AC, LX, ACX, ACY);
   if FParams.CavesEnabled then
      for LX := 0 to CHUNK_TILES_W - 1 do
         PlaceCaveDecor(AC, LX, ACX, ACY);
   if Assigned(FLiquidPlacer) then
      FLiquidPlacer.PlaceChunk(AC);
end;

end.
