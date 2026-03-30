unit Terraria.GenParams;

{$mode objfpc}{$H+}
{$modeSwitch advancedRecords}

interface

uses
   SysUtils, StrUtils, Classes;

type
   { ── Per-biome surface params ─────────────────────────────────────────── }
   PBiomeParams = ^TBiomeParams;

   TBiomeParams = record
      SurfaceOffsetY: Integer;      { [-20..20]   }
      SurfaceAmpBonus: Single;      { [-20..20]   }
      DepthDirtOverride: Integer;   { [0..20]     }
      DepthDirtStoneOverride: Integer;   { [0..60]     }
      SandstoneDepth: Integer;      { [0..30]     }
      GraniteThreshold: Single;     { [0..1]      }
      MarbleThreshold: Single;
      ClayThreshold: Single;
      GravelThreshold: Single;
      CaveDensityMult: Single;    { [0..3]      }
      SurfaceTileOverride: Integer;

      { ── Biome width constraints ──────────────────────────────────────── }
      { Minimum and maximum width (in world tiles) of a continuous zone of
        this biome type.  The segment generator always picks a width in
        [MinBiomeWidth .. MaxBiomeWidth] using a seeded LCG, guaranteeing
        that each biome zone is at least MinBiomeWidth tiles wide and never
        exceeds MaxBiomeWidth tiles.
        Sensible range: 32..4096 tiles (2..256 chunks of 16 tiles each). }
      MinBiomeWidth: Integer;   { [16..2000]  }
      MaxBiomeWidth: Integer;   { [32..4096]  }
   end;

   { ── Surface vegetation params (per biome) ─────────────────────────────── }
   PVegetationParams = ^TVegetationParams;

   TVegetationParams = record
      { Trees (Plains / Forest) }
      TreeEnabled: boolean;
      TreeDensity: Single;
      TreeMinHeight: Integer;
      TreeMaxHeight: Integer;
      TreeCanopyRadius: Integer;
      TreeCanopyHeight: Integer;
      TreeNoiseFreq: Single;
      TreeNoiseThresh: Single;

      { Shrubs / ferns (Plains / Forest) }
      ShrubEnabled: boolean;
      ShrubDensity: Single;
      ShrubNoiseFreq: Single;
      ShrubNoiseThresh: Single;

      { Cacti (Desert) }
      CactusEnabled: boolean;
      CactusDensity: Single;
      CactusMinHeight: Integer;
      CactusMaxHeight: Integer;
      CactusArmChance: Single;
      CactusNoiseFreq: Single;
      CactusNoiseThresh: Single;
   end;

   { ── Cave decoration params ────────────────────────────────────────────── }
   PCaveDecoParams = ^TCaveDecoParams;

   TCaveDecoParams = record
      RootsEnabled: boolean;
      RootsDensity: Single;
      RootsMinLen: Integer;
      RootsMaxLen: Integer;
      RootsNoiseFreq: Single;

      VinesEnabled: boolean;
      VinesDensity: Single;
      VinesMinLen: Integer;
      VinesMaxLen: Integer;
      VinesNoiseFreq: Single;

      StalEnabled: boolean;
      StalDensity: Single;
      StalMinLen: Integer;
      StalMaxLen: Integer;
      StalNoiseFreq: Single;

      MushEnabled: boolean;
      MushDensity: Single;
      MushMinDepth: Integer;

      MossEnabled: boolean;
      MossDensity: Single;
      MossNoiseFreq: Single;
   end;

   PGenParams = ^TGenParams;

   TGenParams = record
      { ── Global ──────────────────────────────────────────────────────────── }
      Seed: longint;

      { ── Surface shape ───────────────────────────────────────────────────── }
      BaseSurface: Integer;
      SurfaceAmp: Integer;
      MinSurface: Integer;
      MaxSurface: Integer;
      SurfaceFreq: Single;
      SurfaceOctaves: Integer;
      SurfaceLacun: Single;
      SurfaceGain: Single;

      { ── Depth zones ──────────────────────────────────────────────────────── }
      DepthDirt: Integer;
      DepthDirtStone: Integer;
      DepthStone: Integer;
      SandstoneExtra: Integer;

      { ── Caves ────────────────────────────────────────────────────────────── }
      CavesEnabled: boolean;
      CaveStartDepth: Integer;
      CaveThreshold: Single;
      CaveFreqX: Single;
      CaveFreqY: Single;
      CaveOctaves: Integer;

      { ── Global ore thresholds ────────────────────────────────────────────── }
      GraniteThreshold: Single;
      MarbleThreshold: Single;
      ClayThreshold: Single;
      GravelThreshold: Single;
      GraniteFreq: Single;
      MarbleFreq: Single;

      { ── Biome distribution ───────────────────────────────────────────────── }
      BiomeFreq: Single;
      BiomeOctaves: Integer;
      DesertThreshold: Single;
      ForestThreshold: Single;

      { ── Per-biome blocks ─────────────────────────────────────────────────── }
      BiomePlains: TBiomeParams;
      BiomeDesert: TBiomeParams;
      BiomeForest: TBiomeParams;

      { ── Deep zone ────────────────────────────────────────────────────────── }
      DeepGraniteRatio: Single;
      BedrockRows: Integer;

      { ── Surface vegetation (per biome) ──────────────────────────────────── }
      VegPlains: TVegetationParams;
      VegDesert: TVegetationParams;
      VegForest: TVegetationParams;

      { ── Cave decorations ─────────────────────────────────────────────────── }
      CaveDecor: TCaveDecoParams;

      procedure SetSeed(NewSeed: longint);
   end;

function DefaultGenParams: TGenParams;
procedure ClampGenParams(var P: TGenParams);
function SaveGenParams(const AFilePath: string; const P: TGenParams): boolean;
function LoadGenParams(const AFilePath: string; var P: TGenParams): boolean;
function GenParamsPresetName(const AFilePath: string): string;

implementation

{ ── Vegetation defaults ────────────────────────────────────────────────── }

function DefaultVegPlains: TVegetationParams;
begin
   Result.TreeEnabled := True;
   Result.TreeDensity := 0.12;
   Result.TreeMinHeight := 4;
   Result.TreeMaxHeight := 8;
   Result.TreeCanopyRadius := 3;
   Result.TreeCanopyHeight := 3;
   Result.TreeNoiseFreq := 0.35;
   Result.TreeNoiseThresh := 0.30;
   Result.ShrubEnabled := True;
   Result.ShrubDensity := 0.25;
   Result.ShrubNoiseFreq := 0.60;
   Result.ShrubNoiseThresh := 0.40;
   Result.CactusEnabled := False;
   Result.CactusDensity := 0;
   Result.CactusMinHeight := 3;
   Result.CactusMaxHeight := 5;
   Result.CactusArmChance := 0;
   Result.CactusNoiseFreq := 0.40;
   Result.CactusNoiseThresh := 0;
end;

function DefaultVegDesert: TVegetationParams;
begin
   Result.TreeEnabled := False;
   Result.TreeDensity := 0;
   Result.TreeMinHeight := 4;
   Result.TreeMaxHeight := 6;
   Result.TreeCanopyRadius := 2;
   Result.TreeCanopyHeight := 2;
   Result.TreeNoiseFreq := 0.35;
   Result.TreeNoiseThresh := 0.20;
   Result.ShrubEnabled := False;
   Result.ShrubDensity := 0;
   Result.ShrubNoiseFreq := 0.60;
   Result.ShrubNoiseThresh := 0.30;
   Result.CactusEnabled := True;
   Result.CactusDensity := 0.15;
   Result.CactusMinHeight := 3;
   Result.CactusMaxHeight := 7;
   Result.CactusArmChance := 0.40;
   Result.CactusNoiseFreq := 0.40;
   Result.CactusNoiseThresh := 0.28;
end;

function DefaultVegForest: TVegetationParams;
begin
   Result.TreeEnabled := True;
   Result.TreeDensity := 0.28;
   Result.TreeMinHeight := 6;
   Result.TreeMaxHeight := 14;
   Result.TreeCanopyRadius := 4;
   Result.TreeCanopyHeight := 4;
   Result.TreeNoiseFreq := 0.25;
   Result.TreeNoiseThresh := 0.45;
   Result.ShrubEnabled := True;
   Result.ShrubDensity := 0.40;
   Result.ShrubNoiseFreq := 0.70;
   Result.ShrubNoiseThresh := 0.50;
   Result.CactusEnabled := False;
   Result.CactusDensity := 0;
   Result.CactusMinHeight := 3;
   Result.CactusMaxHeight := 5;
   Result.CactusArmChance := 0;
   Result.CactusNoiseFreq := 0.40;
   Result.CactusNoiseThresh := 0;
end;

function DefaultCaveDecor: TCaveDecoParams;
begin
   Result.RootsEnabled := True;
   Result.RootsDensity := 0.30;
   Result.RootsMinLen := 1;
   Result.RootsMaxLen := 6;
   Result.RootsNoiseFreq := 0.55;
   Result.VinesEnabled := True;
   Result.VinesDensity := 0.20;
   Result.VinesMinLen := 2;
   Result.VinesMaxLen := 12;
   Result.VinesNoiseFreq := 0.40;
   Result.StalEnabled := True;
   Result.StalDensity := 0.18;
   Result.StalMinLen := 1;
   Result.StalMaxLen := 5;
   Result.StalNoiseFreq := 0.65;
   Result.MushEnabled := True;
   Result.MushDensity := 0.10;
   Result.MushMinDepth := 20;
   Result.MossEnabled := True;
   Result.MossDensity := 0.25;
   Result.MossNoiseFreq := 0.80;
end;

{ ── Biome defaults ─────────────────────────────────────────────────────── }

function DefaultBiomePlains: TBiomeParams;
begin
   Result.SurfaceOffsetY := 0;
   Result.SurfaceAmpBonus := 0;
   Result.DepthDirtOverride := 0;
   Result.DepthDirtStoneOverride := 0;
   Result.SandstoneDepth := 0;
   Result.GraniteThreshold := 0;
   Result.MarbleThreshold := 0;
   Result.ClayThreshold := 0;
   Result.GravelThreshold := 0;
   Result.CaveDensityMult := 1.0;
   Result.SurfaceTileOverride := 0;
   Result.MinBiomeWidth := 120;
   Result.MaxBiomeWidth := 600;
end;

function DefaultBiomeDesert: TBiomeParams;
begin
   Result.SurfaceOffsetY := 4;
   Result.SurfaceAmpBonus := -4;
   Result.DepthDirtOverride := 0;
   Result.DepthDirtStoneOverride := 0;
   Result.SandstoneDepth := 8;
   Result.GraniteThreshold := 0;
   Result.MarbleThreshold := 0;
   Result.ClayThreshold := 0;
   Result.GravelThreshold := 0;
   Result.CaveDensityMult := 0.7;
   Result.SurfaceTileOverride := 0;
   Result.MinBiomeWidth := 80;
   Result.MaxBiomeWidth := 400;
end;

function DefaultBiomeForest: TBiomeParams;
begin
   Result.SurfaceOffsetY := -3;
   Result.SurfaceAmpBonus := 3;
   Result.DepthDirtOverride := 0;
   Result.DepthDirtStoneOverride := 0;
   Result.SandstoneDepth := 0;
   Result.GraniteThreshold := 0;
   Result.MarbleThreshold := 0;
   Result.ClayThreshold := 0;
   Result.GravelThreshold := 0;
   Result.CaveDensityMult := 1.3;
   Result.SurfaceTileOverride := 0;
   Result.MinBiomeWidth := 150;
   Result.MaxBiomeWidth := 700;
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
   Result.CaveThreshold := 0.14;
   Result.CaveFreqX := 0.045;
   Result.CaveFreqY := 0.055;
   Result.CaveOctaves := 3;
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
   Result.BiomePlains := DefaultBiomePlains;
   Result.BiomeDesert := DefaultBiomeDesert;
   Result.BiomeForest := DefaultBiomeForest;
   Result.DeepGraniteRatio := 0.30;
   Result.BedrockRows := 3;
   Result.VegPlains := DefaultVegPlains;
   Result.VegDesert := DefaultVegDesert;
   Result.VegForest := DefaultVegForest;
   Result.CaveDecor := DefaultCaveDecor;
end;

{ ── Clamping ──────────────────────────────────────────────────────────── }

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

   procedure ClampBiome(var B: TBiomeParams);
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
      { Ensure max >= min }
      if B.MaxBiomeWidth < B.MinBiomeWidth then
         B.MaxBiomeWidth := B.MinBiomeWidth;
   end;

   procedure ClampVeg(var V: TVegetationParams);
   begin
      V.TreeDensity := ClF(V.TreeDensity, 0, 1);
      V.TreeMinHeight := Cl(V.TreeMinHeight, 1, 12);
      V.TreeMaxHeight := Cl(V.TreeMaxHeight, 1, 20);
      if V.TreeMaxHeight < V.TreeMinHeight then
         V.TreeMaxHeight := V.TreeMinHeight;
      V.TreeCanopyRadius := Cl(V.TreeCanopyRadius, 1, 8);
      V.TreeCanopyHeight := Cl(V.TreeCanopyHeight, 1, 6);
      V.TreeNoiseFreq := ClF(V.TreeNoiseFreq, 0.05, 2.0);
      V.TreeNoiseThresh := ClF(V.TreeNoiseThresh, 0, 1);
      V.ShrubDensity := ClF(V.ShrubDensity, 0, 1);
      V.ShrubNoiseFreq := ClF(V.ShrubNoiseFreq, 0.1, 3.0);
      V.ShrubNoiseThresh := ClF(V.ShrubNoiseThresh, 0, 1);
      V.CactusDensity := ClF(V.CactusDensity, 0, 1);
      V.CactusMinHeight := Cl(V.CactusMinHeight, 1, 8);
      V.CactusMaxHeight := Cl(V.CactusMaxHeight, 1, 12);
      if V.CactusMaxHeight < V.CactusMinHeight then
         V.CactusMaxHeight := V.CactusMinHeight;
      V.CactusArmChance := ClF(V.CactusArmChance, 0, 1);
      V.CactusNoiseFreq := ClF(V.CactusNoiseFreq, 0.05, 2.0);
      V.CactusNoiseThresh := ClF(V.CactusNoiseThresh, 0, 1);
   end;

   procedure ClampCaveDecor(var C: TCaveDecoParams);
   begin
      C.RootsDensity := ClF(C.RootsDensity, 0, 1);
      C.RootsMinLen := Cl(C.RootsMinLen, 1, 8);
      C.RootsMaxLen := Cl(C.RootsMaxLen, 1, 14);
      if C.RootsMaxLen < C.RootsMinLen then
         C.RootsMaxLen := C.RootsMinLen;
      C.RootsNoiseFreq := ClF(C.RootsNoiseFreq, 0.05, 2.0);
      C.VinesDensity := ClF(C.VinesDensity, 0, 1);
      C.VinesMinLen := Cl(C.VinesMinLen, 1, 10);
      C.VinesMaxLen := Cl(C.VinesMaxLen, 1, 20);
      if C.VinesMaxLen < C.VinesMinLen then
         C.VinesMaxLen := C.VinesMinLen;
      C.VinesNoiseFreq := ClF(C.VinesNoiseFreq, 0.05, 2.0);
      C.StalDensity := ClF(C.StalDensity, 0, 1);
      C.StalMinLen := Cl(C.StalMinLen, 1, 6);
      C.StalMaxLen := Cl(C.StalMaxLen, 1, 12);
      if C.StalMaxLen < C.StalMinLen then
         C.StalMaxLen := C.StalMinLen;
      C.StalNoiseFreq := ClF(C.StalNoiseFreq, 0.05, 2.0);
      C.MushDensity := ClF(C.MushDensity, 0, 1);
      C.MushMinDepth := Cl(C.MushMinDepth, 10, 80);
      C.MossDensity := ClF(C.MossDensity, 0, 1);
      C.MossNoiseFreq := ClF(C.MossNoiseFreq, 0.05, 2.0);
   end;

begin
   P.BaseSurface := Cl(P.BaseSurface, 5, 100);
   P.SurfaceAmp := Cl(P.SurfaceAmp, 0, 50);
   P.MinSurface := Cl(P.MinSurface, 1, 70);
   P.MaxSurface := Cl(P.MaxSurface, 30, 200);
   P.SurfaceFreq := ClF(P.SurfaceFreq, 0.001, 0.05);
   P.SurfaceOctaves := Cl(P.SurfaceOctaves, 1, 8);
   P.SurfaceLacun := ClF(P.SurfaceLacun, 1.0, 4.0);
   P.SurfaceGain := ClF(P.SurfaceGain, 0.1, 0.9);
   P.DepthDirt := Cl(P.DepthDirt, 2, 20);
   P.DepthDirtStone := Cl(P.DepthDirtStone, 10, 60);
   P.DepthStone := Cl(P.DepthStone, 30, 150);
   P.SandstoneExtra := Cl(P.SandstoneExtra, 0, 20);
   P.CaveStartDepth := Cl(P.CaveStartDepth, 0, 20);
   P.CaveThreshold := ClF(P.CaveThreshold, 0.01, 0.5);
   P.CaveFreqX := ClF(P.CaveFreqX, 0.01, 0.2);
   P.CaveFreqY := ClF(P.CaveFreqY, 0.01, 0.2);
   P.CaveOctaves := Cl(P.CaveOctaves, 1, 5);
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
   P.DeepGraniteRatio := ClF(P.DeepGraniteRatio, 0.0, 1.0);
   P.BedrockRows := Cl(P.BedrockRows, 1, 8);
   ClampBiome(P.BiomePlains);
   ClampBiome(P.BiomeDesert);
   ClampBiome(P.BiomeForest);
   ClampVeg(P.VegPlains);
   ClampVeg(P.VegDesert);
   ClampVeg(P.VegForest);
   ClampCaveDecor(P.CaveDecor);
end;

{ ── Serialisation helpers ──────────────────────────────────────────────── }

const
   FILE_MAGIC = 'TerrariaGenParams';
   FILE_VERSION = '4';   { bumped: added MinBiomeWidth / MaxBiomeWidth }

procedure WriteI(SL: TStringList; const K: string; V: Integer);
begin
   SL.Add(K + '=' + IntToStr(V));
end;

procedure WriteF(SL: TStringList; const K: string; V: Single);
begin
   SL.Add(K + '=' + FloatToStr(V));
end;

procedure WriteB(SL: TStringList; const K: string; V: boolean);
begin
   SL.Add(K + '=' + IfThen(V, '1', '0'));
end;

procedure WriteBiome(SL: TStringList; const Pfx: string; const B: TBiomeParams);
begin
   WriteI(SL, Pfx + 'OffY', B.SurfaceOffsetY);
   WriteF(SL, Pfx + 'AmpBonus', B.SurfaceAmpBonus);
   WriteI(SL, Pfx + 'DirtOvr', B.DepthDirtOverride);
   WriteI(SL, Pfx + 'DirtStOvr', B.DepthDirtStoneOverride);
   WriteI(SL, Pfx + 'SsDepth', B.SandstoneDepth);
   WriteF(SL, Pfx + 'GranThr', B.GraniteThreshold);
   WriteF(SL, Pfx + 'MarbThr', B.MarbleThreshold);
   WriteF(SL, Pfx + 'ClayThr', B.ClayThreshold);
   WriteF(SL, Pfx + 'GravThr', B.GravelThreshold);
   WriteF(SL, Pfx + 'CaveMult', B.CaveDensityMult);
   WriteI(SL, Pfx + 'SurfTile', B.SurfaceTileOverride);
   WriteI(SL, Pfx + 'MinW', B.MinBiomeWidth);
   WriteI(SL, Pfx + 'MaxW', B.MaxBiomeWidth);
end;

procedure WriteVeg(SL: TStringList; const Pfx: string; const V: TVegetationParams);
begin
   WriteB(SL, Pfx + 'TreeOn', V.TreeEnabled);
   WriteF(SL, Pfx + 'TreeDens', V.TreeDensity);
   WriteI(SL, Pfx + 'TreeMinH', V.TreeMinHeight);
   WriteI(SL, Pfx + 'TreeMaxH', V.TreeMaxHeight);
   WriteI(SL, Pfx + 'TreeCRad', V.TreeCanopyRadius);
   WriteI(SL, Pfx + 'TreeCHgt', V.TreeCanopyHeight);
   WriteF(SL, Pfx + 'TreeNFreq', V.TreeNoiseFreq);
   WriteF(SL, Pfx + 'TreeNThr', V.TreeNoiseThresh);
   WriteB(SL, Pfx + 'ShrubOn', V.ShrubEnabled);
   WriteF(SL, Pfx + 'ShrubDens', V.ShrubDensity);
   WriteF(SL, Pfx + 'ShrubNFreq', V.ShrubNoiseFreq);
   WriteF(SL, Pfx + 'ShrubNThr', V.ShrubNoiseThresh);
   WriteB(SL, Pfx + 'CactOn', V.CactusEnabled);
   WriteF(SL, Pfx + 'CactDens', V.CactusDensity);
   WriteI(SL, Pfx + 'CactMinH', V.CactusMinHeight);
   WriteI(SL, Pfx + 'CactMaxH', V.CactusMaxHeight);
   WriteF(SL, Pfx + 'CactArm', V.CactusArmChance);
   WriteF(SL, Pfx + 'CactNFreq', V.CactusNoiseFreq);
   WriteF(SL, Pfx + 'CactNThr', V.CactusNoiseThresh);
end;

procedure WriteCaveDecor(SL: TStringList; const V: TCaveDecoParams);
begin
   WriteB(SL, 'RootsOn', V.RootsEnabled);
   WriteF(SL, 'RootsDens', V.RootsDensity);
   WriteI(SL, 'RootsMinL', V.RootsMinLen);
   WriteI(SL, 'RootsMaxL', V.RootsMaxLen);
   WriteF(SL, 'RootsNF', V.RootsNoiseFreq);
   WriteB(SL, 'VinesOn', V.VinesEnabled);
   WriteF(SL, 'VinesDens', V.VinesDensity);
   WriteI(SL, 'VinesMinL', V.VinesMinLen);
   WriteI(SL, 'VinesMaxL', V.VinesMaxLen);
   WriteF(SL, 'VinesNF', V.VinesNoiseFreq);
   WriteB(SL, 'StalOn', V.StalEnabled);
   WriteF(SL, 'StalDens', V.StalDensity);
   WriteI(SL, 'StalMinL', V.StalMinLen);
   WriteI(SL, 'StalMaxL', V.StalMaxLen);
   WriteF(SL, 'StalNF', V.StalNoiseFreq);
   WriteB(SL, 'MushOn', V.MushEnabled);
   WriteF(SL, 'MushDens', V.MushDensity);
   WriteI(SL, 'MushMinD', V.MushMinDepth);
   WriteB(SL, 'MossOn', V.MossEnabled);
   WriteF(SL, 'MossDens', V.MossDensity);
   WriteF(SL, 'MossNF', V.MossNoiseFreq);
end;

function SaveGenParams(const AFilePath: string; const P: TGenParams): boolean;
var
   SL: TStringList;
begin
   Result := False;
   SL := TStringList.Create;
   try
      SL.Add('MAGIC=' + FILE_MAGIC);
      SL.Add('VERSION=' + FILE_VERSION);
      WriteI(SL, 'Seed', P.Seed);
      WriteI(SL, 'BaseSurface', P.BaseSurface);
      WriteI(SL, 'SurfaceAmp', P.SurfaceAmp);
      WriteI(SL, 'MinSurface', P.MinSurface);
      WriteI(SL, 'MaxSurface', P.MaxSurface);
      WriteF(SL, 'SurfaceFreq', P.SurfaceFreq);
      WriteI(SL, 'SurfaceOctaves', P.SurfaceOctaves);
      WriteF(SL, 'SurfaceLacun', P.SurfaceLacun);
      WriteF(SL, 'SurfaceGain', P.SurfaceGain);
      WriteI(SL, 'DepthDirt', P.DepthDirt);
      WriteI(SL, 'DepthDirtStone', P.DepthDirtStone);
      WriteI(SL, 'DepthStone', P.DepthStone);
      WriteI(SL, 'SandstoneExtra', P.SandstoneExtra);
      WriteB(SL, 'CavesEnabled', P.CavesEnabled);
      WriteI(SL, 'CaveStartDepth', P.CaveStartDepth);
      WriteF(SL, 'CaveThreshold', P.CaveThreshold);
      WriteF(SL, 'CaveFreqX', P.CaveFreqX);
      WriteF(SL, 'CaveFreqY', P.CaveFreqY);
      WriteI(SL, 'CaveOctaves', P.CaveOctaves);
      WriteF(SL, 'GranThr', P.GraniteThreshold);
      WriteF(SL, 'MarbThr', P.MarbleThreshold);
      WriteF(SL, 'ClayThr', P.ClayThreshold);
      WriteF(SL, 'GravThr', P.GravelThreshold);
      WriteF(SL, 'GranFreq', P.GraniteFreq);
      WriteF(SL, 'MarbFreq', P.MarbleFreq);
      WriteF(SL, 'BiomeFreq', P.BiomeFreq);
      WriteI(SL, 'BiomeOctaves', P.BiomeOctaves);
      WriteF(SL, 'DesertThr', P.DesertThreshold);
      WriteF(SL, 'ForestThr', P.ForestThreshold);
      WriteF(SL, 'DeepGranRatio', P.DeepGraniteRatio);
      WriteI(SL, 'BedrockRows', P.BedrockRows);
      WriteBiome(SL, 'Plains.', P.BiomePlains);
      WriteBiome(SL, 'Desert.', P.BiomeDesert);
      WriteBiome(SL, 'Forest.', P.BiomeForest);
      WriteVeg(SL, 'VegP.', P.VegPlains);
      WriteVeg(SL, 'VegD.', P.VegDesert);
      WriteVeg(SL, 'VegF.', P.VegForest);
      WriteCaveDecor(SL, P.CaveDecor);
      SL.SaveToFile(AFilePath);
      Result := True;
   except
   end;
   SL.Free;
end;

{ ── Reader helpers ──────────────────────────────────────────────────────── }

function ReadVal(SL: TStringList; const K, Def: string): string;
var
   I: Integer;
begin
   Result := Def;
   for I := 0 to SL.Count - 1 do
      if SL.Names[I] = K then
      begin
         Result := SL.ValueFromIndex[I];
         Exit;
      end;
end;

function RI(SL: TStringList; const K: string; Def: Integer): Integer;
begin
   Result := StrToIntDef(ReadVal(SL, K, IntToStr(Def)), Def);
end;

function RF(SL: TStringList; const K: string; Def: Single): Single;
var
   E: Integer;
begin
   Val(ReadVal(SL, K, FloatToStr(Def)), Result, E);
   if E <> 0 then
      Result := Def;
end;

function RB(SL: TStringList; const K: string; Def: boolean): boolean;
begin
   Result := ReadVal(SL, K, IfThen(Def, '1', '0')) = '1';
end;

procedure ReadBiome(SL: TStringList; const Pfx: string; var B: TBiomeParams);
begin
   B.SurfaceOffsetY := RI(SL, Pfx + 'OffY', B.SurfaceOffsetY);
   B.SurfaceAmpBonus := RF(SL, Pfx + 'AmpBonus', B.SurfaceAmpBonus);
   B.DepthDirtOverride := RI(SL, Pfx + 'DirtOvr', B.DepthDirtOverride);
   B.DepthDirtStoneOverride := RI(SL, Pfx + 'DirtStOvr', B.DepthDirtStoneOverride);
   B.SandstoneDepth := RI(SL, Pfx + 'SsDepth', B.SandstoneDepth);
   B.GraniteThreshold := RF(SL, Pfx + 'GranThr', B.GraniteThreshold);
   B.MarbleThreshold := RF(SL, Pfx + 'MarbThr', B.MarbleThreshold);
   B.ClayThreshold := RF(SL, Pfx + 'ClayThr', B.ClayThreshold);
   B.GravelThreshold := RF(SL, Pfx + 'GravThr', B.GravelThreshold);
   B.CaveDensityMult := RF(SL, Pfx + 'CaveMult', B.CaveDensityMult);
   B.SurfaceTileOverride := RI(SL, Pfx + 'SurfTile', B.SurfaceTileOverride);
   B.MinBiomeWidth := RI(SL, Pfx + 'MinW', B.MinBiomeWidth);
   B.MaxBiomeWidth := RI(SL, Pfx + 'MaxW', B.MaxBiomeWidth);
end;

procedure ReadVeg(SL: TStringList; const Pfx: string; var V: TVegetationParams);
begin
   V.TreeEnabled := RB(SL, Pfx + 'TreeOn', V.TreeEnabled);
   V.TreeDensity := RF(SL, Pfx + 'TreeDens', V.TreeDensity);
   V.TreeMinHeight := RI(SL, Pfx + 'TreeMinH', V.TreeMinHeight);
   V.TreeMaxHeight := RI(SL, Pfx + 'TreeMaxH', V.TreeMaxHeight);
   V.TreeCanopyRadius := RI(SL, Pfx + 'TreeCRad', V.TreeCanopyRadius);
   V.TreeCanopyHeight := RI(SL, Pfx + 'TreeCHgt', V.TreeCanopyHeight);
   V.TreeNoiseFreq := RF(SL, Pfx + 'TreeNFreq', V.TreeNoiseFreq);
   V.TreeNoiseThresh := RF(SL, Pfx + 'TreeNThr', V.TreeNoiseThresh);
   V.ShrubEnabled := RB(SL, Pfx + 'ShrubOn', V.ShrubEnabled);
   V.ShrubDensity := RF(SL, Pfx + 'ShrubDens', V.ShrubDensity);
   V.ShrubNoiseFreq := RF(SL, Pfx + 'ShrubNFreq', V.ShrubNoiseFreq);
   V.ShrubNoiseThresh := RF(SL, Pfx + 'ShrubNThr', V.ShrubNoiseThresh);
   V.CactusEnabled := RB(SL, Pfx + 'CactOn', V.CactusEnabled);
   V.CactusDensity := RF(SL, Pfx + 'CactDens', V.CactusDensity);
   V.CactusMinHeight := RI(SL, Pfx + 'CactMinH', V.CactusMinHeight);
   V.CactusMaxHeight := RI(SL, Pfx + 'CactMaxH', V.CactusMaxHeight);
   V.CactusArmChance := RF(SL, Pfx + 'CactArm', V.CactusArmChance);
   V.CactusNoiseFreq := RF(SL, Pfx + 'CactNFreq', V.CactusNoiseFreq);
   V.CactusNoiseThresh := RF(SL, Pfx + 'CactNThr', V.CactusNoiseThresh);
end;

procedure ReadCaveDecor(SL: TStringList; var V: TCaveDecoParams);
begin
   V.RootsEnabled := RB(SL, 'RootsOn', V.RootsEnabled);
   V.RootsDensity := RF(SL, 'RootsDens', V.RootsDensity);
   V.RootsMinLen := RI(SL, 'RootsMinL', V.RootsMinLen);
   V.RootsMaxLen := RI(SL, 'RootsMaxL', V.RootsMaxLen);
   V.RootsNoiseFreq := RF(SL, 'RootsNF', V.RootsNoiseFreq);
   V.VinesEnabled := RB(SL, 'VinesOn', V.VinesEnabled);
   V.VinesDensity := RF(SL, 'VinesDens', V.VinesDensity);
   V.VinesMinLen := RI(SL, 'VinesMinL', V.VinesMinLen);
   V.VinesMaxLen := RI(SL, 'VinesMaxL', V.VinesMaxLen);
   V.VinesNoiseFreq := RF(SL, 'VinesNF', V.VinesNoiseFreq);
   V.StalEnabled := RB(SL, 'StalOn', V.StalEnabled);
   V.StalDensity := RF(SL, 'StalDens', V.StalDensity);
   V.StalMinLen := RI(SL, 'StalMinL', V.StalMinLen);
   V.StalMaxLen := RI(SL, 'StalMaxL', V.StalMaxLen);
   V.StalNoiseFreq := RF(SL, 'StalNF', V.StalNoiseFreq);
   V.MushEnabled := RB(SL, 'MushOn', V.MushEnabled);
   V.MushDensity := RF(SL, 'MushDens', V.MushDensity);
   V.MushMinDepth := RI(SL, 'MushMinD', V.MushMinDepth);
   V.MossEnabled := RB(SL, 'MossOn', V.MossEnabled);
   V.MossDensity := RF(SL, 'MossDens', V.MossDensity);
   V.MossNoiseFreq := RF(SL, 'MossNF', V.MossNoiseFreq);
end;

function LoadGenParams(const AFilePath: string; var P: TGenParams): boolean;
var
   SL: TStringList;
begin
   Result := False;
   if not FileExists(AFilePath) then
      Exit;
   SL := TStringList.Create;
   try
      SL.LoadFromFile(AFilePath);
      if ReadVal(SL, 'MAGIC', '') <> FILE_MAGIC then
         Exit;
      P.Seed := RI(SL, 'Seed', P.Seed);
      P.BaseSurface := RI(SL, 'BaseSurface', P.BaseSurface);
      P.SurfaceAmp := RI(SL, 'SurfaceAmp', P.SurfaceAmp);
      P.MinSurface := RI(SL, 'MinSurface', P.MinSurface);
      P.MaxSurface := RI(SL, 'MaxSurface', P.MaxSurface);
      P.SurfaceFreq := RF(SL, 'SurfaceFreq', P.SurfaceFreq);
      P.SurfaceOctaves := RI(SL, 'SurfaceOctaves', P.SurfaceOctaves);
      P.SurfaceLacun := RF(SL, 'SurfaceLacun', P.SurfaceLacun);
      P.SurfaceGain := RF(SL, 'SurfaceGain', P.SurfaceGain);
      P.DepthDirt := RI(SL, 'DepthDirt', P.DepthDirt);
      P.DepthDirtStone := RI(SL, 'DepthDirtStone', P.DepthDirtStone);
      P.DepthStone := RI(SL, 'DepthStone', P.DepthStone);
      P.SandstoneExtra := RI(SL, 'SandstoneExtra', P.SandstoneExtra);
      P.CavesEnabled := RB(SL, 'CavesEnabled', P.CavesEnabled);
      P.CaveStartDepth := RI(SL, 'CaveStartDepth', P.CaveStartDepth);
      P.CaveThreshold := RF(SL, 'CaveThreshold', P.CaveThreshold);
      P.CaveFreqX := RF(SL, 'CaveFreqX', P.CaveFreqX);
      P.CaveFreqY := RF(SL, 'CaveFreqY', P.CaveFreqY);
      P.CaveOctaves := RI(SL, 'CaveOctaves', P.CaveOctaves);
      P.GraniteThreshold := RF(SL, 'GranThr', P.GraniteThreshold);
      P.MarbleThreshold := RF(SL, 'MarbThr', P.MarbleThreshold);
      P.ClayThreshold := RF(SL, 'ClayThr', P.ClayThreshold);
      P.GravelThreshold := RF(SL, 'GravThr', P.GravelThreshold);
      P.GraniteFreq := RF(SL, 'GranFreq', P.GraniteFreq);
      P.MarbleFreq := RF(SL, 'MarbFreq', P.MarbleFreq);
      P.BiomeFreq := RF(SL, 'BiomeFreq', P.BiomeFreq);
      P.BiomeOctaves := RI(SL, 'BiomeOctaves', P.BiomeOctaves);
      P.DesertThreshold := RF(SL, 'DesertThr', P.DesertThreshold);
      P.ForestThreshold := RF(SL, 'ForestThr', P.ForestThreshold);
      P.DeepGraniteRatio := RF(SL, 'DeepGranRatio', P.DeepGraniteRatio);
      P.BedrockRows := RI(SL, 'BedrockRows', P.BedrockRows);
      ReadBiome(SL, 'Plains.', P.BiomePlains);
      ReadBiome(SL, 'Desert.', P.BiomeDesert);
      ReadBiome(SL, 'Forest.', P.BiomeForest);
      ReadVeg(SL, 'VegP.', P.VegPlains);
      ReadVeg(SL, 'VegD.', P.VegDesert);
      ReadVeg(SL, 'VegF.', P.VegForest);
      ReadCaveDecor(SL, P.CaveDecor);
      ClampGenParams(P);
      Result := True;
   except
   end;
   SL.Free;
end;

function GenParamsPresetName(const AFilePath: string): string;
begin
   Result := ChangeFileExt(ExtractFileName(AFilePath), '');
end;

procedure TGenParams.SetSeed(NewSeed: longint);
begin
   Seed := NewSeed;
end;

end.
