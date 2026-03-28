unit Terraria.UI.GenEditor;

{$mode objfpc}{$H+}

{ TGenEditor — properties panel with vegetation + cave decoration sections. }

interface

uses
   SysUtils, Math, raylib,
   Terraria.GenParams;

const
   EDIT_W = 330;
   EDIT_H = 700;
   ROW_H = 22;
   COL_BG: TColor = (R: 14; G: 14; B: 22; A: 222);
   COL_HDR: TColor = (R: 30; G: 28; B: 42; A: 255);
   COL_TXT: TColor = (R: 200; G: 200; B: 200; A: 255);
   COL_ACC: TColor = (R: 80; G: 180; B: 255; A: 255);
   COL_BTN: TColor = (R: 50; G: 50; B: 70; A: 255);
   COL_ON: TColor = (R: 60; G: 200; B: 80; A: 255);
   COL_OFF: TColor = (R: 200; G: 60; B: 60; A: 255);
   COL_REG: TColor = (R: 255; G: 180; B: 30; A: 255);
   COL_RST: TColor = (R: 100; G: 100; B: 130; A: 255);
   COL_SAV: TColor = (R: 40; G: 160; B: 80; A: 255);
   COL_LOD: TColor = (R: 40; G: 100; B: 200; A: 255);
   COL_ERR: TColor = (R: 220; G: 60; B: 60; A: 255);
   COL_OK: TColor = (R: 60; G: 200; B: 80; A: 255);
   COL_PLAINS: TColor = (R: 56; G: 160; B: 56; A: 255);
   COL_DESERT: TColor = (R: 196; G: 174; B: 112; A: 255);
   COL_FOREST: TColor = (R: 28; G: 120; B: 28; A: 255);

type
   TSectionFlags = record
      Surface, Depth, Caves, Veins, Biomes, Deep, SaveLoad,
      Vegetation, CaveDecor: boolean;
   end;

   TBiomeTab = (btPlains, btDesert, btForest);

   TGenEditor = class
   private
      FVMouseX, FVMouseY: Integer;
      FPX, FPY: Integer;
      FParams: PGenParams;
      FScrollY: Integer;
      FRegeneratePressed: boolean;
      FResetPressed: boolean;
      FSections: TSectionFlags;
      FBiomeTab: TBiomeTab;
      FHeldTimer: Single;
      FHeldItem: Integer;
      FDelta: Single;
      FCX, FCY: Integer;
      FClipY0, FClipY1: Integer;
      FFileName: string;
      FFileNameEdit: boolean;
      FStatusMsg: string;
      FStatusOK: boolean;

      procedure BeginDraw;
      procedure SkipRow(ACount: Integer = 1);
      procedure DrawSectionHeader(const ATitle: string; var AOpen: boolean; AColor: TColor);
      function DrawIntSlider(const ALabel: string; var AValue: Integer; AMin, AMax, AStep: Integer): boolean;
      function DrawFloatSlider(const ALabel: string; var AValue: Single; AMin, AMax, AStep: Single; ADecimals: Integer = 3): boolean;
      function DrawToggle(const ALabel: string; var AValue: boolean): boolean;
      function DrawButton(const ALabel: string; AColor: TColor): boolean;
      procedure DrawBiomeTabs;
      function CurrentBiome: PBiomeParams;
      function Clicked(RX, RY, RW, RH: Integer): boolean;
      function InPanel: boolean;
      procedure HandleFileNameInput;
   public
      constructor Create(APX, APY: Integer; AParams: PGenParams);
      procedure Update(ADelta: Single);
      procedure Draw;
      property RegeneratePressed: boolean read FRegeneratePressed;
      property ResetPressed: boolean read FResetPressed;
      property PX: Integer read FPX write FPX;
      property PY: Integer read FPY write FPY;
      property Params: PGenParams read FParams write FParams;
   end;

implementation

uses
   P2D.Utils.RayLib;

constructor TGenEditor.Create(APX, APY: Integer; AParams: PGenParams);
begin
   inherited Create;
   FPX := APX;
   FPY := APY;
   FParams := AParams;
   FScrollY := 0;
   FHeldTimer := 0;
   FHeldItem := -1;
   FBiomeTab := btPlains;
   FSections.Surface := True;
   FSections.Depth := True;
   FSections.Caves := True;
   FSections.Veins := False;
   FSections.Biomes := True;
   FSections.Deep := False;
   FSections.SaveLoad := True;
   FSections.Vegetation := True;
   FSections.CaveDecor := True;
   FFileName := 'my_world.tgp';
   FStatusMsg := '';
   FStatusOK := True;
end;

procedure TGenEditor.Update(ADelta: Single);
var
   PhysW, PhysH: Integer;
   Sc, OX, OY: Single;
begin
   FRegeneratePressed := False;
   FResetPressed := False;
   FDelta := ADelta;
   PhysW := GetScreenWidth;
   PhysH := GetScreenHeight;
   if (PhysW > 0) and (PhysH > 0) then
   begin
      Sc := Min(PhysW / 1280.0, PhysH / 720.0);
      OX := (PhysW - 1280.0 * Sc) * 0.5;
      OY := (PhysH - 720.0 * Sc) * 0.5;
      FVMouseX := Round((GetMouseX - OX) / Sc);
      FVMouseY := Round((GetMouseY - OY) / Sc);
   end
   else
   begin
      FVMouseX := GetMouseX;
      FVMouseY := GetMouseY;
   end;
   if IsMouseButtonDown(MOUSE_BUTTON_LEFT) and (FHeldItem >= 0) then
      FHeldTimer := FHeldTimer + ADelta
   else
   begin
      FHeldTimer := 0;
      FHeldItem := -1;
   end;
   if FFileNameEdit then
      HandleFileNameInput;
end;

procedure TGenEditor.HandleFileNameInput;
var
   C: Integer;
begin
   if IsKeyPressed(KEY_BACKSPACE) and (Length(FFileName) > 0) then
      FFileName := Copy(FFileName, 1, Length(FFileName) - 1);
   if IsKeyPressed(KEY_ENTER) or IsKeyPressed(KEY_ESCAPE) then
      FFileNameEdit := False;
   C := GetCharPressed;
   while C > 0 do
   begin
      if (C >= 32) and (C < 127) and (Length(FFileName) < 60) then
         FFileName := FFileName + Chr(C);
      C := GetCharPressed;
   end;
end;

function TGenEditor.InPanel: boolean;
begin
   Result := (FVMouseX >= FPX) and (FVMouseX < FPX + EDIT_W) and (FVMouseY >= FPY) and (FVMouseY < FPY + EDIT_H);
end;

function TGenEditor.Clicked(RX, RY, RW, RH: Integer): boolean;
begin
   Result := IsMouseButtonPressed(MOUSE_BUTTON_LEFT) and (FVMouseX >= RX) and (FVMouseX < RX + RW) and (FVMouseY >= RY) and (FVMouseY < RY + RH);
end;

procedure TGenEditor.BeginDraw;
begin
   FCX := FPX + 4;
   FCY := FPY + 4 - FScrollY;
   FClipY0 := FPY;
   FClipY1 := FPY + EDIT_H;
end;

procedure TGenEditor.SkipRow(ACount: Integer);
begin
   FCY := FCY + ROW_H * ACount;
end;

procedure TGenEditor.DrawSectionHeader(const ATitle: string; var AOpen: boolean; AColor: TColor);
var
   Arrow: string;
begin
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 2;
      Exit;
   end;
   DrawRectangle(FPX, FCY, EDIT_W, ROW_H, COL_HDR);
   DrawLine(FPX, FCY + ROW_H - 1, FPX + EDIT_W, FCY + ROW_H - 1, AColor);
   if AOpen then
      Arrow := '▼ '
   else
      Arrow := '▶ ';
   DrawText(PChar(Arrow + ATitle), FCX, FCY + 4, 12, AColor);
   if Clicked(FPX, FCY, EDIT_W, ROW_H) then
      AOpen := not AOpen;
   FCY := FCY + ROW_H + 2;
end;

function TGenEditor.DrawIntSlider(const ALabel: string; var AValue: Integer; AMin, AMax, AStep: Integer): boolean;
const
   AW = 22;
   VW = 52;
var
   LY, VX, Old: Integer;
begin
   Result := False;
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 1;
      Exit;
   end;
   LY := FCY;
   Old := AValue;
   DrawText(PChar(ALabel), FCX, LY + 4, 10, COL_TXT);
   VX := FPX + EDIT_W - VW - AW * 2 - 4;
   DrawRectangle(VX, LY, AW, ROW_H - 2, COL_BTN);
   DrawText('◄', VX + 5, LY + 4, 10, COL_ACC);
   DrawRectangle(VX + AW, LY, VW, ROW_H - 2, COL_HDR);
   DrawText(PChar(IntToStr(AValue)), VX + AW + 4, LY + 4, 10, COL_TXT);
   DrawRectangle(VX + AW + VW, LY, AW, ROW_H - 2, COL_BTN);
   DrawText('►', VX + AW + VW + 5, LY + 4, 10, COL_ACC);
   if Clicked(VX, LY, AW, ROW_H) then
   begin
      AValue := Max(AMin, AValue - AStep);
      FHeldItem := LY * 1000;
   end;
   if Clicked(VX + AW + VW, LY, AW, ROW_H) then
   begin
      AValue := Min(AMax, AValue + AStep);
      FHeldItem := LY * 1000 + 1;
   end;
   FCY := FCY + ROW_H + 1;
   Result := AValue <> Old;
end;

function TGenEditor.DrawFloatSlider(const ALabel: string; var AValue: Single; AMin, AMax, AStep: Single; ADecimals: Integer): boolean;
const
   AW = 22;
   VW = 64;
var
   LY, VX: Integer;
   Old: Single;
   Fmt: string;
begin
   Result := False;
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 1;
      Exit;
   end;
   LY := FCY;
   Old := AValue;
   DrawText(PChar(ALabel), FCX, LY + 4, 10, COL_TXT);
   VX := FPX + EDIT_W - VW - AW * 2 - 4;
   DrawRectangle(VX, LY, AW, ROW_H - 2, COL_BTN);
   DrawText('◄', VX + 5, LY + 4, 10, COL_ACC);
   DrawRectangle(VX + AW, LY, VW, ROW_H - 2, COL_HDR);
   Fmt := '%.' + IntToStr(ADecimals) + 'f';
   DrawText(PChar(Format(Fmt, [AValue])), VX + AW + 4, LY + 4, 10, COL_TXT);
   DrawRectangle(VX + AW + VW, LY, AW, ROW_H - 2, COL_BTN);
   DrawText('►', VX + AW + VW + 5, LY + 4, 10, COL_ACC);
   if Clicked(VX, LY, AW, ROW_H) then
      AValue := Max(AMin, AValue - AStep);
   if Clicked(VX + AW + VW, LY, AW, ROW_H) then
      AValue := Min(AMax, AValue + AStep);
   FCY := FCY + ROW_H + 1;
   Result := AValue <> Old;
end;

function TGenEditor.DrawToggle(const ALabel: string; var AValue: boolean): boolean;
const
   TW = 46;
var
   LY, TX: Integer;
   Old: boolean;
begin
   Result := False;
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 1;
      Exit;
   end;
   LY := FCY;
   TX := FPX + EDIT_W - TW - 4;
   Old := AValue;
   DrawText(PChar(ALabel), FCX, LY + 4, 10, COL_TXT);
   if AValue then
   begin
      DrawRectangle(TX, LY, TW, ROW_H - 2, COL_ON);
      DrawText('ON', TX + 12, LY + 4, 10, ColorCreate(20, 20, 20, 255));
   end
   else
   begin
      DrawRectangle(TX, LY, TW, ROW_H - 2, COL_OFF);
      DrawText('OFF', TX + 8, LY + 4, 10, ColorCreate(20, 20, 20, 255));
   end;
   if Clicked(TX, LY, TW, ROW_H) then
      AValue := not AValue;
   FCY := FCY + ROW_H + 1;
   Result := AValue <> Old;
end;

function TGenEditor.DrawButton(const ALabel: string; AColor: TColor): boolean;
var
   BW: Integer;
begin
   Result := False;
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 1;
      Exit;
   end;
   BW := EDIT_W - 8;
   DrawRectangle(FCX, FCY, BW, ROW_H - 1, AColor);
   DrawRectangleLinesEx(RectangleCreate(FCX, FCY, BW, ROW_H - 1), 1, ColorCreate(255, 255, 255, 40));
   DrawText(PChar(ALabel), FCX + BW div 2 - Round(MeasureText(PChar(ALabel), 11) * 0.5),
      FCY + 4, 11, ColorCreate(20, 20, 20, 255));
   if Clicked(FCX, FCY, BW, ROW_H) then
      Result := True;
   FCY := FCY + ROW_H + 2;
end;

procedure TGenEditor.DrawBiomeTabs;
const
   TW = (EDIT_W - 8) div 3;
var
   TX, TY: Integer;
   Cols: array[0..2] of TColor;
   I: Integer;
begin
   if (FCY + ROW_H + 2 < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 2;
      Exit;
   end;
   TY := FCY;
   Cols[0] := COL_PLAINS;
   Cols[1] := COL_DESERT;
   Cols[2] := COL_FOREST;
   for I := 0 to 2 do
   begin
      TX := FCX + I * TW;
      if TBiomeTab(I) = FBiomeTab then
         DrawRectangle(TX, TY, TW, ROW_H, Cols[I])
      else
         DrawRectangle(TX, TY, TW, ROW_H, ColorCreate(40, 40, 55, 255));
      DrawRectangleLinesEx(RectangleCreate(TX, TY, TW, ROW_H), 1,
         ColorCreate(Cols[I].R, Cols[I].G, Cols[I].B, 120));
      case I of
         0:
            DrawText('Plains', TX + TW div 2 - 20, TY + 5, 11, ColorCreate(220, 255, 220, 255));
         1:
            DrawText('Desert', TX + TW div 2 - 20, TY + 5, 11, ColorCreate(255, 240, 200, 255));
         2:
            DrawText('Forest', TX + TW div 2 - 18, TY + 5, 11, ColorCreate(200, 240, 200, 255));
      end;
      if Clicked(TX, TY, TW, ROW_H) then
         FBiomeTab := TBiomeTab(I);
   end;
   FCY := FCY + ROW_H + 4;
end;

function TGenEditor.CurrentBiome: PBiomeParams;
begin
   case FBiomeTab of
      btDesert:
         Result := @FParams^.BiomeDesert;
      btForest:
         Result := @FParams^.BiomeForest;
      else
         Result := @FParams^.BiomePlains;
   end;
end;

procedure TGenEditor.Draw;
var
   P: PGenParams;
   B: PBiomeParams;
   VP: PVegetationParams;
   CD: PCaveDecoParams;
   ContentH, MaxScroll, SBH, SBY: Integer;
   FNBoxW, FNBoxX, HW, BLY: Integer;
   FNDisplayed, BName: string;
   FNBoxCol: TColor;
   Wheel: Single;
begin
   P := FParams;

   { Panel frame }
   DrawRectangle(FPX, FPY, EDIT_W, EDIT_H, COL_BG);
   DrawRectangleLinesEx(RectangleCreate(FPX, FPY, EDIT_W, EDIT_H), 1, COL_ACC);
   DrawRectangle(FPX, FPY, EDIT_W, 20, COL_HDR);
   DrawText('Generation Properties', FPX + 6, FPY + 4, 12, COL_ACC);

   BeginDraw;
   FCY := FPY + 22 - FScrollY;

   { Action buttons }
   FRegeneratePressed := DrawButton('▶  REGENERATE WORLD', COL_REG) or FRegeneratePressed;
   FResetPressed := DrawButton('↺  Reset to Defaults', COL_RST) or FResetPressed;
   SkipRow;

   { ══ SURFACE ══ }
   DrawSectionHeader('SURFACE SHAPE', FSections.Surface, COL_ACC);
   if FSections.Surface then
   begin
      DrawIntSlider('Base Surface Y', P^.BaseSurface, 5, 100, 1);
      DrawIntSlider('Surface Amplitude', P^.SurfaceAmp, 0, 50, 1);
      DrawIntSlider('Min Surface Row', P^.MinSurface, 1, 70, 1);
      DrawIntSlider('Max Surface Row', P^.MaxSurface, 30, 200, 1);
      DrawFloatSlider('Noise Frequency', P^.SurfaceFreq, 0.001, 0.05, 0.001, 4);
      DrawIntSlider('FBM Octaves', P^.SurfaceOctaves, 1, 8, 1);
      DrawFloatSlider('Lacunarity', P^.SurfaceLacun, 1.0, 4.0, 0.1, 2);
      DrawFloatSlider('Gain (Persistence)', P^.SurfaceGain, 0.1, 0.9, 0.05, 2);
      SkipRow;
   end;

   { ══ DEPTH ZONES ══ }
   DrawSectionHeader('DEPTH ZONES', FSections.Depth, COL_ACC);
   if FSections.Depth then
   begin
      DrawIntSlider('Dirt Depth (rows)', P^.DepthDirt, 2, 20, 1);
      DrawIntSlider('Dirt+Stone Mix Depth', P^.DepthDirtStone, 10, 60, 1);
      DrawIntSlider('Stone Zone End', P^.DepthStone, 30, 150, 5);
      DrawIntSlider('Desert Sandstone Extra', P^.SandstoneExtra, 0, 20, 1);
      SkipRow;
   end;

   { ══ CAVE SYSTEM ══ }
   DrawSectionHeader('CAVE SYSTEM', FSections.Caves, COL_ACC);
   if FSections.Caves then
   begin
      DrawToggle('Caves Enabled', P^.CavesEnabled);
      DrawIntSlider('Start Depth', P^.CaveStartDepth, 0, 20, 1);
      DrawFloatSlider('Worm Threshold', P^.CaveThreshold, 0.01, 0.5, 0.01, 3);
      DrawFloatSlider('Noise Freq X', P^.CaveFreqX, 0.01, 0.2, 0.005, 3);
      DrawFloatSlider('Noise Freq Y', P^.CaveFreqY, 0.01, 0.2, 0.005, 3);
      DrawIntSlider('FBM Octaves', P^.CaveOctaves, 1, 5, 1);
      SkipRow;
   end;

   { ══ VEINS & POCKETS ══ }
   DrawSectionHeader('VEINS & POCKETS', FSections.Veins, COL_ACC);
   if FSections.Veins then
   begin
      DrawFloatSlider('Granite Threshold', P^.GraniteThreshold, 0.3, 0.95, 0.01, 2);
      DrawFloatSlider('Marble Threshold', P^.MarbleThreshold, 0.3, 0.95, 0.01, 2);
      DrawFloatSlider('Clay Threshold', P^.ClayThreshold, 0.3, 0.95, 0.01, 2);
      DrawFloatSlider('Gravel Threshold', P^.GravelThreshold, 0.3, 0.95, 0.01, 2);
      DrawFloatSlider('Granite Freq', P^.GraniteFreq, 0.01, 0.2, 0.005, 3);
      DrawFloatSlider('Marble Freq', P^.MarbleFreq, 0.01, 0.2, 0.005, 3);
      SkipRow;
   end;

   { ══ BIOME DISTRIBUTION ══ }
   DrawSectionHeader('BIOME DISTRIBUTION', FSections.Biomes, COL_ACC);
   if FSections.Biomes then
   begin
      DrawFloatSlider('Map Frequency', P^.BiomeFreq, 0.0005, 0.02, 0.0005, 4);
      DrawIntSlider('FBM Octaves', P^.BiomeOctaves, 1, 4, 1);
      DrawFloatSlider('Desert Threshold', P^.DesertThreshold, 0.05, 0.6, 0.01, 2);
      DrawFloatSlider('Forest Threshold', P^.ForestThreshold, 0.4, 0.95, 0.01, 2);
      SkipRow;
      DrawBiomeTabs;
      B := CurrentBiome;
      case FBiomeTab of
         btDesert:
            BName := 'Desert';
         btForest:
            BName := 'Forest';
         else
            BName := 'Plains';
      end;
      DrawText(PChar('[ ' + BName + ' overrides — 0 = use global ]'),
         FCX, FCY + 2, 9, ColorCreate(160, 160, 180, 200));
      FCY := FCY + 14;
      DrawIntSlider('Surface Offset Y', B^.SurfaceOffsetY, -20, 20, 1);
      DrawFloatSlider('Amplitude Bonus', B^.SurfaceAmpBonus, -20, 20, 1, 1);
      DrawIntSlider('Dirt Depth Override', B^.DepthDirtOverride, 0, 20, 1);
      DrawIntSlider('Dirt-Stone Override', B^.DepthDirtStoneOverride, 0, 60, 1);
      DrawIntSlider('Sandstone Depth', B^.SandstoneDepth, 0, 30, 1);
      DrawFloatSlider('Granite Thr Override', B^.GraniteThreshold, 0, 1.0, 0.01, 2);
      DrawFloatSlider('Marble Thr Override', B^.MarbleThreshold, 0, 1.0, 0.01, 2);
      DrawFloatSlider('Clay Thr Override', B^.ClayThreshold, 0, 1.0, 0.01, 2);
      DrawFloatSlider('Gravel Thr Override', B^.GravelThreshold, 0, 1.0, 0.01, 2);
      DrawFloatSlider('Cave Density Mult', B^.CaveDensityMult, 0.0, 3.0, 0.1, 2);
      DrawIntSlider('Surface Tile (0=auto)', B^.SurfaceTileOverride, 0, 10, 1);
      SkipRow;
   end;

   { ══ VEGETATION ══ }
   DrawSectionHeader('VEGETATION', FSections.Vegetation,
      ColorCreate(80, 200, 80, 255));
   if FSections.Vegetation then
   begin
      DrawBiomeTabs;
      case FBiomeTab of
         btDesert:
            VP := @P^.VegDesert;
         btForest:
            VP := @P^.VegForest;
         else
            VP := @P^.VegPlains;
      end;

      DrawText('Trees:', FCX, FCY + 3, 10, ColorCreate(120, 220, 80, 255));
      FCY := FCY + ROW_H - 6;
      DrawToggle('  Trees Enabled', VP^.TreeEnabled);
      DrawFloatSlider('  Tree Density', VP^.TreeDensity, 0, 1, 0.01, 2);
      DrawIntSlider('  Min Height (tiles)', VP^.TreeMinHeight, 1, 12, 1);
      DrawIntSlider('  Max Height (tiles)', VP^.TreeMaxHeight, 1, 20, 1);
      DrawIntSlider('  Canopy Radius', VP^.TreeCanopyRadius, 1, 8, 1);
      DrawIntSlider('  Canopy Height', VP^.TreeCanopyHeight, 1, 6, 1);
      DrawFloatSlider('  Spacing Noise Freq', VP^.TreeNoiseFreq, 0.05, 2.0, 0.05, 2);
      DrawFloatSlider('  Spacing Threshold', VP^.TreeNoiseThresh, 0, 1, 0.01, 2);
      SkipRow;

      DrawText('Shrubs / Ferns:', FCX, FCY + 3, 10, ColorCreate(100, 200, 60, 255));
      FCY := FCY + ROW_H - 6;
      DrawToggle('  Shrubs Enabled', VP^.ShrubEnabled);
      DrawFloatSlider('  Shrub Density', VP^.ShrubDensity, 0, 1, 0.01, 2);
      DrawFloatSlider('  Spacing Noise Freq', VP^.ShrubNoiseFreq, 0.1, 3.0, 0.05, 2);
      DrawFloatSlider('  Spacing Threshold', VP^.ShrubNoiseThresh, 0, 1, 0.01, 2);
      SkipRow;

      DrawText('Cacti:', FCX, FCY + 3, 10, ColorCreate(200, 200, 80, 255));
      FCY := FCY + ROW_H - 6;
      DrawToggle('  Cacti Enabled', VP^.CactusEnabled);
      DrawFloatSlider('  Cactus Density', VP^.CactusDensity, 0, 1, 0.01, 2);
      DrawIntSlider('  Min Height', VP^.CactusMinHeight, 1, 8, 1);
      DrawIntSlider('  Max Height', VP^.CactusMaxHeight, 1, 12, 1);
      DrawFloatSlider('  Arm Chance', VP^.CactusArmChance, 0, 1, 0.05, 2);
      DrawFloatSlider('  Spacing Noise Freq', VP^.CactusNoiseFreq, 0.05, 2.0, 0.05, 2);
      DrawFloatSlider('  Spacing Threshold', VP^.CactusNoiseThresh, 0, 1, 0.01, 2);
      SkipRow;
   end;

   { ══ CAVE DECORATIONS ══ }
   DrawSectionHeader('CAVE DECORATIONS', FSections.CaveDecor,
      ColorCreate(160, 120, 200, 255));
   if FSections.CaveDecor then
   begin
      CD := @P^.CaveDecor;

      DrawText('Roots (dirt ceilings):', FCX, FCY + 3, 10, ColorCreate(160, 110, 60, 255));
      FCY := FCY + ROW_H - 6;
      DrawToggle('  Roots Enabled', CD^.RootsEnabled);
      DrawFloatSlider('  Density', CD^.RootsDensity, 0, 1, 0.01, 2);
      DrawIntSlider('  Min Length', CD^.RootsMinLen, 1, 8, 1);
      DrawIntSlider('  Max Length', CD^.RootsMaxLen, 1, 14, 1);
      DrawFloatSlider('  Noise Freq', CD^.RootsNoiseFreq, 0.05, 2.0, 0.05, 2);
      SkipRow;

      DrawText('Vines (stone ceilings):', FCX, FCY + 3, 10, ColorCreate(80, 200, 80, 255));
      FCY := FCY + ROW_H - 6;
      DrawToggle('  Vines Enabled', CD^.VinesEnabled);
      DrawFloatSlider('  Density', CD^.VinesDensity, 0, 1, 0.01, 2);
      DrawIntSlider('  Min Length', CD^.VinesMinLen, 1, 10, 1);
      DrawIntSlider('  Max Length', CD^.VinesMaxLen, 1, 20, 1);
      DrawFloatSlider('  Noise Freq', CD^.VinesNoiseFreq, 0.05, 2.0, 0.05, 2);
      SkipRow;

      DrawText('Stalactites + Stalagmites:', FCX, FCY + 3, 10, ColorCreate(180, 180, 200, 255));
      FCY := FCY + ROW_H - 6;
      DrawToggle('  Stal. Enabled', CD^.StalEnabled);
      DrawFloatSlider('  Density', CD^.StalDensity, 0, 1, 0.01, 2);
      DrawIntSlider('  Min Length', CD^.StalMinLen, 1, 6, 1);
      DrawIntSlider('  Max Length', CD^.StalMaxLen, 1, 12, 1);
      DrawFloatSlider('  Noise Freq', CD^.StalNoiseFreq, 0.05, 2.0, 0.05, 2);
      SkipRow;

      DrawText('Cave Mushrooms:', FCX, FCY + 3, 10, ColorCreate(220, 100, 180, 255));
      FCY := FCY + ROW_H - 6;
      DrawToggle('  Mushrooms Enabled', CD^.MushEnabled);
      DrawFloatSlider('  Density', CD^.MushDensity, 0, 1, 0.01, 2);
      DrawIntSlider('  Min Depth', CD^.MushMinDepth, 10, 80, 5);
      SkipRow;

      DrawText('Moss Patches:', FCX, FCY + 3, 10, ColorCreate(80, 160, 80, 255));
      FCY := FCY + ROW_H - 6;
      DrawToggle('  Moss Enabled', CD^.MossEnabled);
      DrawFloatSlider('  Density', CD^.MossDensity, 0, 1, 0.01, 2);
      DrawFloatSlider('  Noise Freq', CD^.MossNoiseFreq, 0.05, 2.0, 0.05, 2);
      SkipRow;
   end;

   { ══ DEEP ZONE ══ }
   DrawSectionHeader('DEEP ZONE', FSections.Deep, COL_ACC);
   if FSections.Deep then
   begin
      DrawFloatSlider('Granite/Marble Ratio', P^.DeepGraniteRatio, 0.0, 1.0, 0.05, 2);
      DrawIntSlider('Bedrock Rows', P^.BedrockRows, 1, 8, 1);
      SkipRow;
   end;

   { ══ SAVE / LOAD ══ }
   DrawSectionHeader('SAVE / LOAD SETTINGS', FSections.SaveLoad, COL_ACC);
   if FSections.SaveLoad then
   begin
      if (FCY + ROW_H >= FClipY0) and (FCY <= FClipY1) then
      begin
         DrawText('File:', FCX, FCY + 4, 10, COL_TXT);
         FNBoxX := FCX + 36;
         FNBoxW := EDIT_W - 44;
         FNBoxCol := IfThen(FFileNameEdit, ColorCreate(60, 60, 90, 255), COL_HDR);
         DrawRectangle(FNBoxX, FCY, FNBoxW, ROW_H - 2, FNBoxCol);
         DrawRectangleLinesEx(RectangleCreate(FNBoxX, FCY, FNBoxW, ROW_H - 2), 1,
            IfThen(FFileNameEdit, COL_ACC, ColorCreate(60, 60, 80, 200)));
         FNDisplayed := FFileName;
         if FFileNameEdit and (Round(Now * 2) mod 2 = 0) then
            FNDisplayed := FNDisplayed + '_';
         while (Length(FNDisplayed) > 1) and (MeasureText(PChar(FNDisplayed), 10) > FNBoxW - 8) do
            FNDisplayed := Copy(FNDisplayed, 2, MaxInt);
         DrawText(PChar(FNDisplayed), FNBoxX + 4, FCY + 4, 10, COL_TXT);
         if Clicked(FNBoxX, FCY, FNBoxW, ROW_H) then
            FFileNameEdit := True;
         FCY := FCY + ROW_H + 2;

         if (FCY + ROW_H >= FClipY0) and (FCY <= FClipY1) then
         begin
            HW := (EDIT_W - 8) div 2 - 2;
            BLY := FCY;
            DrawRectangle(FCX, BLY, HW, ROW_H - 1, COL_SAV);
            DrawText(PChar('Save'), FCX + HW div 2 - 16, BLY + 4, 11, ColorCreate(20, 20, 20, 255));
            DrawRectangle(FCX + HW + 4, BLY, HW, ROW_H - 1, COL_LOD);
            DrawText(PChar('Load'), FCX + HW + 4 + HW div 2 - 16, BLY + 4, 11, ColorCreate(20, 20, 20, 255));
            if Clicked(FCX, BLY, HW, ROW_H) then
            begin
               if SaveGenParams(FFileName, P^) then
               begin
                  FStatusMsg := 'Saved: ' + FFileName;
                  FStatusOK := True;
               end
               else
               begin
                  FStatusMsg := 'Save failed: ' + FFileName;
                  FStatusOK := False;
               end;
               FFileNameEdit := False;
            end;
            if Clicked(FCX + HW + 4, BLY, HW, ROW_H) then
            begin
               if LoadGenParams(FFileName, P^) then
               begin
                  FStatusMsg := 'Loaded: ' + FFileName;
                  FStatusOK := True;
               end
               else
               begin
                  FStatusMsg := 'Load failed: ' + FFileName;
                  FStatusOK := False;
               end;
               FFileNameEdit := False;
            end;
            FCY := FCY + ROW_H + 2;
            if (FStatusMsg <> '') and (FCY <= FClipY1) then
            begin
               DrawText(PChar(FStatusMsg), FCX, FCY + 4, 9, IfThen(FStatusOK, COL_OK, COL_ERR));
               FCY := FCY + 16;
            end;
         end;
      end;
      SkipRow;
   end;

   { Scroll limit }
   ContentH := FCY + FScrollY - FPY;
   MaxScroll := Max(0, ContentH - EDIT_H + 20);
   if FScrollY > MaxScroll then
      FScrollY := MaxScroll;

   if InPanel then
   begin
      Wheel := GetMouseWheelMove;
      if Wheel <> 0 then
      begin
         FScrollY := FScrollY - Round(Wheel * ROW_H * 3);
         if FScrollY < 0 then
            FScrollY := 0;
         if FScrollY > MaxScroll then
            FScrollY := MaxScroll;
      end;
   end;

   if MaxScroll > 0 then
   begin
      SBH := Max(20, Round(EDIT_H * EDIT_H / (ContentH + 1)));
      SBY := FPY + Round(FScrollY / MaxScroll * (EDIT_H - SBH));
      DrawRectangle(FPX + EDIT_W - 4, SBY, 3, SBH, ColorCreate(80, 80, 120, 200));
   end;
end;

function IfThen(B: boolean; const T, F: TColor): TColor;
begin
   if B then
      Result := T
   else
      Result := F;
end;

end.
