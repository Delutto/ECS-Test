unit Terraria.UI.GenEditor;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math, raylib,
   Terraria.GenParams,
   Terraria.Lighting;

type
   TSectionFlags = record
      Surface, Depth, Caves, Veins, Biomes, Deep, SaveLoad,
      Vegetation, CaveDecor, Lighting: boolean;
   end;

   TBiomeTab = (btPlains, btDesert, btForest);

   TGenEditor = class
   private
      FVMouseX, FVMouseY: Integer;
      FPX, FPY: Integer;
      FParams: PGenParams;
      FLighting: PLightSettings;
      FScrollY: Integer;
      FRegeneratePressed: boolean;
      FResetPressed: boolean;
      FLoadPressed: boolean;
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
      function DrawByteSlider(const ALabel: string; var AValue: byte; AMin, AMax: byte): boolean;
      function DrawFloatSlider(const ALabel: string; var AValue: Single; AMin, AMax, AStep: Single; ADecimals: Integer = 3): boolean;
      function DrawToggle(const ALabel: string; var AValue: boolean): boolean;
      function DrawButton(const ALabel: string; AColor: TColor): boolean;
      procedure DrawBiomeTabs;
      function CurrentBiome: PBiomeParams;
      function Clicked(RX, RY, RW, RH: Integer): boolean;
      function InPanel: boolean;
      procedure HandleFileNameInput;
   public
      constructor Create(APX, APY: Integer; AParams: PGenParams; ALighting: PLightSettings);
      procedure Update(ADelta: Single);
      procedure Draw;
      property RegeneratePressed: boolean read FRegeneratePressed;
      property ResetPressed: boolean read FResetPressed;
      property LoadPressed: boolean read FLoadPressed;
      property PX: Integer read FPX write FPX;
      property PY: Integer read FPY write FPY;
      property Params: PGenParams read FParams write FParams;
      property Lighting: PLightSettings read FLighting write FLighting;
   end;

implementation

uses
   P2D.Utils.RayLib;

const
   EDIT_W = 260;
   EDIT_H = 720;
   ROW_H = 22;
   COL_BG: TColor = (R: 20; G: 20; B: 28; A: 240);
   COL_HDR: TColor = (R: 30; G: 30; B: 42; A: 255);
   COL_OK: TColor = (R: 80; G: 220; B: 80; A: 255);
   COL_ERR: TColor = (R: 220; G: 80; B: 80; A: 255);
   COL_REG: TColor = (R: 60; G: 180; B: 80; A: 255);
   COL_RST: TColor = (R: 180; G: 120; B: 40; A: 255);
   COL_SAV: TColor = (R: 60; G: 120; B: 200; A: 255);
   COL_LOD: TColor = (R: 120; G: 60; B: 200; A: 255);
   COL_PLAINS: TColor = (R: 80; G: 180; B: 80; A: 255);
   COL_DESERT: TColor = (R: 210; G: 170; B: 50; A: 255);
   COL_FOREST: TColor = (R: 40; G: 140; B: 60; A: 255);
   COL_SEC_SURF: TColor = (R: 100; G: 200; B: 100; A: 255);
   COL_SEC_DEPTH: TColor = (R: 160; G: 120; B: 60; A: 255);
   COL_SEC_CAVE: TColor = (R: 80; G: 80; B: 180; A: 255);
   COL_SEC_VEIN: TColor = (R: 180; G: 80; B: 180; A: 255);
   COL_SEC_BIOME: TColor = (R: 60; G: 160; B: 60; A: 255);
   COL_SEC_DEEP: TColor = (R: 60; G: 60; B: 160; A: 255);
   COL_SEC_SAVE: TColor = (R: 160; G: 160; B: 60; A: 255);
   COL_SEC_VEG: TColor = (R: 80; G: 200; B: 80; A: 255);
   COL_SEC_CDEC: TColor = (R: 100; G: 80; B: 160; A: 255);
   COL_SEC_LIGHT: TColor = (R: 255; G: 220; B: 80; A: 255);

constructor TGenEditor.Create(APX, APY: Integer; AParams: PGenParams; ALighting: PLightSettings);
begin
   inherited Create;
   FPX := APX;
   FPY := APY;
   FParams := AParams;
   FLighting := ALighting;
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
   FSections.Lighting := True;
   FFileName := 'my_world.tgp';
   FStatusMsg := '';
   FStatusOK := True;
end;

function TGenEditor.Clicked(RX, RY, RW, RH: Integer): boolean;
begin
   Result := IsMouseButtonPressed(MOUSE_BUTTON_LEFT) and (FVMouseX >= RX) and (FVMouseX < RX + RW) and (FVMouseY >= RY) and (FVMouseY < RY + RH);
end;

function TGenEditor.InPanel: boolean;
begin
   Result := (FVMouseX >= FPX) and (FVMouseX < FPX + EDIT_W) and (FVMouseY >= FPY) and (FVMouseY < FPY + EDIT_H);
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
      Arrow := 'v '
   else
      Arrow := '> ';
   DrawText(PChar(Arrow + ATitle), FCX, FCY + 4, 12, AColor);
   if Clicked(FPX, FCY, EDIT_W, ROW_H) then
      AOpen := not AOpen;
   FCY := FCY + ROW_H + 2;
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
   DrawText(PChar(ALabel), FCX + BW div 2 - Round(MeasureText(PChar(ALabel), 11) * 0.5), FCY + 4, 11, ColorCreate(20, 20, 20, 255));
   if Clicked(FCX, FCY, BW, ROW_H) then
      Result := True;
   FCY := FCY + ROW_H + 2;
end;

function TGenEditor.DrawIntSlider(const ALabel: string; var AValue: Integer; AMin, AMax, AStep: Integer): boolean;
var
   LW, VX, BW, OldVal: Integer;
begin
   Result := False;
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 1;
      Exit;
   end;
   OldVal := AValue;
   LW := 130;
   BW := 22;
   VX := FCX + LW + BW + 2;
   DrawText(PChar(ALabel), FCX, FCY + 4, 10, ColorCreate(200, 200, 200, 255));
   DrawRectangle(FCX + LW, FCY, BW, ROW_H - 1, ColorCreate(50, 50, 70, 255));
   DrawText(PChar('-'), FCX + LW + BW div 2 - 3, FCY + 4, 11, ColorCreate(220, 220, 220, 255));
   if Clicked(FCX + LW, FCY, BW, ROW_H) then
      AValue := Max(AMin, AValue - AStep);
   DrawRectangle(VX, FCY, 44, ROW_H - 1, ColorCreate(35, 35, 50, 255));
   DrawText(PChar(IntToStr(AValue)), VX + 22 - MeasureText(PChar(IntToStr(AValue)), 10) div 2, FCY + 4, 10, ColorCreate(240, 240, 100, 255));
   DrawRectangle(VX + 46, FCY, BW, ROW_H - 1, ColorCreate(50, 50, 70, 255));
   DrawText(PChar('+'), VX + 46 + BW div 2 - 3, FCY + 4, 11, ColorCreate(220, 220, 220, 255));
   if Clicked(VX + 46, FCY, BW, ROW_H) then
      AValue := Min(AMax, AValue + AStep);
   Result := AValue <> OldVal;
   FCY := FCY + ROW_H + 1;
end;

function TGenEditor.DrawByteSlider(const ALabel: string; var AValue: byte; AMin, AMax: byte): boolean;
var
   Tmp: Integer;
begin
   Tmp := AValue;
   Result := DrawIntSlider(ALabel, Tmp, AMin, AMax, 1);
   AValue := byte(Tmp);
end;

function TGenEditor.DrawFloatSlider(const ALabel: string; var AValue: Single; AMin, AMax, AStep: Single; ADecimals: Integer): boolean;
var
   LW, VX, BW: Integer;
   OldVal: Single;
   Fmt, VS: string;
begin
   Result := False;
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 1;
      Exit;
   end;
   OldVal := AValue;
   LW := 130;
   BW := 22;
   VX := FCX + LW + BW + 2;
   DrawText(PChar(ALabel), FCX, FCY + 4, 10, ColorCreate(200, 200, 200, 255));
   DrawRectangle(FCX + LW, FCY, BW, ROW_H - 1, ColorCreate(50, 50, 70, 255));
   DrawText(PChar('-'), FCX + LW + BW div 2 - 3, FCY + 4, 11, ColorCreate(220, 220, 220, 255));
   if Clicked(FCX + LW, FCY, BW, ROW_H) then
      AValue := Max(AMin, AValue - AStep);
   DrawRectangle(VX, FCY, 44, ROW_H - 1, ColorCreate(35, 35, 50, 255));
   Fmt := '%.' + IntToStr(ADecimals) + 'f';
   VS := Format(Fmt, [AValue]);
   DrawText(PChar(VS), VX + 22 - MeasureText(PChar(VS), 10) div 2, FCY + 4, 10, ColorCreate(240, 240, 100, 255));
   DrawRectangle(VX + 46, FCY, BW, ROW_H - 1, ColorCreate(50, 50, 70, 255));
   DrawText(PChar('+'), VX + 46 + BW div 2 - 3, FCY + 4, 11, ColorCreate(220, 220, 220, 255));
   if Clicked(VX + 46, FCY, BW, ROW_H) then
      AValue := Min(AMax, AValue + AStep);
   Result := AValue <> OldVal;
   FCY := FCY + ROW_H + 1;
end;

function TGenEditor.DrawToggle(const ALabel: string; var AValue: boolean): boolean;
var
   BX: Integer;
   BC, LC: TColor;
begin
   Result := False;
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 1;
      Exit;
   end;
   BX := FCX + EDIT_W - 50;
   if AValue then
   begin
      BC := ColorCreate(60, 200, 80, 255);
      LC := ColorCreate(60, 200, 80, 255);
   end
   else
   begin
      BC := ColorCreate(80, 80, 80, 255);
      LC := ColorCreate(160, 160, 160, 255);
   end;
   DrawText(PChar(ALabel), FCX, FCY + 4, 10, LC);
   DrawRectangle(BX, FCY, 44, ROW_H - 1, BC);
   if AValue then
      DrawText(PChar('ON'), BX + 10, FCY + 4, 10, ColorCreate(20, 20, 20, 255))
   else
      DrawText(PChar('OFF'), BX + 6, FCY + 4, 10, ColorCreate(20, 20, 20, 255));
   if Clicked(BX, FCY, 44, ROW_H) then
   begin
      AValue := not AValue;
      Result := True;
   end;
   FCY := FCY + ROW_H + 1;
end;

procedure TGenEditor.DrawBiomeTabs;
var
   TW, TX1, TX2, TX3: Integer;
   C1, C2, C3: TColor;
begin
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 2;
      Exit;
   end;
   TW := (EDIT_W - 8) div 3;
   TX1 := FCX;
   TX2 := FCX + TW + 2;
   TX3 := FCX + (TW + 2) * 2;
   if FBiomeTab = btPlains then
      C1 := COL_PLAINS
   else
      C1 := ColorCreate(40, 60, 40, 255);
   if FBiomeTab = btDesert then
      C2 := COL_DESERT
   else
      C2 := ColorCreate(60, 50, 20, 255);
   if FBiomeTab = btForest then
      C3 := COL_FOREST
   else
      C3 := ColorCreate(20, 50, 30, 255);
   DrawRectangle(TX1, FCY, TW, ROW_H - 1, C1);
   DrawText(PChar('Plains'), TX1 + TW div 2 - MeasureText('Plains', 10) div 2, FCY + 4, 10, ColorCreate(220, 220, 220, 255));
   DrawRectangle(TX2, FCY, TW, ROW_H - 1, C2);
   DrawText(PChar('Desert'), TX2 + TW div 2 - MeasureText('Desert', 10) div 2, FCY + 4, 10, ColorCreate(220, 220, 220, 255));
   DrawRectangle(TX3, FCY, TW, ROW_H - 1, C3);
   DrawText(PChar('Forest'), TX3 + TW div 2 - MeasureText('Forest', 10) div 2, FCY + 4, 10, ColorCreate(220, 220, 220, 255));
   if Clicked(TX1, FCY, TW, ROW_H) then
      FBiomeTab := btPlains;
   if Clicked(TX2, FCY, TW, ROW_H) then
      FBiomeTab := btDesert;
   if Clicked(TX3, FCY, TW, ROW_H) then
      FBiomeTab := btForest;
   FCY := FCY + ROW_H + 2;
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

procedure TGenEditor.HandleFileNameInput;
var
   C: Integer;
begin
   if IsKeyPressed(KEY_BACKSPACE) and (Length(FFileName) > 0) then
      Delete(FFileName, Length(FFileName), 1);
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

procedure TGenEditor.Update(ADelta: Single);
var
   PhysW, PhysH: Integer;
   Sc, OX, OY: Single;
begin
   FRegeneratePressed := False;
   FResetPressed := False;
   FLoadPressed := False;
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

procedure TGenEditor.Draw;
var
   P: PGenParams;
   L: PLightSettings;
   B: PBiomeParams;
   HW, BLY, ContentH, MaxScroll, ThumbH, ThumbY, ScrollBarH: Integer;
   FinalCY: Integer;
   VisibleFrac: Single;
   BoxBlink: TColor;
   ShortFN: string;
begin
   P := FParams;
   L := FLighting;
   DrawRectangle(FPX, FPY, EDIT_W, EDIT_H, COL_BG);
   DrawRectangleLinesEx(RectangleCreate(FPX, FPY, EDIT_W, EDIT_H), 1, ColorCreate(80, 80, 120, 255));
   BeginDraw;

   FRegeneratePressed := DrawButton('REGENERATE WORLD', COL_REG) or FRegeneratePressed;
   FResetPressed := DrawButton('Reset to Defaults', COL_RST) or FResetPressed;
   SkipRow;

   DrawSectionHeader('Surface Shape', FSections.Surface, COL_SEC_SURF);
   if FSections.Surface then
   begin
      DrawIntSlider('Base Surface Y', P^.BaseSurface, 10, 120, 1);
      DrawIntSlider('Surface Amplitude', P^.SurfaceAmp, 2, 40, 1);
      DrawIntSlider('Min Surface', P^.MinSurface, 5, 60, 1);
      DrawIntSlider('Max Surface', P^.MaxSurface, 40, 200, 1);
      DrawFloatSlider('Frequency', P^.SurfaceFreq, 0.005, 0.1, 0.002, 3);
      DrawIntSlider('Octaves', P^.SurfaceOctaves, 1, 6, 1);
      DrawFloatSlider('Lacunarity', P^.SurfaceLacun, 1.5, 3.0, 0.1, 2);
      DrawFloatSlider('Gain', P^.SurfaceGain, 0.2, 0.8, 0.05, 2);
      SkipRow;
   end;

   DrawSectionHeader('Depth Zones', FSections.Depth, COL_SEC_DEPTH);
   if FSections.Depth then
   begin
      DrawIntSlider('Dirt Depth', P^.DepthDirt, 2, 20, 1);
      DrawIntSlider('Dirt+Stone Trans', P^.DepthDirtStone, 10, 60, 1);
      DrawIntSlider('Stone Depth', P^.DepthStone, 50, 200, 2);
      DrawIntSlider('Sandstone Extra', P^.SandstoneExtra, 0, 10, 1);
      DrawIntSlider('Bedrock Rows', P^.BedrockRows, 1, 6, 1);
      SkipRow;
   end;

   DrawSectionHeader('Cave System', FSections.Caves, COL_SEC_CAVE);
   if FSections.Caves then
   begin
      DrawToggle('Caves Enabled', P^.CavesEnabled);
      DrawIntSlider('Cave Start Depth', P^.CaveStartDepth, 0, 20, 1);
      DrawFloatSlider('Threshold', P^.CaveThreshold, 0.04, 0.4, 0.01, 2);
      DrawFloatSlider('Freq X', P^.CaveFreqX, 0.02, 0.2, 0.01, 3);
      DrawFloatSlider('Freq Y', P^.CaveFreqY, 0.02, 0.2, 0.01, 3);
      DrawIntSlider('Octaves', P^.CaveOctaves, 1, 5, 1);
      SkipRow;
   end;

   DrawSectionHeader('Ore Veins', FSections.Veins, COL_SEC_VEIN);
   if FSections.Veins then
   begin
      DrawFloatSlider('Granite Thresh', P^.GraniteThreshold, 0.1, 0.9, 0.05, 2);
      DrawFloatSlider('Granite Freq', P^.GraniteFreq, 0.02, 0.3, 0.01, 3);
      DrawFloatSlider('Marble Thresh', P^.MarbleThreshold, 0.1, 0.9, 0.05, 2);
      DrawFloatSlider('Marble Freq', P^.MarbleFreq, 0.02, 0.3, 0.01, 3);
      DrawFloatSlider('Clay Thresh', P^.ClayThreshold, 0.1, 0.9, 0.05, 2);
      DrawFloatSlider('Gravel Thresh', P^.GravelThreshold, 0.1, 0.9, 0.05, 2);
      SkipRow;
   end;

   DrawSectionHeader('Biomes', FSections.Biomes, COL_SEC_BIOME);
   if FSections.Biomes then
   begin
      DrawFloatSlider('Biome Freq', P^.BiomeFreq, 0.002, 0.05, 0.001, 3);
      DrawIntSlider('Biome Octaves', P^.BiomeOctaves, 1, 4, 1);
      DrawFloatSlider('Desert Thresh', P^.DesertThreshold, 0.1, 0.6, 0.05, 2);
      DrawFloatSlider('Forest Thresh', P^.ForestThreshold, 0.3, 0.9, 0.05, 2);
      SkipRow;
      DrawBiomeTabs;
      B := CurrentBiome;
      DrawIntSlider('Surface Offset Y', B^.SurfaceOffsetY, -20, 20, 1);
      DrawFloatSlider('Amp Bonus', B^.SurfaceAmpBonus, 0, 20, 0.5, 1);
      DrawIntSlider('Dirt Override', B^.DepthDirtOverride, 0, 20, 1);
      DrawIntSlider('D+S Override', B^.DepthDirtStoneOverride, 0, 60, 1);
      DrawIntSlider('Sandstone Depth', B^.SandstoneDepth, 0, 10, 1);
      DrawFloatSlider('Granite Thr', B^.GraniteThreshold, 0, 0.9, 0.05, 2);
      DrawFloatSlider('Marble Thr', B^.MarbleThreshold, 0, 0.9, 0.05, 2);
      DrawFloatSlider('Clay Thr', B^.ClayThreshold, 0, 0.9, 0.05, 2);
      DrawFloatSlider('Gravel Thr', B^.GravelThreshold, 0, 0.9, 0.05, 2);
      DrawFloatSlider('Cave Density', B^.CaveDensityMult, 0.1, 3.0, 0.1, 2);
      SkipRow;
   end;

   DrawSectionHeader('Deep Zone', FSections.Deep, COL_SEC_DEEP);
   if FSections.Deep then
   begin
      DrawFloatSlider('Granite Ratio', P^.DeepGraniteRatio, 0.0, 1.0, 0.05, 2);
      SkipRow;
   end;

   DrawSectionHeader('Vegetation', FSections.Vegetation, COL_SEC_VEG);
   if FSections.Vegetation then
   begin
      DrawText(PChar('-- Plains --'), FCX, FCY + 4, 10, COL_PLAINS);
      FCY := FCY + ROW_H;
      DrawToggle('Trees', P^.VegPlains.TreeEnabled);
      DrawFloatSlider('Tree Density', P^.VegPlains.TreeDensity, 0.0, 1.0, 0.05, 2);
      DrawIntSlider('Min Height', P^.VegPlains.TreeMinHeight, 2, 8, 1);
      DrawIntSlider('Max Height', P^.VegPlains.TreeMaxHeight, 4, 16, 1);
      DrawIntSlider('Canopy Radius', P^.VegPlains.TreeCanopyRadius, 2, 8, 1);
      DrawIntSlider('Canopy Height', P^.VegPlains.TreeCanopyHeight, 1, 6, 1);
      DrawToggle('Shrubs', P^.VegPlains.ShrubEnabled);
      DrawFloatSlider('Shrub Density', P^.VegPlains.ShrubDensity, 0.0, 1.0, 0.05, 2);
      SkipRow;
      DrawText(PChar('-- Desert --'), FCX, FCY + 4, 10, COL_DESERT);
      FCY := FCY + ROW_H;
      DrawToggle('Cacti', P^.VegDesert.CactusEnabled);
      DrawFloatSlider('Cactus Density', P^.VegDesert.CactusDensity, 0.0, 1.0, 0.05, 2);
      DrawIntSlider('Min Height', P^.VegDesert.CactusMinHeight, 2, 6, 1);
      DrawIntSlider('Max Height', P^.VegDesert.CactusMaxHeight, 4, 12, 1);
      DrawFloatSlider('Arm Chance', P^.VegDesert.CactusArmChance, 0.0, 1.0, 0.05, 2);
      SkipRow;
      DrawText(PChar('-- Forest --'), FCX, FCY + 4, 10, COL_FOREST);
      FCY := FCY + ROW_H;
      DrawToggle('Trees', P^.VegForest.TreeEnabled);
      DrawFloatSlider('Tree Density', P^.VegForest.TreeDensity, 0.0, 1.0, 0.05, 2);
      DrawIntSlider('Min Height', P^.VegForest.TreeMinHeight, 2, 10, 1);
      DrawIntSlider('Max Height', P^.VegForest.TreeMaxHeight, 6, 20, 1);
      DrawIntSlider('Canopy Radius', P^.VegForest.TreeCanopyRadius, 3, 10, 1);
      DrawIntSlider('Canopy Height', P^.VegForest.TreeCanopyHeight, 2, 8, 1);
      DrawToggle('Shrubs', P^.VegForest.ShrubEnabled);
      DrawFloatSlider('Shrub Density', P^.VegForest.ShrubDensity, 0.0, 1.0, 0.05, 2);
      SkipRow;
   end;

   DrawSectionHeader('Cave Decor', FSections.CaveDecor, COL_SEC_CDEC);
   if FSections.CaveDecor then
   begin
      DrawToggle('Roots', P^.CaveDecor.RootsEnabled);
      DrawFloatSlider('Root Density', P^.CaveDecor.RootsDensity, 0.0, 1.0, 0.05, 2);
      DrawIntSlider('Root Min Len', P^.CaveDecor.RootsMinLen, 1, 6, 1);
      DrawIntSlider('Root Max Len', P^.CaveDecor.RootsMaxLen, 2, 12, 1);
      DrawToggle('Vines', P^.CaveDecor.VinesEnabled);
      DrawFloatSlider('Vine Density', P^.CaveDecor.VinesDensity, 0.0, 1.0, 0.05, 2);
      DrawIntSlider('Vine Min Len', P^.CaveDecor.VinesMinLen, 1, 6, 1);
      DrawIntSlider('Vine Max Len', P^.CaveDecor.VinesMaxLen, 3, 16, 1);
      DrawToggle('Stalactites', P^.CaveDecor.StalEnabled);
      DrawFloatSlider('Stal Density', P^.CaveDecor.StalDensity, 0.0, 1.0, 0.05, 2);
      DrawIntSlider('Stal Min Len', P^.CaveDecor.StalMinLen, 1, 4, 1);
      DrawIntSlider('Stal Max Len', P^.CaveDecor.StalMaxLen, 2, 8, 1);
      DrawToggle('Mushrooms', P^.CaveDecor.MushEnabled);
      DrawFloatSlider('Mush Density', P^.CaveDecor.MushDensity, 0.0, 1.0, 0.05, 2);
      DrawIntSlider('Mush Min Depth', P^.CaveDecor.MushMinDepth, 4, 30, 1);
      DrawToggle('Moss', P^.CaveDecor.MossEnabled);
      DrawFloatSlider('Moss Density', P^.CaveDecor.MossDensity, 0.0, 1.0, 0.05, 2);
      SkipRow;
   end;

   { Lighting section }
   if Assigned(L) then
   begin
      DrawSectionHeader('Lighting', FSections.Lighting, COL_SEC_LIGHT);
      if FSections.Lighting then
      begin
         DrawToggle('Lighting Enabled', L^.Enabled);
         SkipRow;
         DrawText(PChar('-- Sky --'), FCX, FCY + 4, 10, COL_SEC_LIGHT);
         FCY := FCY + ROW_H;
         DrawByteSlider('Sky Red', L^.SkyR, 0, 255);
         DrawByteSlider('Sky Green', L^.SkyG, 0, 255);
         DrawByteSlider('Sky Blue', L^.SkyB, 0, 255);
         DrawByteSlider('Ambient Min', L^.AmbientLight, 0, 60);
         SkipRow;
         DrawText(PChar('-- Falloff --'), FCX, FCY + 4, 10, COL_SEC_LIGHT);
         FCY := FCY + ROW_H;
         DrawByteSlider('Air Falloff', L^.FalloffAir, 1, 60);
         DrawByteSlider('Solid Falloff', L^.FalloffSolid, 8, 255);
         DrawByteSlider('Decor Falloff', L^.FalloffDecor, 1, 80);
         SkipRow;
         DrawText(PChar('-- Mushroom Emitter --'), FCX, FCY + 4, 10, COL_SEC_LIGHT);
         FCY := FCY + ROW_H;
         DrawByteSlider('Brightness', L^.MushroomBrightness, 0, 255);
         DrawByteSlider('Red', L^.MushroomR, 0, 255);
         DrawByteSlider('Green', L^.MushroomG, 0, 255);
         DrawByteSlider('Blue', L^.MushroomB, 0, 255);
         SkipRow;
         DrawToggle('Background Dim', L^.DimBackground);
         DrawFloatSlider('Dim Factor', L^.BackgroundDimFactor, 0.1, 1.0, 0.05, 2);
         SkipRow;
      end;
   end;

   DrawSectionHeader('Save / Load', FSections.SaveLoad, COL_SEC_SAVE);
   if FSections.SaveLoad then
   begin
      if (FCY + ROW_H >= FClipY0) and (FCY <= FClipY1) then
      begin
         DrawRectangle(FCX, FCY, EDIT_W - 8, ROW_H - 1,
            IfThen(FFileNameEdit, ColorCreate(50, 50, 80, 255), ColorCreate(30, 30, 50, 255)));
         ShortFN := FFileName;
         while (Length(ShortFN) > 0) and (MeasureText(PChar(ShortFN), 10) > EDIT_W - 16) do
            ShortFN := Copy(ShortFN, 2, MaxInt);
         if FFileNameEdit then
         begin
            if ((GetTime * 2) - Trunc(GetTime * 2)) < 0.5 then
               BoxBlink := ColorCreate(220, 220, 60, 255)
            else
               BoxBlink := ColorCreate(200, 200, 200, 255);
            DrawText(PChar(ShortFN + '|'), FCX + 4, FCY + 4, 10, BoxBlink);
         end
         else
            DrawText(PChar(ShortFN), FCX + 4, FCY + 4, 10, ColorCreate(200, 200, 200, 255));
         if Clicked(FCX, FCY, EDIT_W - 8, ROW_H) then
            FFileNameEdit := not FFileNameEdit;
         FCY := FCY + ROW_H + 2;
      end;
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
               FLoadPressed := True;
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

   FinalCY := FCY + FScrollY + 8;
   ContentH := FinalCY - FPY;
   MaxScroll := Max(0, ContentH - EDIT_H + 20);
   if FScrollY > MaxScroll then
      FScrollY := MaxScroll;
   if FScrollY < 0 then
      FScrollY := 0;
   if InPanel then
   begin
      ScrollBarH := EDIT_H - 4;
      VisibleFrac := Min(1.0, EDIT_H / Max(1, ContentH));
      ThumbH := Max(20, Round(ScrollBarH * VisibleFrac));
      if MaxScroll > 0 then
         ThumbY := FPY + 2 + Round((ScrollBarH - ThumbH) * (FScrollY / MaxScroll))
      else
         ThumbY := FPY + 2;
      DrawRectangle(FPX + EDIT_W - 6, FPY + 2, 4, ScrollBarH, ColorCreate(50, 50, 70, 200));
      DrawRectangle(FPX + EDIT_W - 6, ThumbY, 4, ThumbH, ColorCreate(120, 120, 180, 220));
      if not FFileNameEdit then
         if GetMouseWheelMove <> 0 then
            FScrollY := Max(0, Min(MaxScroll, FScrollY - Round(GetMouseWheelMove * ROW_H * 3)));
   end;
end;

end.
