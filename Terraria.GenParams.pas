unit Terraria.GenParams;

{$mode objfpc}{$H+}
{$modeSwitch advancedRecords}

{ TGenParams — a single record holding every tuneable parameter that drives
  TChunkGenerator. Stored by value; passed by reference to the generator.

  All fields have documented ranges. The Reset procedure fills the record with
  the default values that reproduce the original hand-tuned terrain. }

interface

type
   { ──────────────────────────────────────────────────────────────────────── }
   { Per-biome surface modifiers (additive offsets on top of global params)  }
   TBiomeSurfaceParams = record
      SurfaceOffsetY: Integer;    { pushes surface up/down for this biome }
      SurfaceAmpBonus: Single;    { extra amplitude variation             }
   end;

   { ──────────────────────────────────────────────────────────────────────── }
   PGenParams = ^TGenParams;

   { TGenParams }

   TGenParams = record
      { ── Global ─────────────────────────────────────────────────────────── }
      Seed: LongInt;   { noise seed (0 = random on generate)      }

      { ── Surface shape ───────────────────────────────────────────────────── }
      BaseSurface: Integer;   { average surface Y row (tiles from top)  [5..100]  }
      SurfaceAmp: Integer;   { ± amplitude of surface variation (tiles) [0..50]  }
      MinSurface: Integer;   { hard ceiling on surface row             [1..70]   }
      MaxSurface: Integer;   { hard floor on surface row               [30..200] }
      SurfaceFreq: Single;    { noise frequency for surface shape        [0.001..0.05] }
      SurfaceOctaves: Integer;   { FBM octaves for surface                  [1..8]   }
      SurfaceLacun: Single;    { FBM lacunarity                           [1.0..4.0] }
      SurfaceGain: Single;    { FBM gain (persistence)                   [0.1..0.9] }

      { ── Depth zones ─────────────────────────────────────────────────────── }
      DepthDirt: Integer;   { rows below surface = pure dirt/sand     [2..20]   }
      DepthDirtStone: Integer;   { rows below surface = mixed zone         [10..60]  }
      DepthStone: Integer;   { rows below surface = stone zone ends    [30..150] }
      SandstoneExtra: Integer;   { extra sand/sandstone depth in desert    [0..20]   }

      { ── Cave system ─────────────────────────────────────────────────────── }
      CaveStartDepth: Integer;   { min depth below surface for caves       [0..20]   }
      CaveThreshold: Single;    { |FBM2D| < threshold → carve air        [0.01..0.5] }
      CaveFreqX: Single;    { noise frequency X for caves             [0.01..0.2] }
      CaveFreqY: Single;    { noise frequency Y for caves             [0.01..0.2] }
      CaveOctaves: Integer;   { FBM octaves for cave noise              [1..5]    }
      CavesEnabled: boolean;   { master toggle                                     }

      { ── Vein / ore pockets ───────────────────────────────────────────────── }
      GraniteThreshold: Single;  { FBM2D > threshold → granite in stone   [0.3..0.9] }
      MarbleThreshold: Single;  { FBM2D > threshold → marble in stone    [0.3..0.9] }
      ClayThreshold: Single;  { noise2D > threshold → clay pocket      [0.3..0.9] }
      GravelThreshold: Single;  { noise2D > threshold → gravel pocket    [0.3..0.9] }
      GraniteFreq: Single;  { noise freq for granite veins           [0.01..0.2] }
      MarbleFreq: Single;  { noise freq for marble veins            [0.01..0.2] }

      { ── Biome distribution ──────────────────────────────────────────────── }
      BiomeFreq: Single;  { noise freq for biome map (slow=wide biomes) [0.0005..0.02] }
      BiomeOctaves: Integer; { octaves for biome noise                [1..4]   }
      DesertThreshold: Single;  { noise < threshold → desert             [0.05..0.6] }
      ForestThreshold: Single;  { noise > threshold → forest             [0.4..0.95] }
      { note: plains = everything between DesertThreshold and ForestThreshold }

      { ── Per-biome tweaks ────────────────────────────────────────────────── }
      BiomePlains: TBiomeSurfaceParams;
      BiomeDesert: TBiomeSurfaceParams;
      BiomeForest: TBiomeSurfaceParams;

      { ── Deep zone ───────────────────────────────────────────────────────── }
      DeepGraniteRatio: Single;  { noise2D > ratio → granite in deep zone [0.0..1.0] }
      BedrockRows: Integer; { rows from world bottom that are bedrock [1..8]   }

      procedure SetSeed(NewSeed: LongInt);
   end;

{ Return a TGenParams filled with the default (hand-tuned) values }
function DefaultGenParams: TGenParams;

{ Clamp all fields to their documented valid ranges }
procedure ClampGenParams(var P: TGenParams);

implementation

function DefaultGenParams: TGenParams;
begin
   Result.Seed := 0;

   { Surface }
   Result.BaseSurface := 48;
   Result.SurfaceAmp := 14;
   Result.MinSurface := 20;
   Result.MaxSurface := 70;
   Result.SurfaceFreq := 0.008;
   Result.SurfaceOctaves := 4;
   Result.SurfaceLacun := 2.0;
   Result.SurfaceGain := 0.55;

   { Depth zones }
   Result.DepthDirt := 6;
   Result.DepthDirtStone := 22;
   Result.DepthStone := 80;
   Result.SandstoneExtra := 8;

   { Caves }
   Result.CaveStartDepth := 6;
   Result.CaveThreshold := 0.14;
   Result.CaveFreqX := 0.045;
   Result.CaveFreqY := 0.055;
   Result.CaveOctaves := 3;
   Result.CavesEnabled := True;

   { Veins }
   Result.GraniteThreshold := 0.55;
   Result.MarbleThreshold := 0.62;
   Result.ClayThreshold := 0.62;
   Result.GravelThreshold := 0.68;
   Result.GraniteFreq := 0.06;
   Result.MarbleFreq := 0.05;

   { Biomes }
   Result.BiomeFreq := 0.003;
   Result.BiomeOctaves := 2;
   Result.DesertThreshold := 0.30;
   Result.ForestThreshold := 0.68;

   { Per-biome tweaks — no offset by default }
   Result.BiomePlains.SurfaceOffsetY := 0;
   Result.BiomePlains.SurfaceAmpBonus := 0;
   Result.BiomeDesert.SurfaceOffsetY := 4;    { desert slightly lower }
   Result.BiomeDesert.SurfaceAmpBonus := -4;  { flatter desert }
   Result.BiomeForest.SurfaceOffsetY := -3;   { forest slightly higher }
   Result.BiomeForest.SurfaceAmpBonus := 3;   { more hilly }

   { Deep zone }
   Result.DeepGraniteRatio := 0.30;
   Result.BedrockRows := 3;
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
   P.BiomePlains.SurfaceOffsetY := Cl(P.BiomePlains.SurfaceOffsetY, -20, 20);
   P.BiomePlains.SurfaceAmpBonus := ClF(P.BiomePlains.SurfaceAmpBonus, -20, 20);
   P.BiomeDesert.SurfaceOffsetY := Cl(P.BiomeDesert.SurfaceOffsetY, -20, 20);
   P.BiomeDesert.SurfaceAmpBonus := ClF(P.BiomeDesert.SurfaceAmpBonus, -20, 20);
   P.BiomeForest.SurfaceOffsetY := Cl(P.BiomeForest.SurfaceOffsetY, -20, 20);
   P.BiomeForest.SurfaceAmpBonus := ClF(P.BiomeForest.SurfaceAmpBonus, -20, 20);
end;

{ TGenParams }

procedure TGenParams.SetSeed(NewSeed: LongInt);
begin
   Seed := NewSeed;
end;

end.
