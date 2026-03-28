unit Terraria.GenParams;

{$mode objfpc}{$H+}
{$modeSwitch advancedRecords}

{ TGenParams — complete generation parameter set for TChunkGenerator.

  BIOME CONFIGURATION EXPANSION
  ─────────────────────────────────────────────────────────────────────────────
  Each biome (Plains, Desert, Forest) now has its own TBiomeParams block with
  independent control over:
    • Surface shape (offset, amplitude bonus)
    • Depth zones (dirt, dirt-to-stone, sandstone override)
    • Ore/pocket thresholds and frequencies
    • Cave density multiplier
    • Background wall tile override

  SAVE / LOAD
  ─────────────────────────────────────────────────────────────────────────────
  SaveGenParams / LoadGenParams write/read a simple INI-style text file.
  Each field is stored as  KEY=VALUE  on its own line.  Unknown keys are
  silently ignored, so files from older versions load safely. }

interface

uses
   SysUtils, StrUtils, Classes;

type
   { ────────────────────────────────────────────────────────────────────────── }
   { Full per-biome configuration block                                         }
   PBiomeParams = ^TBiomeParams;
   TBiomeParams = record
      { Surface }
      SurfaceOffsetY: Integer;   { pushes surface up(−)/down(+)   [-20..20]  }
      SurfaceAmpBonus: Single;    { extra amplitude on top of global [-20..20] }

      { Depth overrides (0 = use global value) }
      DepthDirtOverride: Integer;  { 0 = use global DepthDirt      [0..20]  }
      DepthDirtStoneOverride: Integer;  { 0 = use global DepthDirtStone [0..60]  }
      SandstoneDepth: Integer;  { Desert sandstone rows below dirt [0..30]}

      { Ore / pocket thresholds (0 = use global) }
      GraniteThreshold: Single;   { 0 = use global  [0..1]  }
      MarbleThreshold: Single;
      ClayThreshold: Single;
      GravelThreshold: Single;

      { Cave density for this biome (1.0 = same as global, 0 = no caves) }
      CaveDensityMult: Single;   { [0.0..3.0] }

      { Unique surface tile (0 = use automatic biome default) }
      SurfaceTileOverride: Integer;  { TILE_* constant or 0 }
   end;

   PGenParams = ^TGenParams;

   TGenParams = record
      { ── Global ──────────────────────────────────────────────────────────── }
      Seed: longint;

      { ── Surface shape ───────────────────────────────────────────────────── }
      BaseSurface: Integer;   { [5..100]      }
      SurfaceAmp: Integer;   { [0..50]       }
      MinSurface: Integer;   { [1..70]       }
      MaxSurface: Integer;   { [30..200]     }
      SurfaceFreq: Single;    { [0.001..0.05] }
      SurfaceOctaves: Integer;   { [1..8]        }
      SurfaceLacun: Single;    { [1.0..4.0]    }
      SurfaceGain: Single;    { [0.1..0.9]    }

      { ── Global depth zones ──────────────────────────────────────────────── }
      DepthDirt: Integer;   { [2..20]       }
      DepthDirtStone: Integer;   { [10..60]      }
      DepthStone: Integer;   { [30..150]     }
      SandstoneExtra: Integer;   { [0..20]       }

      { ── Cave system ─────────────────────────────────────────────────────── }
      CavesEnabled: boolean;
      CaveStartDepth: Integer;   { [0..20]       }
      CaveThreshold: Single;     { [0.01..0.5]   }
      CaveFreqX: Single;         { [0.01..0.2]   }
      CaveFreqY: Single;         { [0.01..0.2]   }
      CaveOctaves: Integer;      { [1..5]        }

      { ── Global ore / pocket thresholds ─────────────────────────────────── }
      GraniteThreshold: Single;  { [0.3..0.95]   }
      MarbleThreshold: Single;
      ClayThreshold: Single;
      GravelThreshold: Single;
      GraniteFreq: Single;  { [0.01..0.2]   }
      MarbleFreq: Single;

      { ── Biome distribution ──────────────────────────────────────────────── }
      BiomeFreq: Single;  { [0.0005..0.02] }
      BiomeOctaves: Integer; { [1..4]         }
      DesertThreshold: Single;  { [0.05..0.6]    }
      ForestThreshold: Single;  { [0.4..0.95]    }

      { ── Full per-biome configuration blocks ─────────────────────────────── }
      BiomePlains: TBiomeParams;
      BiomeDesert: TBiomeParams;
      BiomeForest: TBiomeParams;

      { ── Deep zone ───────────────────────────────────────────────────────── }
      DeepGraniteRatio: Single;  { [0.0..1.0]    }
      BedrockRows: Integer; { [1..8]        }

      procedure SetSeed(NewSeed: longint);
   end;

{ ── Defaults & clamping ────────────────────────────────────────────────── }
function DefaultGenParams: TGenParams;
procedure ClampGenParams(var P: TGenParams);

 { ── Serialisation ──────────────────────────────────────────────────────── }
 { Returns True on success }
function SaveGenParams(const AFilePath: string; const P: TGenParams): boolean;
function LoadGenParams(const AFilePath: string; var P: TGenParams): boolean;

{ Preset name (used by preset library) }
function GenParamsPresetName(const AFilePath: string): string;

implementation

 { ═══════════════════════════════════════════════════════════════════════════ }
 { Defaults                                                                    }
 { ═══════════════════════════════════════════════════════════════════════════ }

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
end;

 { ═══════════════════════════════════════════════════════════════════════════ }
 { Clamping                                                                    }
 { ═══════════════════════════════════════════════════════════════════════════ }

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
end;

 { ═══════════════════════════════════════════════════════════════════════════ }
 { Serialisation — simple KEY=VALUE INI-style text                             }
 { ═══════════════════════════════════════════════════════════════════════════ }

const
   FILE_MAGIC = 'TerrariaGenParams';
   FILE_VERSION = '2';

{ ── Writer helpers ─────────────────────────────────────────────────────── }
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

procedure WriteBiome(SL: TStringList; const Prefix: string; const B: TBiomeParams);
begin
   WriteI(SL, Prefix + 'OffY', B.SurfaceOffsetY);
   WriteF(SL, Prefix + 'AmpBonus', B.SurfaceAmpBonus);
   WriteI(SL, Prefix + 'DirtOvr', B.DepthDirtOverride);
   WriteI(SL, Prefix + 'DirtStOvr', B.DepthDirtStoneOverride);
   WriteI(SL, Prefix + 'SsDepth', B.SandstoneDepth);
   WriteF(SL, Prefix + 'GranThr', B.GraniteThreshold);
   WriteF(SL, Prefix + 'MarbThr', B.MarbleThreshold);
   WriteF(SL, Prefix + 'ClayThr', B.ClayThreshold);
   WriteF(SL, Prefix + 'GravThr', B.GravelThreshold);
   WriteF(SL, Prefix + 'CaveMult', B.CaveDensityMult);
   WriteI(SL, Prefix + 'SurfTile', B.SurfaceTileOverride);
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
      { Global }
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
      { Per-biome }
      WriteBiome(SL, 'Plains.', P.BiomePlains);
      WriteBiome(SL, 'Desert.', P.BiomeDesert);
      WriteBiome(SL, 'Forest.', P.BiomeForest);
      SL.SaveToFile(AFilePath);
      Result := True;
   except
   end;
   SL.Free;
end;

{ ── Reader helpers ─────────────────────────────────────────────────────── }
function ReadVal(SL: TStringList; const K: string; Default: string): string;
var
   I: Integer;
begin
   Result := Default;
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

procedure ReadBiome(SL: TStringList; const Prefix: string; var B: TBiomeParams);
begin
   B.SurfaceOffsetY := RI(SL, Prefix + 'OffY', B.SurfaceOffsetY);
   B.SurfaceAmpBonus := RF(SL, Prefix + 'AmpBonus', B.SurfaceAmpBonus);
   B.DepthDirtOverride := RI(SL, Prefix + 'DirtOvr', B.DepthDirtOverride);
   B.DepthDirtStoneOverride := RI(SL, Prefix + 'DirtStOvr', B.DepthDirtStoneOverride);
   B.SandstoneDepth := RI(SL, Prefix + 'SsDepth', B.SandstoneDepth);
   B.GraniteThreshold := RF(SL, Prefix + 'GranThr', B.GraniteThreshold);
   B.MarbleThreshold := RF(SL, Prefix + 'MarbThr', B.MarbleThreshold);
   B.ClayThreshold := RF(SL, Prefix + 'ClayThr', B.ClayThreshold);
   B.GravelThreshold := RF(SL, Prefix + 'GravThr', B.GravelThreshold);
   B.CaveDensityMult := RF(SL, Prefix + 'CaveMult', B.CaveDensityMult);
   B.SurfaceTileOverride := RI(SL, Prefix + 'SurfTile', B.SurfaceTileOverride);
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

{ TGenParams.SetSeed }
procedure TGenParams.SetSeed(NewSeed: longint);
begin
   Seed := NewSeed;
end;

end.
