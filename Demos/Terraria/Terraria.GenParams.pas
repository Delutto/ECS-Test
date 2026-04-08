unit Terraria.GenParams;

{$mode objfpc}{$H+}
{$modeSwitch advancedRecords}

{ =============================================================================
  Terraria.GenParams — World Generation Parameters

  CHANGE LOG (liquid system addition)
  ────────────────────────────────────
  • Added TLiquidParams field to TGenParams.
  • DefaultGenParams initialises Liquid via DefaultLiquidParams.
  • SaveGenParams / LoadGenParams serialise and deserialise the full Liquid
    sub-record using a simple INI-like text format.

  All other fields are unchanged from the original.
  ============================================================================= }

interface

uses
   SysUtils, StrUtils, Classes,
   Terraria.Liquid;

type
   PBiomeParams = ^TBiomeParams;

   TBiomeParams = record
      SurfaceOffsetY, DepthDirtOverride, DepthDirtStoneOverride, SandstoneDepth,
      SurfaceTileOverride, MinBiomeWidth, MaxBiomeWidth: Integer;
      SurfaceAmpBonus, GraniteThreshold, MarbleThreshold, ClayThreshold,
      GravelThreshold, CaveDensityMult: Single;
   end;

   PVegetationParams = ^TVegetationParams;

   TVegetationParams = record
      TreeEnabled, ShrubEnabled, CactusEnabled: boolean;
      TreeDensity, TreeNoiseFreq, TreeNoiseThresh, ShrubDensity, ShrubNoiseFreq,
      ShrubNoiseThresh: Single;
      TreeMinHeight, TreeMaxHeight, TreeCanopyRadius, TreeCanopyHeight,
      CactusMinHeight, CactusMaxHeight: Integer;
      CactusDensity, CactusArmChance, CactusNoiseFreq, CactusNoiseThresh: Single;
   end;

   PCaveDecoParams = ^TCaveDecoParams;

   TCaveDecoParams = record
      RootsEnabled, VinesEnabled, StalEnabled, MushEnabled, MossEnabled: boolean;
      RootsDensity, RootsNoiseFreq, VinesDensity, VinesNoiseFreq, StalDensity,
      StalNoiseFreq: Single;
      MushDensity, MossDensity, MossNoiseFreq: Single;
      RootsMinLen, RootsMaxLen, VinesMinLen, VinesMaxLen, StalMinLen, StalMaxLen,
      MushMinDepth: Integer;
   end;

   PGenParams = ^TGenParams;

   TGenParams = record
      Seed: longint;
      BaseSurface, SurfaceAmp, MinSurface, MaxSurface, SurfaceOctaves: Integer;
      SurfaceFreq, SurfaceLacun, SurfaceGain: Single;
      DepthDirt, DepthDirtStone, DepthStone, SandstoneExtra, BedrockRows: Integer;
      CavesEnabled, ChamberEnabled: boolean;
      CaveStartDepth, CaveOctaves, ChamberOctaves: Integer;
      CaveThreshold, CaveThresholdDeep: Single;
      CaveFreqX, CaveFreqY: Single;
      CaveWarpStrength, CaveWarpFreq: Single;
      ChamberFreq, ChamberThreshold, ChamberWarpStrength: Single;
      GraniteThreshold, MarbleThreshold, ClayThreshold, GravelThreshold,
      GraniteFreq, MarbleFreq: Single;
      BiomeFreq, DesertThreshold, ForestThreshold, DeepGraniteRatio: Single;
      BiomeOctaves: Integer;
      BiomePlains, BiomeDesert, BiomeForest: TBiomeParams;
      VegPlains, VegDesert, VegForest: TVegetationParams;
      CaveDecor: TCaveDecoParams;

      { ── Liquid parameters (added for the liquid system) ── }
      Liquid: TLiquidParams;

      procedure SetSeed(N: longint);
   end;

function DefaultGenParams: TGenParams;
procedure ClampGenParams(var P: TGenParams);
function SaveGenParams(const F: string; const P: TGenParams): boolean;
function LoadGenParams(const F: string; var P: TGenParams): boolean;
function GenParamsPresetName(const F: string): string;

implementation

{ ── Internal helper constructors for sub-records ─────────────────────────── }

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

{ =============================================================================
  DefaultGenParams
  ============================================================================= }

function DefaultGenParams: TGenParams;
var
   CD: TCaveDecoParams;
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
   Result.BedrockRows := 3;
   Result.CavesEnabled := True;
   Result.CaveStartDepth := 6;
   Result.CaveThreshold := 0.10;
   Result.CaveThresholdDeep := 0.22;
   Result.CaveFreqX := 0.045;
   Result.CaveFreqY := 0.055;
   Result.CaveOctaves := 4;
   Result.CaveWarpStrength := 18.0;
   Result.CaveWarpFreq := 0.014;
   Result.ChamberEnabled := True;
   Result.ChamberFreq := 0.012;
   Result.ChamberOctaves := 2;
   Result.ChamberThreshold := 0.22;
   Result.ChamberWarpStrength := 30.0;
   Result.GraniteThreshold := 0.55;
   Result.GraniteFreq := 0.06;
   Result.MarbleThreshold := 0.62;
   Result.MarbleFreq := 0.05;
   Result.ClayThreshold := 0.68;
   Result.GravelThreshold := 0.68;
   Result.BiomeFreq := 0.003;
   Result.BiomeOctaves := 2;
   Result.DesertThreshold := 0.30;
   Result.ForestThreshold := 0.68;
   Result.DeepGraniteRatio := 0.35;

   { Biome overrides }
   Result.BiomePlains := DefaultBP(0, 0, 0, 0, 0, 80, 400, 0, 0, 0, 0, 0, 1.0);
   Result.BiomeDesert := DefaultBP(2, 2, 0, 8, 4, 80, 300, 4.0, 0, 0, 0, 0, 0.7);
   Result.BiomeForest := DefaultBP(-3, 0, 0, 0, 0, 120, 600, -2.0, 0, 0, 0, 0, 1.3);

   { Vegetation }
   Result.VegPlains := DefaultVeg(True, True, False, 0.35, 0.08, 0.4, 0.55, 0.12, 0.3, 0, 0, 0, 0, 3, 7, 3, 3, 0, 0);
   Result.VegDesert := DefaultVeg(False, False, True, 0, 0, 0, 0, 0, 0, 0.45, 0.35, 0.1, 0.35, 0, 0, 0, 0, 3, 7);
   Result.VegForest := DefaultVeg(True, True, False, 0.55, 0.07, 0.35, 0.65, 0.10, 0.25, 0, 0, 0, 0, 4, 10, 4, 4, 0, 0);

   { Cave decorations }
   CD.RootsEnabled := True;
   CD.RootsDensity := 0.35;
   CD.RootsNoiseFreq := 0.12;
   CD.RootsMinLen := 2;
   CD.RootsMaxLen := 6;
   CD.VinesEnabled := True;
   CD.VinesDensity := 0.30;
   CD.VinesNoiseFreq := 0.10;
   CD.VinesMinLen := 2;
   CD.VinesMaxLen := 8;
   CD.StalEnabled := True;
   CD.StalDensity := 0.25;
   CD.StalNoiseFreq := 0.14;
   CD.StalMinLen := 1;
   CD.StalMaxLen := 5;
   CD.MushEnabled := True;
   CD.MushDensity := 0.18;
   CD.MushMinDepth := 12;
   CD.MossEnabled := True;
   CD.MossDensity := 0.40;
   CD.MossNoiseFreq := 0.20;
   Result.CaveDecor := CD;

   { Liquid params — fully initialised via DefaultLiquidParams }
   Result.Liquid := DefaultLiquidParams;
end;

{ =============================================================================
  ClampGenParams — sanity-clamps all numeric fields
  ============================================================================= }

procedure ClampGenParams(var P: TGenParams);

   procedure CI(var V: Integer; Lo, Hi: Integer);
   begin
      if V < Lo then
         V := Lo;
      if V > Hi then
         V := Hi;
   end;

   procedure CS(var V: Single; Lo, Hi: Single);
   begin
      if V < Lo then
         V := Lo;
      if V > Hi then
         V := Hi;
   end;

   procedure ClampBiomeLiquid(var B: TLiquidBiomeParams);
   begin
      CS(B.SurfaceLakeProb, 0, 1);
      CI(B.SurfaceMinDepth, 1, 20);
      CI(B.SurfaceMaxFill, 1, 32);
      CS(B.UnderLakeProb, 0, 1);
      CS(B.UnderLakeFillRatio, 0.05, 1.0);
      CI(B.UnderLakeMinWorldY, 4, 200);
      CI(B.LavaStartY, 100, 255);
      CS(B.LavaProb, 0, 1);
   end;

begin
   CI(P.BaseSurface, 5, 150);
   CI(P.SurfaceAmp, 1, 60);
   CI(P.MinSurface, 2, 100);
   CI(P.MaxSurface, 20, 240);
   CI(P.SurfaceOctaves, 1, 8);
   CS(P.SurfaceFreq, 0.001, 0.2);
   CS(P.SurfaceLacun, 1.2, 4.0);
   CS(P.SurfaceGain, 0.1, 0.9);
   CI(P.DepthDirt, 1, 30);
   CI(P.DepthDirtStone, 5, 100);
   CI(P.DepthStone, 30, 230);
   CI(P.BedrockRows, 1, 8);
   CI(P.CaveStartDepth, 0, 30);
   CS(P.CaveThreshold, 0.01, 0.45);
   CS(P.CaveThresholdDeep, 0.01, 0.45);
   CS(P.CaveFreqX, 0.01, 0.3);
   CS(P.CaveFreqY, 0.01, 0.3);
   CI(P.CaveOctaves, 1, 8);
   CS(P.CaveWarpStrength, 0, 80);
   CS(P.CaveWarpFreq, 0.002, 0.06);
   CS(P.ChamberFreq, 0.002, 0.06);
   CI(P.ChamberOctaves, 1, 4);
   CS(P.ChamberThreshold, 0.02, 0.45);
   CS(P.ChamberWarpStrength, 0, 120);
   CS(P.BiomeFreq, 0.001, 0.1);
   CI(P.BiomeOctaves, 1, 6);
   CS(P.DesertThreshold, 0.05, 0.7);
   CS(P.ForestThreshold, 0.15, 0.95);
   CS(P.DeepGraniteRatio, 0, 1);

   { Clamp liquid sub-records }
   ClampBiomeLiquid(P.Liquid.Plains);
   ClampBiomeLiquid(P.Liquid.Desert);
   ClampBiomeLiquid(P.Liquid.Forest);
end;

procedure TGenParams.SetSeed(N: longint);
begin
   Seed := N;
end;

{ =============================================================================
  SaveGenParams / LoadGenParams — simple key=value text serialisation
  The format is backward-compatible: unknown keys are silently ignored on load.
  ============================================================================= }

function BoolStr(B: boolean): string;
begin
   if B then
      Result := '1'
   else
      Result := '0';
end;

function SaveGenParams(const F: string; const P: TGenParams): boolean;
var
   SL: TStringList;

   procedure W(const K: string; V: Integer);
   begin
      SL.Add(K + '=' + IntToStr(V));
   end;

   procedure WF(const K: string; V: Single);
   begin
      SL.Add(K + '=' + FloatToStr(V));
   end;

   procedure WB(const K: string; V: boolean);
   begin
      SL.Add(K + '=' + BoolStr(V));
   end;

   procedure WByte(const K: string; V: byte);
   begin
      SL.Add(K + '=' + IntToStr(V));
   end;

   procedure WriteLiquidBP(const Pfx: string; const B: TLiquidBiomeParams);
   begin
      WB(Pfx + 'SurfaceEnabled', B.SurfaceLakeEnabled);
      WF(Pfx + 'SurfaceProb', B.SurfaceLakeProb);
      W(Pfx + 'SurfaceType', Ord(B.SurfaceLakeType));
      W(Pfx + 'SurfaceMinDepth', B.SurfaceMinDepth);
      W(Pfx + 'SurfaceMaxFill', B.SurfaceMaxFill);
      WB(Pfx + 'UnderEnabled', B.UnderLakeEnabled);
      WF(Pfx + 'UnderProb', B.UnderLakeProb);
      W(Pfx + 'UnderType', Ord(B.UnderLakeType));
      WF(Pfx + 'UnderFillRatio', B.UnderLakeFillRatio);
      W(Pfx + 'UnderMinY', B.UnderLakeMinWorldY);
      WB(Pfx + 'LavaEnabled', B.LavaEnabled);
      W(Pfx + 'LavaStartY', B.LavaStartY);
      WF(Pfx + 'LavaProb', B.LavaProb);
   end;

   procedure WriteLiquidVisual(const Pfx: string; const V: TLiquidVisual);
   begin
      WByte(Pfx + 'R', V.R);
      WByte(Pfx + 'G', V.G);
      WByte(Pfx + 'B', V.B);
      WByte(Pfx + 'Alpha', V.Alpha);
      WB(Pfx + 'Emissive', V.Emissive);
      WByte(Pfx + 'EmitBr', V.EmitBrightness);
      WByte(Pfx + 'EmitR', V.EmitR);
      WByte(Pfx + 'EmitG', V.EmitG);
      WByte(Pfx + 'EmitB', V.EmitB);
      WF(Pfx + 'RipSpd', V.Anim.RippleSpeed);
      WF(Pfx + 'RipAmp', V.Anim.RippleAmp);
      WF(Pfx + 'FlkSpd', V.Anim.FlickerSpeed);
      WF(Pfx + 'FlkAmp', V.Anim.FlickerAmp);
   end;

begin
   Result := False;
   SL := TStringList.Create;
   try
      { ── terrain params (unchanged) ── }
      W('Seed', P.Seed);
      W('BaseSurface', P.BaseSurface);
      W('SurfaceAmp', P.SurfaceAmp);
      W('MinSurface', P.MinSurface);
      W('MaxSurface', P.MaxSurface);
      W('SurfaceOctaves', P.SurfaceOctaves);
      WF('SurfaceFreq', P.SurfaceFreq);
      WF('SurfaceLacun', P.SurfaceLacun);
      WF('SurfaceGain', P.SurfaceGain);
      W('DepthDirt', P.DepthDirt);
      W('DepthDirtStone', P.DepthDirtStone);
      W('DepthStone', P.DepthStone);
      WB('CavesEnabled', P.CavesEnabled);
      WF('CaveThreshold', P.CaveThreshold);
      WF('CaveThresholdDeep', P.CaveThresholdDeep);
      WF('CaveFreqX', P.CaveFreqX);
      WF('CaveFreqY', P.CaveFreqY);
      W('CaveOctaves', P.CaveOctaves);
      WF('CaveWarpStrength', P.CaveWarpStrength);
      WF('CaveWarpFreq', P.CaveWarpFreq);
      WB('ChamberEnabled', P.ChamberEnabled);
      WF('ChamberFreq', P.ChamberFreq);
      W('ChamberOctaves', P.ChamberOctaves);
      WF('ChamberThreshold', P.ChamberThreshold);
      WF('ChamberWarpStrength', P.ChamberWarpStrength);
      WF('BiomeFreq', P.BiomeFreq);
      W('BiomeOctaves', P.BiomeOctaves);
      WF('DesertThreshold', P.DesertThreshold);
      WF('ForestThreshold', P.ForestThreshold);
      WF('DeepGraniteRatio', P.DeepGraniteRatio);

      { ── liquid biome params ── }
      WriteLiquidBP('LiqPlains.', P.Liquid.Plains);
      WriteLiquidBP('LiqDesert.', P.Liquid.Desert);
      WriteLiquidBP('LiqForest.', P.Liquid.Forest);
      WriteLiquidVisual('LiqWater.', P.Liquid.WaterVisual);
      WriteLiquidVisual('LiqLava.', P.Liquid.LavaVisual);
      WriteLiquidVisual('LiqMud.', P.Liquid.MudVisual);

      SL.SaveToFile(F);
      Result := True;
   except
   end;
   SL.Free;
end;

function LoadGenParams(const F: string; var P: TGenParams): boolean;
var
   SL: TStringList;
   I: Integer;
   Key, Val: string;
   Pos: Integer;

   function GI(const K: string; Default: Integer): Integer;
   var
      J: Integer;
   begin
      Result := Default;
      for J := 0 to SL.Count - 1 do
         if StartsStr(K + '=', SL[J]) then
         begin
            Result := StrToIntDef(Copy(SL[J], Length(K) + 2, MaxInt), Default);
            Exit;
         end;
   end;

   function GF(const K: string; Default: Single): Single;
   var
      J: Integer;
   begin
      Result := Default;
      for J := 0 to SL.Count - 1 do
         if StartsStr(K + '=', SL[J]) then
         begin
            Result := StrToFloatDef(Copy(SL[J], Length(K) + 2, MaxInt), Default);
            Exit;
         end;
   end;

   function GB(const K: string; Default: boolean): boolean;
   begin
      Result := GI(K, Ord(Default)) <> 0;
   end;

   function GByte(const K: string; Default: byte): byte;
   begin
      Result := byte(GI(K, Default));
   end;

   procedure ReadLiquidBP(const Pfx: string; var B: TLiquidBiomeParams);
   begin
      B.SurfaceLakeEnabled := GB(Pfx + 'SurfaceEnabled', B.SurfaceLakeEnabled);
      B.SurfaceLakeProb := GF(Pfx + 'SurfaceProb', B.SurfaceLakeProb);
      B.SurfaceLakeType := TLiquidType(GI(Pfx + 'SurfaceType', Ord(B.SurfaceLakeType)));
      B.SurfaceMinDepth := GI(Pfx + 'SurfaceMinDepth', B.SurfaceMinDepth);
      B.SurfaceMaxFill := GI(Pfx + 'SurfaceMaxFill', B.SurfaceMaxFill);
      B.UnderLakeEnabled := GB(Pfx + 'UnderEnabled', B.UnderLakeEnabled);
      B.UnderLakeProb := GF(Pfx + 'UnderProb', B.UnderLakeProb);
      B.UnderLakeType := TLiquidType(GI(Pfx + 'UnderType', Ord(B.UnderLakeType)));
      B.UnderLakeFillRatio := GF(Pfx + 'UnderFillRatio', B.UnderLakeFillRatio);
      B.UnderLakeMinWorldY := GI(Pfx + 'UnderMinY', B.UnderLakeMinWorldY);
      B.LavaEnabled := GB(Pfx + 'LavaEnabled', B.LavaEnabled);
      B.LavaStartY := GI(Pfx + 'LavaStartY', B.LavaStartY);
      B.LavaProb := GF(Pfx + 'LavaProb', B.LavaProb);
   end;

   procedure ReadLiquidVisual(const Pfx: string; var V: TLiquidVisual);
   begin
      V.R := GByte(Pfx + 'R', V.R);
      V.G := GByte(Pfx + 'G', V.G);
      V.B := GByte(Pfx + 'B', V.B);
      V.Alpha := GByte(Pfx + 'Alpha', V.Alpha);
      V.Emissive := GB(Pfx + 'Emissive', V.Emissive);
      V.EmitBrightness := GByte(Pfx + 'EmitBr', V.EmitBrightness);
      V.EmitR := GByte(Pfx + 'EmitR', V.EmitR);
      V.EmitG := GByte(Pfx + 'EmitG', V.EmitG);
      V.EmitB := GByte(Pfx + 'EmitB', V.EmitB);
      V.Anim.RippleSpeed := GF(Pfx + 'RipSpd', V.Anim.RippleSpeed);
      V.Anim.RippleAmp := GF(Pfx + 'RipAmp', V.Anim.RippleAmp);
      V.Anim.FlickerSpeed := GF(Pfx + 'FlkSpd', V.Anim.FlickerSpeed);
      V.Anim.FlickerAmp := GF(Pfx + 'FlkAmp', V.Anim.FlickerAmp);
   end;

begin
   Result := False;
   if not FileExists(F) then
      Exit;
   SL := TStringList.Create;
   try
      SL.LoadFromFile(F);

      { Terrain fields }
      P.Seed := GI('Seed', P.Seed);
      P.BaseSurface := GI('BaseSurface', P.BaseSurface);
      P.SurfaceAmp := GI('SurfaceAmp', P.SurfaceAmp);
      P.MinSurface := GI('MinSurface', P.MinSurface);
      P.MaxSurface := GI('MaxSurface', P.MaxSurface);
      P.SurfaceOctaves := GI('SurfaceOctaves', P.SurfaceOctaves);
      P.SurfaceFreq := GF('SurfaceFreq', P.SurfaceFreq);
      P.SurfaceLacun := GF('SurfaceLacun', P.SurfaceLacun);
      P.SurfaceGain := GF('SurfaceGain', P.SurfaceGain);
      P.DepthDirt := GI('DepthDirt', P.DepthDirt);
      P.DepthDirtStone := GI('DepthDirtStone', P.DepthDirtStone);
      P.DepthStone := GI('DepthStone', P.DepthStone);
      P.CavesEnabled := GB('CavesEnabled', P.CavesEnabled);
      P.CaveThreshold := GF('CaveThreshold', P.CaveThreshold);
      P.CaveThresholdDeep := GF('CaveThresholdDeep', P.CaveThresholdDeep);
      P.CaveFreqX := GF('CaveFreqX', P.CaveFreqX);
      P.CaveFreqY := GF('CaveFreqY', P.CaveFreqY);
      P.CaveOctaves := GI('CaveOctaves', P.CaveOctaves);
      P.CaveWarpStrength := GF('CaveWarpStrength', P.CaveWarpStrength);
      P.CaveWarpFreq := GF('CaveWarpFreq', P.CaveWarpFreq);
      P.ChamberEnabled := GB('ChamberEnabled', P.ChamberEnabled);
      P.ChamberFreq := GF('ChamberFreq', P.ChamberFreq);
      P.ChamberOctaves := GI('ChamberOctaves', P.ChamberOctaves);
      P.ChamberThreshold := GF('ChamberThreshold', P.ChamberThreshold);
      P.ChamberWarpStrength := GF('ChamberWarpStrength', P.ChamberWarpStrength);
      P.BiomeFreq := GF('BiomeFreq', P.BiomeFreq);
      P.BiomeOctaves := GI('BiomeOctaves', P.BiomeOctaves);
      P.DesertThreshold := GF('DesertThreshold', P.DesertThreshold);
      P.ForestThreshold := GF('ForestThreshold', P.ForestThreshold);
      P.DeepGraniteRatio := GF('DeepGraniteRatio', P.DeepGraniteRatio);

      { Liquid biome params }
      ReadLiquidBP('LiqPlains.', P.Liquid.Plains);
      ReadLiquidBP('LiqDesert.', P.Liquid.Desert);
      ReadLiquidBP('LiqForest.', P.Liquid.Forest);
      ReadLiquidVisual('LiqWater.', P.Liquid.WaterVisual);
      ReadLiquidVisual('LiqLava.', P.Liquid.LavaVisual);
      ReadLiquidVisual('LiqMud.', P.Liquid.MudVisual);

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

end.
