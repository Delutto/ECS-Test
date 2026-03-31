unit Terraria.GenParams;

{$mode objfpc}{$H+}
{$modeSwitch advancedRecords}

interface

uses
   SysUtils, StrUtils, Classes;

type
   PBiomeParams = ^TBiomeParams;

   TBiomeParams = record
      SurfaceOffsetY, DepthDirtOverride, DepthDirtStoneOverride, SandstoneDepth, SurfaceTileOverride, MinBiomeWidth, MaxBiomeWidth: Integer;
      SurfaceAmpBonus, GraniteThreshold, MarbleThreshold, ClayThreshold, GravelThreshold, CaveDensityMult: Single;
   end;
   PVegetationParams = ^TVegetationParams;

   TVegetationParams = record
      TreeEnabled, ShrubEnabled, CactusEnabled: boolean;
      TreeDensity, TreeNoiseFreq, TreeNoiseThresh, ShrubDensity, ShrubNoiseFreq, ShrubNoiseThresh: Single;
      TreeMinHeight, TreeMaxHeight, TreeCanopyRadius, TreeCanopyHeight, CactusMinHeight, CactusMaxHeight: Integer;
      CactusDensity, CactusArmChance, CactusNoiseFreq, CactusNoiseThresh: Single;
   end;
   PCaveDecoParams = ^TCaveDecoParams;

   TCaveDecoParams = record
      RootsEnabled, VinesEnabled, StalEnabled, MushEnabled, MossEnabled: boolean;
      RootsDensity, RootsNoiseFreq, VinesDensity, VinesNoiseFreq, StalDensity, StalNoiseFreq: Single;
      MushDensity, MossDensity, MossNoiseFreq: Single;
      RootsMinLen, RootsMaxLen, VinesMinLen, VinesMaxLen, StalMinLen, StalMaxLen, MushMinDepth: Integer;
   end;
   PGenParams = ^TGenParams;

   TGenParams = record
      Seed: longint;
      BaseSurface, SurfaceAmp, MinSurface, MaxSurface, SurfaceOctaves: Integer;
      SurfaceFreq, SurfaceLacun, SurfaceGain: Single;
      DepthDirt, DepthDirtStone, DepthStone, SandstoneExtra, BedrockRows: Integer;
      CavesEnabled, ChamberEnabled: boolean;
      CaveStartDepth, CaveOctaves, ChamberOctaves: Integer;
    { CaveThreshold = surface entrance (tight)
      CaveThresholdDeep = stone zone (wide) — interpolated with depth }
      CaveThreshold, CaveThresholdDeep: Single;
      CaveFreqX, CaveFreqY: Single;
    { Domain warp: two FBM fields displace sample coords so tunnels
      curve organically and grid bias disappears. }
      CaveWarpStrength, CaveWarpFreq: Single;
    { Chamber system: lower-freq noise OR'd with tunnel field.
      Independent warp vectors produce genuine open rooms. }
      ChamberFreq, ChamberThreshold, ChamberWarpStrength: Single;
      GraniteThreshold, MarbleThreshold, ClayThreshold, GravelThreshold, GraniteFreq, MarbleFreq: Single;
      BiomeFreq, DesertThreshold, ForestThreshold, DeepGraniteRatio: Single;
      BiomeOctaves: Integer;
      BiomePlains, BiomeDesert, BiomeForest: TBiomeParams;
      VegPlains, VegDesert, VegForest: TVegetationParams;
      CaveDecor: TCaveDecoParams;
      procedure SetSeed(N: longint);
   end;

function DefaultGenParams: TGenParams;
procedure ClampGenParams(var P: TGenParams);
function SaveGenParams(const F: string; const P: TGenParams): boolean;
function LoadGenParams(const F: string; var P: TGenParams): boolean;
function GenParamsPresetName(const F: string): string;

implementation

function DefaultBP(ox, ddov, ddsov, ssd, stov, minw, maxw: Integer; ab, gt, mt, ct, gvt, cdm: Single): TBiomeParams;
begin
   Result.SurfaceOffsetY := ox;
   Result.SurfaceAmpBonus := ab;
   Result.DepthDirtOverride := ddov;
   Result.DepthDirtStoneOverride := ddsov;
   Result.SandstoneDepth := ssd;
   Result.GraniteThreshold := gt;
   Result.MarbleThreshold := mt;
   Result.ClayThreshold := ct;
   Result.GravelThreshold := gvt;
   Result.CaveDensityMult := cdm;
   Result.SurfaceTileOverride := stov;
   Result.MinBiomeWidth := minw;
   Result.MaxBiomeWidth := maxw;
end;

function DefaultVeg(te, se, ce: boolean; td, tnf, tnt, sd, snf, snt, cd, ca, cnf, cnt: Single; tmin, tmax, tr, th, cmin, cmax: Integer): TVegetationParams;
begin
   Result.TreeEnabled := te;
   Result.TreeDensity := td;
   Result.TreeNoiseFreq := tnf;
   Result.TreeNoiseThresh := tnt;
   Result.TreeMinHeight := tmin;
   Result.TreeMaxHeight := tmax;
   Result.TreeCanopyRadius := tr;
   Result.TreeCanopyHeight := th;
   Result.ShrubEnabled := se;
   Result.ShrubDensity := sd;
   Result.ShrubNoiseFreq := snf;
   Result.ShrubNoiseThresh := snt;
   Result.CactusEnabled := ce;
   Result.CactusDensity := cd;
   Result.CactusArmChance := ca;
   Result.CactusNoiseFreq := cnf;
   Result.CactusNoiseThresh := cnt;
   Result.CactusMinHeight := cmin;
   Result.CactusMaxHeight := cmax;
end;

function DefaultGenParams: TGenParams;
begin
   Result.Seed := 0;
   Result.BaseSurface := 48;
   Result.SurfaceAmp := 14;
   Result.MinSurface := 20;
   Result.MaxSurface := 70;
   Result.SurfaceFreq := 0.008;
   Result.SurfaceOctaves := 4;
   Result.SurfaceLacun := 2.0;
   Result.SurfaceGain := 0.55;
   Result.DepthDirt := 6;
   Result.DepthDirtStone := 22;
   Result.DepthStone := 80;
   Result.SandstoneExtra := 8;
   Result.CavesEnabled := True;
   Result.CaveStartDepth := 6;
   Result.CaveThreshold := 0.10;
   Result.CaveThresholdDeep := 0.22;
   Result.CaveFreqX := 0.045;
   Result.CaveFreqY := 0.055;
   Result.CaveOctaves := 4;
   Result.CaveWarpStrength := 16.0;
   Result.CaveWarpFreq := 0.015;
   Result.ChamberEnabled := True;
   Result.ChamberFreq := 0.018;
   Result.ChamberOctaves := 2;
   Result.ChamberThreshold := 0.14;
   Result.ChamberWarpStrength := 24.0;
   Result.GraniteThreshold := 0.55;
   Result.MarbleThreshold := 0.62;
   Result.ClayThreshold := 0.62;
   Result.GravelThreshold := 0.68;
   Result.GraniteFreq := 0.06;
   Result.MarbleFreq := 0.05;
   Result.BiomeFreq := 0.003;
   Result.BiomeOctaves := 2;
   Result.DesertThreshold := 0.30;
   Result.ForestThreshold := 0.68;
   Result.DeepGraniteRatio := 0.30;
   Result.BedrockRows := 3;
   Result.BiomePlains := DefaultBP(0, 0, 0, 0, 0, 120, 600, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0);
   Result.BiomeDesert := DefaultBP(4, 0, 0, 8, 0, 80, 400, -4.0, 0.0, 0.0, 0.0, 0.0, 0.7);
   Result.BiomeForest := DefaultBP(-3, 0, 0, 0, 0, 150, 700, 3.0, 0.0, 0.0, 0.0, 0.0, 1.3);
   Result.VegPlains := DefaultVeg(True, True, False, 0.12, 0.35, 0.30, 0.25, 0.60, 0.40, 0.0, 0.0, 0.40, 0.0, 4, 8, 3, 3, 3, 5);
   Result.VegDesert := DefaultVeg(False, False, True, 0.0, 0.35, 0.20, 0.0, 0.60, 0.30, 0.15, 0.40, 0.40, 0.28, 4, 6, 2, 2, 3, 7);
   Result.VegForest := DefaultVeg(True, True, False, 0.28, 0.25, 0.45, 0.40, 0.70, 0.50, 0.0, 0.0, 0.40, 0.0, 6, 14, 4, 4, 3, 5);
   with Result.CaveDecor do
   begin
      RootsEnabled := True;
      RootsDensity := 0.30;
      RootsMinLen := 1;
      RootsMaxLen := 6;
      RootsNoiseFreq := 0.55;
      VinesEnabled := True;
      VinesDensity := 0.20;
      VinesMinLen := 2;
      VinesMaxLen := 12;
      VinesNoiseFreq := 0.40;
      StalEnabled := True;
      StalDensity := 0.18;
      StalMinLen := 1;
      StalMaxLen := 5;
      StalNoiseFreq := 0.65;
      MushEnabled := True;
      MushDensity := 0.10;
      MushMinDepth := 20;
      MossEnabled := True;
      MossDensity := 0.25;
      MossNoiseFreq := 0.80;
   end;
end;

procedure ClampGenParams(var P: TGenParams);

   function Cl(V, Lo, Hi: Integer): Integer;
   begin
      Result := V;
      if Result < Lo then
         Result := Lo;
      if Result > Hi then
         Result := Hi;
   end;

   function ClF(V, Lo, Hi: Single): Single;
   begin
      Result := V;
      if Result < Lo then
         Result := Lo;
      if Result > Hi then
         Result := Hi;
   end;

   procedure CB(var B: TBiomeParams);
   begin
      B.SurfaceOffsetY := Cl(B.SurfaceOffsetY, -20, 20);
      B.SurfaceAmpBonus := ClF(B.SurfaceAmpBonus, -20, 20);
      B.DepthDirtOverride := Cl(B.DepthDirtOverride, 0, 20);
      B.DepthDirtStoneOverride := Cl(B.DepthDirtStoneOverride, 0, 60);
      B.SandstoneDepth := Cl(B.SandstoneDepth, 0, 30);
      B.GraniteThreshold := ClF(B.GraniteThreshold, 0, 1);
      B.MarbleThreshold := ClF(B.MarbleThreshold, 0, 1);
      B.ClayThreshold := ClF(B.ClayThreshold, 0, 1);
      B.GravelThreshold := ClF(B.GravelThreshold, 0, 1);
      B.CaveDensityMult := ClF(B.CaveDensityMult, 0, 3);
      B.MinBiomeWidth := Cl(B.MinBiomeWidth, 16, 2000);
      B.MaxBiomeWidth := Cl(B.MaxBiomeWidth, 32, 4096);
      if B.MaxBiomeWidth < B.MinBiomeWidth then
         B.MaxBiomeWidth := B.MinBiomeWidth;
   end;

   procedure CV(var V: TVegetationParams);
   begin
      V.TreeDensity := ClF(V.TreeDensity, 0, 1);
      V.TreeMinHeight := Cl(V.TreeMinHeight, 1, 12);
      V.TreeMaxHeight := Cl(V.TreeMaxHeight, 1, 20);
      if V.TreeMaxHeight < V.TreeMinHeight then
         V.TreeMaxHeight := V.TreeMinHeight;
      V.TreeCanopyRadius := Cl(V.TreeCanopyRadius, 1, 8);
      V.TreeCanopyHeight := Cl(V.TreeCanopyHeight, 1, 6);
      V.TreeNoiseFreq := ClF(V.TreeNoiseFreq, 0.05, 2);
      V.TreeNoiseThresh := ClF(V.TreeNoiseThresh, 0, 1);
      V.ShrubDensity := ClF(V.ShrubDensity, 0, 1);
      V.ShrubNoiseFreq := ClF(V.ShrubNoiseFreq, 0.1, 3);
      V.ShrubNoiseThresh := ClF(V.ShrubNoiseThresh, 0, 1);
      V.CactusDensity := ClF(V.CactusDensity, 0, 1);
      V.CactusMinHeight := Cl(V.CactusMinHeight, 1, 8);
      V.CactusMaxHeight := Cl(V.CactusMaxHeight, 1, 12);
      if V.CactusMaxHeight < V.CactusMinHeight then
         V.CactusMaxHeight := V.CactusMinHeight;
      V.CactusArmChance := ClF(V.CactusArmChance, 0, 1);
      V.CactusNoiseFreq := ClF(V.CactusNoiseFreq, 0.05, 2);
      V.CactusNoiseThresh := ClF(V.CactusNoiseThresh, 0, 1);
   end;

   procedure CD(var C: TCaveDecoParams);
   begin
      C.RootsDensity := ClF(C.RootsDensity, 0, 1);
      C.RootsMinLen := Cl(C.RootsMinLen, 1, 8);
      C.RootsMaxLen := Cl(C.RootsMaxLen, 1, 14);
      if C.RootsMaxLen < C.RootsMinLen then
         C.RootsMaxLen := C.RootsMinLen;
      C.RootsNoiseFreq := ClF(C.RootsNoiseFreq, 0.05, 2);
      C.VinesDensity := ClF(C.VinesDensity, 0, 1);
      C.VinesMinLen := Cl(C.VinesMinLen, 1, 10);
      C.VinesMaxLen := Cl(C.VinesMaxLen, 1, 20);
      if C.VinesMaxLen < C.VinesMinLen then
         C.VinesMaxLen := C.VinesMinLen;
      C.VinesNoiseFreq := ClF(C.VinesNoiseFreq, 0.05, 2);
      C.StalDensity := ClF(C.StalDensity, 0, 1);
      C.StalMinLen := Cl(C.StalMinLen, 1, 6);
      C.StalMaxLen := Cl(C.StalMaxLen, 1, 12);
      if C.StalMaxLen < C.StalMinLen then
         C.StalMaxLen := C.StalMinLen;
      C.StalNoiseFreq := ClF(C.StalNoiseFreq, 0.05, 2);
      C.MushDensity := ClF(C.MushDensity, 0, 1);
      C.MushMinDepth := Cl(C.MushMinDepth, 10, 80);
      C.MossDensity := ClF(C.MossDensity, 0, 1);
      C.MossNoiseFreq := ClF(C.MossNoiseFreq, 0.05, 2);
   end;

begin
   P.BaseSurface := Cl(P.BaseSurface, 5, 100);
   P.SurfaceAmp := Cl(P.SurfaceAmp, 0, 50);
   P.MinSurface := Cl(P.MinSurface, 1, 70);
   P.MaxSurface := Cl(P.MaxSurface, 30, 200);
   P.SurfaceFreq := ClF(P.SurfaceFreq, 0.001, 0.05);
   P.SurfaceOctaves := Cl(P.SurfaceOctaves, 1, 8);
   P.SurfaceLacun := ClF(P.SurfaceLacun, 1, 4);
   P.SurfaceGain := ClF(P.SurfaceGain, 0.1, 0.9);
   P.DepthDirt := Cl(P.DepthDirt, 2, 20);
   P.DepthDirtStone := Cl(P.DepthDirtStone, 10, 60);
   P.DepthStone := Cl(P.DepthStone, 30, 150);
   P.SandstoneExtra := Cl(P.SandstoneExtra, 0, 20);
   P.CaveStartDepth := Cl(P.CaveStartDepth, 0, 20);
   P.CaveThreshold := ClF(P.CaveThreshold, 0.01, 0.40);
   P.CaveThresholdDeep := ClF(P.CaveThresholdDeep, 0.01, 0.45);
   if P.CaveThresholdDeep < P.CaveThreshold then
      P.CaveThresholdDeep := P.CaveThreshold;
   P.CaveFreqX := ClF(P.CaveFreqX, 0.01, 0.2);
   P.CaveFreqY := ClF(P.CaveFreqY, 0.01, 0.2);
   P.CaveOctaves := Cl(P.CaveOctaves, 1, 6);
   P.CaveWarpStrength := ClF(P.CaveWarpStrength, 0, 60);
   P.CaveWarpFreq := ClF(P.CaveWarpFreq, 0.005, 0.05);
   P.ChamberFreq := ClF(P.ChamberFreq, 0.005, 0.04);
   P.ChamberOctaves := Cl(P.ChamberOctaves, 1, 4);
   P.ChamberThreshold := ClF(P.ChamberThreshold, 0.05, 0.40);
   P.ChamberWarpStrength := ClF(P.ChamberWarpStrength, 0, 80);
   P.GraniteThreshold := ClF(P.GraniteThreshold, 0.3, 0.95);
   P.MarbleThreshold := ClF(P.MarbleThreshold, 0.3, 0.95);
   P.ClayThreshold := ClF(P.ClayThreshold, 0.3, 0.95);
   P.GravelThreshold := ClF(P.GravelThreshold, 0.3, 0.95);
   P.GraniteFreq := ClF(P.GraniteFreq, 0.01, 0.2);
   P.MarbleFreq := ClF(P.MarbleFreq, 0.01, 0.2);
   P.BiomeFreq := ClF(P.BiomeFreq, 0.0005, 0.02);
   P.BiomeOctaves := Cl(P.BiomeOctaves, 1, 4);
   P.DesertThreshold := ClF(P.DesertThreshold, 0.05, 0.6);
   P.ForestThreshold := ClF(P.ForestThreshold, 0.4, 0.95);
   P.DeepGraniteRatio := ClF(P.DeepGraniteRatio, 0, 1);
   P.BedrockRows := Cl(P.BedrockRows, 1, 8);
   CB(P.BiomePlains);
   CB(P.BiomeDesert);
   CB(P.BiomeForest);
   CV(P.VegPlains);
   CV(P.VegDesert);
   CV(P.VegForest);
   CD(P.CaveDecor);
end;

const
   MAGIC = 'TerrariaGenParams';
   VER = '5';

procedure WI(SL: TStringList; const K: string; V: Integer);
begin
   SL.Add(K + '=' + IntToStr(V));
end;

procedure WF(SL: TStringList; const K: string; V: Single);
begin
   SL.Add(K + '=' + FloatToStr(V));
end;

procedure WB(SL: TStringList; const K: string; V: boolean);
begin
   SL.Add(K + '=' + IfThen(V, '1', '0'));
end;

procedure WBiome(SL: TStringList; const Pfx: string; const B: TBiomeParams);
begin
   WI(SL, Pfx + 'OffY', B.SurfaceOffsetY);
   WF(SL, Pfx + 'AB', B.SurfaceAmpBonus);
   WI(SL, Pfx + 'DDO', B.DepthDirtOverride);
   WI(SL, Pfx + 'DDSO', B.DepthDirtStoneOverride);
   WI(SL, Pfx + 'SsD', B.SandstoneDepth);
   WF(SL, Pfx + 'GT', B.GraniteThreshold);
   WF(SL, Pfx + 'MT', B.MarbleThreshold);
   WF(SL, Pfx + 'CT', B.ClayThreshold);
   WF(SL, Pfx + 'GvT', B.GravelThreshold);
   WF(SL, Pfx + 'CDM', B.CaveDensityMult);
   WI(SL, Pfx + 'STO', B.SurfaceTileOverride);
   WI(SL, Pfx + 'MinW', B.MinBiomeWidth);
   WI(SL, Pfx + 'MaxW', B.MaxBiomeWidth);
end;

procedure WVeg(SL: TStringList; const Pfx: string; const V: TVegetationParams);
begin
   WB(SL, Pfx + 'TrOn', V.TreeEnabled);
   WF(SL, Pfx + 'TrD', V.TreeDensity);
   WI(SL, Pfx + 'TrMiH', V.TreeMinHeight);
   WI(SL, Pfx + 'TrMaH', V.TreeMaxHeight);
   WI(SL, Pfx + 'TrCR', V.TreeCanopyRadius);
   WI(SL, Pfx + 'TrCH', V.TreeCanopyHeight);
   WF(SL, Pfx + 'TrNF', V.TreeNoiseFreq);
   WF(SL, Pfx + 'TrNT', V.TreeNoiseThresh);
   WB(SL, Pfx + 'ShOn', V.ShrubEnabled);
   WF(SL, Pfx + 'ShD', V.ShrubDensity);
   WF(SL, Pfx + 'ShNF', V.ShrubNoiseFreq);
   WF(SL, Pfx + 'ShNT', V.ShrubNoiseThresh);
   WB(SL, Pfx + 'CaOn', V.CactusEnabled);
   WF(SL, Pfx + 'CaD', V.CactusDensity);
   WI(SL, Pfx + 'CaMiH', V.CactusMinHeight);
   WI(SL, Pfx + 'CaMaH', V.CactusMaxHeight);
   WF(SL, Pfx + 'CaA', V.CactusArmChance);
   WF(SL, Pfx + 'CaNF', V.CactusNoiseFreq);
   WF(SL, Pfx + 'CaNT', V.CactusNoiseThresh);
end;

procedure WCD(SL: TStringList; const V: TCaveDecoParams);
begin
   WB(SL, 'ROn', V.RootsEnabled);
   WF(SL, 'RD', V.RootsDensity);
   WI(SL, 'RMiL', V.RootsMinLen);
   WI(SL, 'RMaL', V.RootsMaxLen);
   WF(SL, 'RNF', V.RootsNoiseFreq);
   WB(SL, 'VOn', V.VinesEnabled);
   WF(SL, 'VD', V.VinesDensity);
   WI(SL, 'VMiL', V.VinesMinLen);
   WI(SL, 'VMaL', V.VinesMaxLen);
   WF(SL, 'VNF', V.VinesNoiseFreq);
   WB(SL, 'SOn', V.StalEnabled);
   WF(SL, 'SD', V.StalDensity);
   WI(SL, 'SMiL', V.StalMinLen);
   WI(SL, 'SMaL', V.StalMaxLen);
   WF(SL, 'SNF', V.StalNoiseFreq);
   WB(SL, 'MOn', V.MushEnabled);
   WF(SL, 'MD', V.MushDensity);
   WI(SL, 'MMD', V.MushMinDepth);
   WB(SL, 'MsOn', V.MossEnabled);
   WF(SL, 'MsD', V.MossDensity);
   WF(SL, 'MsNF', V.MossNoiseFreq);
end;

function SaveGenParams(const F: string; const P: TGenParams): boolean;
var
   SL: TStringList;
begin
   Result := False;
   SL := TStringList.Create;
   try
      SL.Add('MAGIC=' + MAGIC);
      SL.Add('VER=' + VER);
      WI(SL, 'Seed', P.Seed);
      WI(SL, 'BS', P.BaseSurface);
      WI(SL, 'SA', P.SurfaceAmp);
      WI(SL, 'MinS', P.MinSurface);
      WI(SL, 'MaxS', P.MaxSurface);
      WF(SL, 'SF', P.SurfaceFreq);
      WI(SL, 'SO', P.SurfaceOctaves);
      WF(SL, 'SL', P.SurfaceLacun);
      WF(SL, 'SG', P.SurfaceGain);
      WI(SL, 'DD', P.DepthDirt);
      WI(SL, 'DDS', P.DepthDirtStone);
      WI(SL, 'DS', P.DepthStone);
      WI(SL, 'SE', P.SandstoneExtra);
      WB(SL, 'COn', P.CavesEnabled);
      WI(SL, 'CSD', P.CaveStartDepth);
      WF(SL, 'CT', P.CaveThreshold);
      WF(SL, 'CTD', P.CaveThresholdDeep);
      WF(SL, 'CFX', P.CaveFreqX);
      WF(SL, 'CFY', P.CaveFreqY);
      WI(SL, 'CO', P.CaveOctaves);
      WF(SL, 'CWS', P.CaveWarpStrength);
      WF(SL, 'CWF', P.CaveWarpFreq);
      WB(SL, 'ChOn', P.ChamberEnabled);
      WF(SL, 'ChF', P.ChamberFreq);
      WI(SL, 'ChO', P.ChamberOctaves);
      WF(SL, 'ChT', P.ChamberThreshold);
      WF(SL, 'ChWS', P.ChamberWarpStrength);
      WF(SL, 'GT', P.GraniteThreshold);
      WF(SL, 'MT', P.MarbleThreshold);
      WF(SL, 'CLT', P.ClayThreshold);
      WF(SL, 'GVT', P.GravelThreshold);
      WF(SL, 'GF', P.GraniteFreq);
      WF(SL, 'MF', P.MarbleFreq);
      WF(SL, 'BF', P.BiomeFreq);
      WI(SL, 'BO', P.BiomeOctaves);
      WF(SL, 'DT', P.DesertThreshold);
      WF(SL, 'FT', P.ForestThreshold);
      WF(SL, 'DGR', P.DeepGraniteRatio);
      WI(SL, 'BR', P.BedrockRows);
      WBiome(SL, 'P.', P.BiomePlains);
      WBiome(SL, 'D.', P.BiomeDesert);
      WBiome(SL, 'F.', P.BiomeForest);
      WVeg(SL, 'VP.', P.VegPlains);
      WVeg(SL, 'VD.', P.VegDesert);
      WVeg(SL, 'VF.', P.VegForest);
      WCD(SL, P.CaveDecor);
      SL.SaveToFile(F);
      Result := True;
   except
   end;
   SL.Free;
end;

function RV(SL: TStringList; const K, D: string): string;
var
   I: Integer;
begin
   Result := D;
   for I := 0 to SL.Count - 1 do
      if SL.Names[I] = K then
      begin
         Result := SL.ValueFromIndex[I];
         Exit;
      end;
end;

function RI2(SL: TStringList; const K: string; D: Integer): Integer;
begin
   Result := StrToIntDef(RV(SL, K, IntToStr(D)), D);
end;

function RF2(SL: TStringList; const K: string; D: Single): Single;
var
   E: Integer;
begin
   Val(RV(SL, K, FloatToStr(D)), Result, E);
   if E <> 0 then
      Result := D;
end;

function RB2(SL: TStringList; const K: string; D: boolean): boolean;
begin
   Result := RV(SL, K, IfThen(D, '1', '0')) = '1';
end;

procedure RBiome(SL: TStringList; const Pfx: string; var B: TBiomeParams);
begin
   B.SurfaceOffsetY := RI2(SL, Pfx + 'OffY', B.SurfaceOffsetY);
   B.SurfaceAmpBonus := RF2(SL, Pfx + 'AB', B.SurfaceAmpBonus);
   B.DepthDirtOverride := RI2(SL, Pfx + 'DDO', B.DepthDirtOverride);
   B.DepthDirtStoneOverride := RI2(SL, Pfx + 'DDSO', B.DepthDirtStoneOverride);
   B.SandstoneDepth := RI2(SL, Pfx + 'SsD', B.SandstoneDepth);
   B.GraniteThreshold := RF2(SL, Pfx + 'GT', B.GraniteThreshold);
   B.MarbleThreshold := RF2(SL, Pfx + 'MT', B.MarbleThreshold);
   B.ClayThreshold := RF2(SL, Pfx + 'CT', B.ClayThreshold);
   B.GravelThreshold := RF2(SL, Pfx + 'GvT', B.GravelThreshold);
   B.CaveDensityMult := RF2(SL, Pfx + 'CDM', B.CaveDensityMult);
   B.SurfaceTileOverride := RI2(SL, Pfx + 'STO', B.SurfaceTileOverride);
   B.MinBiomeWidth := RI2(SL, Pfx + 'MinW', B.MinBiomeWidth);
   B.MaxBiomeWidth := RI2(SL, Pfx + 'MaxW', B.MaxBiomeWidth);
end;

procedure RVeg(SL: TStringList; const Pfx: string; var V: TVegetationParams);
begin
   V.TreeEnabled := RB2(SL, Pfx + 'TrOn', V.TreeEnabled);
   V.TreeDensity := RF2(SL, Pfx + 'TrD', V.TreeDensity);
   V.TreeMinHeight := RI2(SL, Pfx + 'TrMiH', V.TreeMinHeight);
   V.TreeMaxHeight := RI2(SL, Pfx + 'TrMaH', V.TreeMaxHeight);
   V.TreeCanopyRadius := RI2(SL, Pfx + 'TrCR', V.TreeCanopyRadius);
   V.TreeCanopyHeight := RI2(SL, Pfx + 'TrCH', V.TreeCanopyHeight);
   V.TreeNoiseFreq := RF2(SL, Pfx + 'TrNF', V.TreeNoiseFreq);
   V.TreeNoiseThresh := RF2(SL, Pfx + 'TrNT', V.TreeNoiseThresh);
   V.ShrubEnabled := RB2(SL, Pfx + 'ShOn', V.ShrubEnabled);
   V.ShrubDensity := RF2(SL, Pfx + 'ShD', V.ShrubDensity);
   V.ShrubNoiseFreq := RF2(SL, Pfx + 'ShNF', V.ShrubNoiseFreq);
   V.ShrubNoiseThresh := RF2(SL, Pfx + 'ShNT', V.ShrubNoiseThresh);
   V.CactusEnabled := RB2(SL, Pfx + 'CaOn', V.CactusEnabled);
   V.CactusDensity := RF2(SL, Pfx + 'CaD', V.CactusDensity);
   V.CactusMinHeight := RI2(SL, Pfx + 'CaMiH', V.CactusMinHeight);
   V.CactusMaxHeight := RI2(SL, Pfx + 'CaMaH', V.CactusMaxHeight);
   V.CactusArmChance := RF2(SL, Pfx + 'CaA', V.CactusArmChance);
   V.CactusNoiseFreq := RF2(SL, Pfx + 'CaNF', V.CactusNoiseFreq);
   V.CactusNoiseThresh := RF2(SL, Pfx + 'CaNT', V.CactusNoiseThresh);
end;

procedure RCD2(SL: TStringList; var V: TCaveDecoParams);
begin
   V.RootsEnabled := RB2(SL, 'ROn', V.RootsEnabled);
   V.RootsDensity := RF2(SL, 'RD', V.RootsDensity);
   V.RootsMinLen := RI2(SL, 'RMiL', V.RootsMinLen);
   V.RootsMaxLen := RI2(SL, 'RMaL', V.RootsMaxLen);
   V.RootsNoiseFreq := RF2(SL, 'RNF', V.RootsNoiseFreq);
   V.VinesEnabled := RB2(SL, 'VOn', V.VinesEnabled);
   V.VinesDensity := RF2(SL, 'VD', V.VinesDensity);
   V.VinesMinLen := RI2(SL, 'VMiL', V.VinesMinLen);
   V.VinesMaxLen := RI2(SL, 'VMaL', V.VinesMaxLen);
   V.VinesNoiseFreq := RF2(SL, 'VNF', V.VinesNoiseFreq);
   V.StalEnabled := RB2(SL, 'SOn', V.StalEnabled);
   V.StalDensity := RF2(SL, 'SD', V.StalDensity);
   V.StalMinLen := RI2(SL, 'SMiL', V.StalMinLen);
   V.StalMaxLen := RI2(SL, 'SMaL', V.StalMaxLen);
   V.StalNoiseFreq := RF2(SL, 'SNF', V.StalNoiseFreq);
   V.MushEnabled := RB2(SL, 'MOn', V.MushEnabled);
   V.MushDensity := RF2(SL, 'MD', V.MushDensity);
   V.MushMinDepth := RI2(SL, 'MMD', V.MushMinDepth);
   V.MossEnabled := RB2(SL, 'MsOn', V.MossEnabled);
   V.MossDensity := RF2(SL, 'MsD', V.MossDensity);
   V.MossNoiseFreq := RF2(SL, 'MsNF', V.MossNoiseFreq);
end;

function LoadGenParams(const F: string; var P: TGenParams): boolean;
var
   SL: TStringList;
begin
   Result := False;
   if not FileExists(F) then
      Exit;
   SL := TStringList.Create;
   try
      SL.LoadFromFile(F);
      if RV(SL, 'MAGIC', '') <> MAGIC then
         Exit;
      P.Seed := RI2(SL, 'Seed', P.Seed);
      P.BaseSurface := RI2(SL, 'BS', P.BaseSurface);
      P.SurfaceAmp := RI2(SL, 'SA', P.SurfaceAmp);
      P.MinSurface := RI2(SL, 'MinS', P.MinSurface);
      P.MaxSurface := RI2(SL, 'MaxS', P.MaxSurface);
      P.SurfaceFreq := RF2(SL, 'SF', P.SurfaceFreq);
      P.SurfaceOctaves := RI2(SL, 'SO', P.SurfaceOctaves);
      P.SurfaceLacun := RF2(SL, 'SL', P.SurfaceLacun);
      P.SurfaceGain := RF2(SL, 'SG', P.SurfaceGain);
      P.DepthDirt := RI2(SL, 'DD', P.DepthDirt);
      P.DepthDirtStone := RI2(SL, 'DDS', P.DepthDirtStone);
      P.DepthStone := RI2(SL, 'DS', P.DepthStone);
      P.SandstoneExtra := RI2(SL, 'SE', P.SandstoneExtra);
      P.CavesEnabled := RB2(SL, 'COn', P.CavesEnabled);
      P.CaveStartDepth := RI2(SL, 'CSD', P.CaveStartDepth);
      P.CaveThreshold := RF2(SL, 'CT', P.CaveThreshold);
      P.CaveThresholdDeep := RF2(SL, 'CTD', P.CaveThresholdDeep);
      P.CaveFreqX := RF2(SL, 'CFX', P.CaveFreqX);
      P.CaveFreqY := RF2(SL, 'CFY', P.CaveFreqY);
      P.CaveOctaves := RI2(SL, 'CO', P.CaveOctaves);
      P.CaveWarpStrength := RF2(SL, 'CWS', P.CaveWarpStrength);
      P.CaveWarpFreq := RF2(SL, 'CWF', P.CaveWarpFreq);
      P.ChamberEnabled := RB2(SL, 'ChOn', P.ChamberEnabled);
      P.ChamberFreq := RF2(SL, 'ChF', P.ChamberFreq);
      P.ChamberOctaves := RI2(SL, 'ChO', P.ChamberOctaves);
      P.ChamberThreshold := RF2(SL, 'ChT', P.ChamberThreshold);
      P.ChamberWarpStrength := RF2(SL, 'ChWS', P.ChamberWarpStrength);
      P.GraniteThreshold := RF2(SL, 'GT', P.GraniteThreshold);
      P.MarbleThreshold := RF2(SL, 'MT', P.MarbleThreshold);
      P.ClayThreshold := RF2(SL, 'CLT', P.ClayThreshold);
      P.GravelThreshold := RF2(SL, 'GVT', P.GravelThreshold);
      P.GraniteFreq := RF2(SL, 'GF', P.GraniteFreq);
      P.MarbleFreq := RF2(SL, 'MF', P.MarbleFreq);
      P.BiomeFreq := RF2(SL, 'BF', P.BiomeFreq);
      P.BiomeOctaves := RI2(SL, 'BO', P.BiomeOctaves);
      P.DesertThreshold := RF2(SL, 'DT', P.DesertThreshold);
      P.ForestThreshold := RF2(SL, 'FT', P.ForestThreshold);
      P.DeepGraniteRatio := RF2(SL, 'DGR', P.DeepGraniteRatio);
      P.BedrockRows := RI2(SL, 'BR', P.BedrockRows);
      RBiome(SL, 'P.', P.BiomePlains);
      RBiome(SL, 'D.', P.BiomeDesert);
      RBiome(SL, 'F.', P.BiomeForest);
      RVeg(SL, 'VP.', P.VegPlains);
      RVeg(SL, 'VD.', P.VegDesert);
      RVeg(SL, 'VF.', P.VegForest);
      RCD2(SL, P.CaveDecor);
      ClampGenParams(P);
      Result := True;
   except
   end;
   SL.Free;
end;

function GenParamsPresetName(const F: string): string;
begin
   Result := ChangeFileExt(ExtractFileName(F), '');
end;

procedure TGenParams.SetSeed(N: longint);
begin
   Seed := N;
end;

end.
