unit Terraria.UI.GenEditor;

{$mode objfpc}{$H+}

{ TGenEditor — an immediate-mode properties panel for TGenParams.

  LAYOUT
  ──────
  The editor is a fixed-width side panel (right side of the screen) rendered
  entirely with raylib DrawRectangle / DrawText / DrawLine calls.  It supports:

    • Section headers (collapsible)
    • Integer sliders   [◄ value ►] with keyboard fine-tuning
    • Float sliders     [◄ value ►]
    • Toggle buttons    [ON / OFF]
    • Reset-to-default button
    • Regenerate button

  INTERACTION
  ───────────
  Mouse-click on ◄/► arrows nudges the value by one step.
  Click + hold on ◄/► fires auto-repeat after 0.4s.
  The panel is scrollable vertically with the scroll wheel when hovered.

  USAGE (from TWorldScene)
  ─────────────────────────
    FEditor := TGenEditor.Create(X, Y, W, H, @FGenerator.Params);
    ...
    FEditor.Update(ADelta);        { call BEFORE rendering }
    FEditor.Draw;                  { call in screen-space (outside camera) }
    if FEditor.RegeneratePressed then begin ... end; }

interface

uses
   SysUtils, Math, raylib,
   Terraria.GenParams;

const
   EDIT_W = 310;    { panel pixel width   }
   EDIT_H = 680;    { panel pixel height  }
   ROW_H = 22;      { height per row      }
   COL_BG: TColor = (R: 14; G: 14; B: 22; A: 220);
   COL_HDR: TColor = (R: 30; G: 28; B: 42; A: 255);
   COL_TXT: TColor = (R: 200; G: 200; B: 200; A: 255);
   COL_ACC: TColor = (R: 80; G: 180; B: 255; A: 255);
   COL_BTN: TColor = (R: 50; G: 50; B: 70; A: 255);
   COL_ON: TColor = (R: 60; G: 200; B: 80; A: 255);
   COL_OFF: TColor = (R: 200; G: 60; B: 60; A: 255);
   COL_REG: TColor = (R: 255; G: 180; B: 30; A: 255);
   COL_RST: TColor = (R: 100; G: 100; B: 130; A: 255);

type
   { Section visibility flags }
   TSectionFlags = record
      Surface, Depth, Caves, Veins, Biomes, BiomeTweaks, Deep: boolean;
   end;

   TGenEditor = class
   private
      FVMouseX, FVMouseY : Integer;
      FPX, FPY: Integer;    { top-left panel position (screen pixels) }
      FParams: PGenParams;  { pointer to the live params record        }
      FScrollY: Integer;    { vertical scroll offset (pixels)          }
      FRegeneratePressed: Boolean;
      FResetPressed: boolean;
      FSections: TSectionFlags;

      { Auto-repeat state }
      FHeldTimer: Single;
      FHeldItem: Integer;   { encoded: 1000*row + col (0=dec,1=inc) }

      FDelta: Single;

      { Drawing cursor (reset each Draw call) }
      FCX, FCY: Integer;   { current draw cursor }
      FClipY0, FClipY1: Integer;

      { Helpers }
      procedure BeginDraw;
      procedure SkipRow(ACount: Integer = 1);
      procedure DrawSectionHeader(const ATitle: string; var AOpen: Boolean);
      function DrawIntSlider(const ALabel: string; var AValue: Integer; AMin, AMax, AStep: Integer): Boolean;
      function DrawFloatSlider(const ALabel: string; var AValue: Single; AMin, AMax, AStep: Single; ADecimals: Integer = 3): Boolean;
      function DrawToggle(const ALabel: string; var AValue: Boolean): Boolean;
      function DrawButton(const ALabel: string; AColor: TColor): Boolean;
      { Returns true if (MX,MY) is inside (RX,RY,RW,RH) and LMB just pressed }
      function Clicked(RX, RY, RW, RH: Integer): Boolean;
      function InPanel(MX, MY: Integer): Boolean;
   public
      constructor Create(APX, APY: Integer; AParams: PGenParams);

      { Call once per frame with frame delta }
      procedure Update(ADelta: Single);

      { Draw the panel (call in screen space, outside BeginMode2D) }
      procedure Draw;

      { True for one frame after the user clicked "Regenerate" }
      property RegeneratePressed: Boolean read FRegeneratePressed;
      { True for one frame after the user clicked "Reset defaults" }
      property ResetPressed: Boolean read FResetPressed;
      property PX: Integer read FPX write FPX;
      property PY: Integer read FPY write FPY;
      property Params: PGenParams read FParams write FParams;
   end;

implementation

{ ── Constructor ─────────────────────────────────────────────────────────── }

constructor TGenEditor.Create(APX, APY: Integer; AParams: PGenParams);
begin
   inherited Create;
   FPX := APX;
   FPY := APY;
   FParams := AParams;
   FScrollY := 0;
   FHeldTimer := 0;
   FHeldItem := -1;
   FSections.Surface := True;
   FSections.Depth := True;
   FSections.Caves := True;
   FSections.Veins := False;
   FSections.Biomes := True;
   FSections.BiomeTweaks := False;
   FSections.Deep := False;
end;

{ ── Update (auto-repeat, scroll) ────────────────────────────────────────── }

procedure TGenEditor.Update(ADelta: Single);
var
   PhysW, PhysH: Integer;
   Sc, OX, OY : Single;
begin
   FRegeneratePressed := False;
   FResetPressed := False;

   FDelta := ADelta;

   { Convert physical mouse coords to virtual-canvas coords }
   PhysW := GetScreenWidth;
   PhysH := GetScreenHeight;
   if (PhysW > 0) and (PhysH > 0) then
   begin
      Sc := Min(PhysW / 1280.0, PhysH / 720.0);  { letterbox scale }
      OX := (PhysW - 1280.0 * Sc) * 0.5;          { horizontal offset }
      OY := (PhysH - 720.0  * Sc) * 0.5;          { vertical offset   }
      FVMouseX := Round((GetMouseX - OX) / Sc);
      FVMouseY := Round((GetMouseY - OY) / Sc);
   end
   else
   begin
      FVMouseX := GetMouseX;
      FVMouseY := GetMouseY;
   end;

   { Auto-repeat for held arrow buttons (handled in DrawIntSlider/DrawFloatSlider) }
   if IsMouseButtonDown(MOUSE_BUTTON_LEFT) and (FHeldItem >= 0) then
   begin
      FHeldTimer := FHeldTimer + ADelta;
   end
   else
   begin
      FHeldTimer := 0;
      FHeldItem := -1;
   end;
end;

{ ── Internal cursor helpers ─────────────────────────────────────────────── }

function TGenEditor.InPanel(MX, MY: Integer): boolean;
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

function TGenEditor.Clicked(RX, RY, RW, RH: Integer): boolean;
begin
   Result := IsMouseButtonPressed(MOUSE_BUTTON_LEFT) and (FVMouseX >= RX) and (FVMouseX < RX + RW) and (FVMouseY >= RY) and (FVMouseY < RY + RH);
end;

{ ── Drawing primitives (clipped to panel) ───────────────────────────────── }

procedure TGenEditor.DrawSectionHeader(const ATitle: string; var AOpen: boolean);
var
   Arrow: string;
   BtnX, BtnY: Integer;
begin
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 2;
      Exit;
   end;
   DrawRectangle(FPX, FCY, EDIT_W, ROW_H, COL_HDR);
   DrawLine(FPX, FCY + ROW_H - 1, FPX + EDIT_W, FCY + ROW_H - 1, COL_ACC);
   if AOpen then
      Arrow := '▼ '
   else
      Arrow := '▶ ';
   DrawText(PChar(Arrow + ATitle), FCX, FCY + 4, 12, COL_ACC);
   BtnX := FPX;
   BtnY := FCY;
   if Clicked(BtnX, BtnY, EDIT_W, ROW_H) then
      AOpen := not AOpen;
   FCY := FCY + ROW_H + 2;
end;

function TGenEditor.DrawIntSlider(const ALabel: string; var AValue: Integer; AMin, AMax, AStep: Integer): Boolean;
const
   AW = 22;
   VW = 52;
var
   LX, LY, VX: Integer;
   Old: Integer;
   BRep: Boolean;
begin
   Result := False;
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 1;
      Exit;
   end;

   LX := FCX;
   LY := FCY;
   DrawText(PChar(ALabel), LX, LY + 4, 10, COL_TXT);
   VX := FPX + EDIT_W - VW - AW * 2 - 4;

   { ◄ }
   DrawRectangle(VX, LY, AW, ROW_H - 2, COL_BTN);
   DrawText('◄', VX + 5, LY + 4, 10, COL_ACC);
   { Value }
   DrawRectangle(VX + AW, LY, VW, ROW_H - 2, COL_HDR);
   DrawText(PChar(IntToStr(AValue)), VX + AW + 4, LY + 4, 10, COL_TXT);
   { ► }
   DrawRectangle(VX + AW + VW, LY, AW, ROW_H - 2, COL_BTN);
   DrawText('►', VX + AW + VW + 5, LY + 4, 10, COL_ACC);

   Old := AValue;
   if Clicked(VX, LY, AW, ROW_H) then
   begin
      AValue := Max(AMin, AValue - AStep);
      FHeldItem := LY * 1000 + 0;
   end;
   if Clicked(VX + AW + VW, LY, AW, ROW_H) then
   begin
      AValue := Min(AMax, AValue + AStep);
      FHeldItem := LY * 1000 + 1;
   end;

   { Auto-repeat after hold }
   BRep := (FHeldTimer > 0.35) and ((FHeldTimer - FDelta < 0.35) or (Round(FHeldTimer * 12) > Round((FHeldTimer - FDelta) * 12)));

   FCY := FCY + ROW_H + 1;
   Result := AValue <> Old;
end;

function TGenEditor.DrawFloatSlider(const ALabel: string; var AValue: Single; AMin, AMax, AStep: Single; ADecimals: Integer): boolean;
const
   AW = 22;
   VW = 60;
var
   LX, LY, VX: Integer;
   Old: Single;
   Fmt: string;
begin
   Result := False;
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 1;
      Exit;
   end;

   LX := FCX;
   LY := FCY;
   DrawText(PChar(ALabel), LX, LY + 4, 10, COL_TXT);
   VX := FPX + EDIT_W - VW - AW * 2 - 4;

   DrawRectangle(VX, LY, AW, ROW_H - 2, COL_BTN);
   DrawText('◄', VX + 5, LY + 4, 10, COL_ACC);
   DrawRectangle(VX + AW, LY, VW, ROW_H - 2, COL_HDR);
   Fmt := '%.' + IntToStr(ADecimals) + 'f';
   DrawText(PChar(Format(Fmt, [AValue])), VX + AW + 4, LY + 4, 10, COL_TXT);
   DrawRectangle(VX + AW + VW, LY, AW, ROW_H - 2, COL_BTN);
   DrawText('►', VX + AW + VW + 5, LY + 4, 10, COL_ACC);

   Old := AValue;
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
   LX, LY, TX: Integer;
   Old: boolean;
   LblColor: TColor;
begin
   Result := False;
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 1;
      Exit;
   end;
   LX := FCX;
   LY := FCY;
   TX := FPX + EDIT_W - TW - 4;
   Old := AValue;
   DrawText(PChar(ALabel), LX, LY + 4, 10, COL_TXT);
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
   BX, BW: Integer;
begin
   Result := False;
   if (FCY + ROW_H < FClipY0) or (FCY > FClipY1) then
   begin
      FCY := FCY + ROW_H + 1;
      Exit;
   end;
   BX := FCX;
   BW := EDIT_W - 8;
   DrawRectangle(BX, FCY, BW, ROW_H - 1, AColor);
   DrawRectangleLinesEx(RectangleCreate(BX, FCY, BW, ROW_H - 1), 1, ColorCreate(255, 255, 255, 40));
   DrawText(PChar(ALabel), BX + BW div 2 - Round(MeasureText(PChar(ALabel), 11) * 0.5),
      FCY + 4, 11, ColorCreate(20, 20, 20, 255));
   if Clicked(BX, FCY, BW, ROW_H) then
      Result := True;
   FCY := FCY + ROW_H + 2;
end;

{ ── Main Draw ───────────────────────────────────────────────────────────── }

procedure TGenEditor.Draw;
var
   P: PGenParams;
   ContentH, MaxScroll, SBH, SBY: Integer;
begin
   P := FParams;

   { Panel background + title }
   DrawRectangle(FPX, FPY, EDIT_W, EDIT_H, COL_BG);
   DrawRectangleLinesEx(RectangleCreate(FPX, FPY, EDIT_W, EDIT_H), 1, COL_ACC);
   DrawRectangle(FPX, FPY, EDIT_W, 20, COL_HDR);
   DrawText('Generation Properties', FPX + 6, FPY + 4, 12, COL_ACC);

   BeginDraw;
   FCY := FPY + 22 - FScrollY;

   { ── Action buttons ── }
   FRegeneratePressed := DrawButton('▶  REGENERATE WORLD', COL_REG) or FRegeneratePressed;
   FResetPressed := DrawButton('↺  Reset to Defaults', COL_RST) or FResetPressed;
   SkipRow;

   { ── SURFACE ── }
   DrawSectionHeader('SURFACE SHAPE', FSections.Surface);
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

   { ── DEPTH ZONES ── }
   DrawSectionHeader('DEPTH ZONES', FSections.Depth);
   if FSections.Depth then
   begin
      DrawIntSlider('Dirt Depth (rows)', P^.DepthDirt, 2, 20, 1);
      DrawIntSlider('Dirt+Stone Mix Depth', P^.DepthDirtStone, 10, 60, 1);
      DrawIntSlider('Stone Zone End', P^.DepthStone, 30, 150, 5);
      DrawIntSlider('Desert Sandstone Extra', P^.SandstoneExtra, 0, 20, 1);
      SkipRow;
   end;

   { ── CAVES ── }
   DrawSectionHeader('CAVE SYSTEM', FSections.Caves);
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

   { ── VEINS ── }
   DrawSectionHeader('VEINS & POCKETS', FSections.Veins);
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

   { ── BIOMES ── }
   DrawSectionHeader('BIOME DISTRIBUTION', FSections.Biomes);
   if FSections.Biomes then
   begin
      DrawFloatSlider('Map Frequency', P^.BiomeFreq, 0.0005, 0.02, 0.0005, 4);
      DrawIntSlider('FBM Octaves', P^.BiomeOctaves, 1, 4, 1);
      DrawFloatSlider('Desert Threshold', P^.DesertThreshold, 0.05, 0.6, 0.01, 2);
      DrawFloatSlider('Forest Threshold', P^.ForestThreshold, 0.4, 0.95, 0.01, 2);
      SkipRow;
   end;

   { ── BIOME TWEAKS ── }
   DrawSectionHeader('BIOME TWEAKS', FSections.BiomeTweaks);
   if FSections.BiomeTweaks then
   begin
      DrawText('Plains:', FCX, FCY + 3, 10, ColorCreate(56, 200, 90, 255));
      FCY := FCY + ROW_H;
      DrawIntSlider('  Surface Offset Y', P^.BiomePlains.SurfaceOffsetY, -20, 20, 1);
      DrawFloatSlider('  Amplitude Bonus', P^.BiomePlains.SurfaceAmpBonus, -20, 20, 1, 1);
      DrawText('Desert:', FCX, FCY + 3, 10, ColorCreate(196, 174, 112, 255));
      FCY := FCY + ROW_H;
      DrawIntSlider('  Surface Offset Y', P^.BiomeDesert.SurfaceOffsetY, -20, 20, 1);
      DrawFloatSlider('  Amplitude Bonus', P^.BiomeDesert.SurfaceAmpBonus, -20, 20, 1, 1);
      DrawText('Forest:', FCX, FCY + 3, 10, ColorCreate(80, 180, 80, 255));
      FCY := FCY + ROW_H;
      DrawIntSlider('  Surface Offset Y', P^.BiomeForest.SurfaceOffsetY, -20, 20, 1);
      DrawFloatSlider('  Amplitude Bonus', P^.BiomeForest.SurfaceAmpBonus, -20, 20, 1, 1);
      SkipRow;
   end;

   { ── DEEP ZONE ── }
   DrawSectionHeader('DEEP ZONE', FSections.Deep);
   if FSections.Deep then
   begin
      DrawFloatSlider('Granite/Marble Ratio', P^.DeepGraniteRatio, 0.0, 1.0, 0.05, 2);
      DrawIntSlider('Bedrock Rows', P^.BedrockRows, 1, 8, 1);
      SkipRow;
   end;

   { Scroll limit: never let the cursor go above the window content }
   ContentH := FCY + FScrollY - FPY;
   MaxScroll := Max(0, ContentH - EDIT_H + 20);
   if FScrollY > MaxScroll then
      FScrollY := MaxScroll;

   { Scrollbar indicator }
   if MaxScroll > 0 then
   begin
      SBH := Round(EDIT_H * EDIT_H / (ContentH + 1));
      SBY := FPY + Round(FScrollY / MaxScroll * (EDIT_H - SBH));
      DrawRectangle(FPX + EDIT_W - 4, SBY, 3, SBH, ColorCreate(80, 80, 120, 200));
   end;
end;

end.
