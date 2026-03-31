unit Terraria.UI.GenEditor;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math, raylib, Terraria.GenParams, Terraria.Lighting;

type
   TSectionFlags = record
      Surface, Depth, Caves, Veins, Biomes, Deep, SaveLoad, Vegetation, CaveDecor, Lighting: boolean;
   end;
   TBiomeTab = (btPlains, btDesert, btForest);

   TGenEditor = class
   private
      FVX, FVY, FPX, FPY, FScrollY, FHI: Integer;
      FHT, FDelta: Single;
      FParams: PGenParams;
      FLighting: PLightSettings;
      FRegen, FReset, FLoad, FFileEdit, FStatusOK: boolean;
      FSec: TSectionFlags;
      FBTab: TBiomeTab;
      FCX, FCY, FC0, FC1: Integer;
      FFile, FMsg: string;
      procedure BD;
      procedure SR(N: Integer = 1);
      procedure SH(const T: string; var O: boolean; C: TColor);
      function IS2(const L: string; var V: Integer; Lo, Hi, St: Integer): boolean;
      function BS(const L: string; var V: byte; Lo, Hi: byte): boolean;
      function FS(const L: string; var V: Single; Lo, Hi, St: Single; D: Integer = 3): boolean;
      function TG(const L: string; var V: boolean): boolean;
      function BT(const L: string; C: TColor): boolean;
      procedure Tabs;
      function CB: PBiomeParams;
      function CK(X, Y, W, H: Integer): boolean;
      function IP: boolean;
      procedure FI;
   public
      constructor Create(PX, PY: Integer; AP: PGenParams; AL: PLightSettings);
      procedure Update(D: Single);
      procedure Draw;
      property RegeneratePressed: boolean read FRegen;
      property ResetPressed: boolean read FReset;
      property LoadPressed: boolean read FLoad;
      property PX: Integer read FPX write FPX;
      property PY: Integer read FPY write FPY;
      property Params: PGenParams read FParams write FParams;
      property Lighting: PLightSettings read FLighting write FLighting;
   end;

implementation

uses
   P2D.Utils.RayLib;

const
   EW = 260;
   EH = 720;
   RH = 22;
   CBG: TColor = (R: 20; G: 20; B: 28; A: 240);
   CHD: TColor = (R: 30; G: 30; B: 42; A: 255);
   COK: TColor = (R: 80; G: 220; B: 80; A: 255);
   CER: TColor = (R: 220; G: 80; B: 80; A: 255);
   CRG: TColor = (R: 60; G: 180; B: 80; A: 255);
   CRS: TColor = (R: 180; G: 120; B: 40; A: 255);
   CSV: TColor = (R: 60; G: 120; B: 200; A: 255);
   CLD: TColor = (R: 120; G: 60; B: 200; A: 255);
   CPL: TColor = (R: 80; G: 180; B: 80; A: 255);
   CDS: TColor = (R: 210; G: 170; B: 50; A: 255);
   CFO: TColor = (R: 40; G: 140; B: 60; A: 255);
   CSS: TColor = (R: 100; G: 200; B: 100; A: 255);
   CSD: TColor = (R: 160; G: 120; B: 60; A: 255);
   CCV: TColor = (R: 80; G: 80; B: 180; A: 255);
   CVN: TColor = (R: 180; G: 80; B: 180; A: 255);
   CBM: TColor = (R: 60; G: 160; B: 60; A: 255);
   CDP: TColor = (R: 60; G: 60; B: 160; A: 255);
   CSL: TColor = (R: 160; G: 160; B: 60; A: 255);
   CVG: TColor = (R: 80; G: 200; B: 80; A: 255);
   CCD: TColor = (R: 100; G: 80; B: 160; A: 255);
   CLT: TColor = (R: 255; G: 220; B: 80; A: 255);
   { Sub-group label colours for the Cave System section }
   CTU: TColor = (R: 140; G: 160; B: 220; A: 255);  { Tunnels }
   CWP: TColor = (R: 160; G: 140; B: 220; A: 255);  { Domain Warp }
   CCH: TColor = (R: 180; G: 120; B: 220; A: 255);  { Chambers }

constructor TGenEditor.Create(PX, PY: Integer; AP: PGenParams; AL: PLightSettings);
begin
   inherited Create;
   FPX := PX;
   FPY := PY;
   FParams := AP;
   FLighting := AL;
   FScrollY := 0;
   FHT := 0;
   FHI := -1;
   FBTab := btPlains;
   FSec.Surface := True;
   FSec.Depth := True;
   FSec.Caves := True;
   FSec.Veins := False;
   FSec.Biomes := True;
   FSec.Deep := False;
   FSec.SaveLoad := True;
   FSec.Vegetation := True;
   FSec.CaveDecor := True;
   FSec.Lighting := True;
   FFile := 'my_world.tgp';
   FMsg := '';
   FStatusOK := True;
end;

function TGenEditor.CK(X, Y, W, H: Integer): boolean;
begin
   Result := IsMouseButtonPressed(MOUSE_BUTTON_LEFT) and (FVX >= X) and (FVX < X + W) and (FVY >= Y) and (FVY < Y + H);
end;

function TGenEditor.IP: boolean;
begin
   Result := (FVX >= FPX) and (FVX < FPX + EW) and (FVY >= FPY) and (FVY < FPY + EH);
end;

procedure TGenEditor.BD;
begin
   FCX := FPX + 4;
   FCY := FPY + 4 - FScrollY;
   FC0 := FPY;
   FC1 := FPY + EH;
end;

procedure TGenEditor.SR(N: Integer);
begin
   FCY := FCY + RH * N;
end;

procedure TGenEditor.SH(const T: string; var O: boolean; C: TColor);
var
   A: string;
begin
   if (FCY + RH < FC0) or (FCY > FC1) then
   begin
      FCY := FCY + RH + 2;
      Exit;
   end;
   DrawRectangle(FPX, FCY, EW, RH, CHD);
   DrawLine(FPX, FCY + RH - 1, FPX + EW, FCY + RH - 1, C);
   if O then
      A := 'v '
   else
      A := '> ';
   DrawText(PChar(A + T), FCX, FCY + 4, 12, C);
   if CK(FPX, FCY, EW, RH) then
      O := not O;
   FCY := FCY + RH + 2;
end;

function TGenEditor.BT(const L: string; C: TColor): boolean;
var
   BW: Integer;
begin
   Result := False;
   if (FCY + RH < FC0) or (FCY > FC1) then
   begin
      FCY := FCY + RH + 1;
      Exit;
   end;
   BW := EW - 8;
   DrawRectangle(FCX, FCY, BW, RH - 1, C);
   DrawRectangleLinesEx(RectangleCreate(FCX, FCY, BW, RH - 1), 1, ColorCreate(255, 255, 255, 40));
   DrawText(PChar(L), FCX + BW div 2 - Round(MeasureText(PChar(L), 11) * 0.5), FCY + 4, 11, ColorCreate(20, 20, 20, 255));
   if CK(FCX, FCY, BW, RH) then
      Result := True;
   FCY := FCY + RH + 2;
end;

function TGenEditor.IS2(const L: string; var V: Integer; Lo, Hi, St: Integer): boolean;
var
   LW, VX, BW, OV: Integer;
begin
   Result := False;
   if (FCY + RH < FC0) or (FCY > FC1) then
   begin
      FCY := FCY + RH + 1;
      Exit;
   end;
   OV := V;
   LW := 130;
   BW := 22;
   VX := FCX + LW + BW + 2;
   DrawText(PChar(L), FCX, FCY + 4, 10, ColorCreate(200, 200, 200, 255));
   DrawRectangle(FCX + LW, FCY, BW, RH - 1, ColorCreate(50, 50, 70, 255));
   DrawText(PChar('-'), FCX + LW + BW div 2 - 3, FCY + 4, 11, ColorCreate(220, 220, 220, 255));
   if CK(FCX + LW, FCY, BW, RH) then
      V := Max(Lo, V - St);
   DrawRectangle(VX, FCY, 44, RH - 1, ColorCreate(35, 35, 50, 255));
   DrawText(PChar(IntToStr(V)), VX + 22 - MeasureText(PChar(IntToStr(V)), 10) div 2, FCY + 4, 10, ColorCreate(240, 240, 100, 255));
   DrawRectangle(VX + 46, FCY, BW, RH - 1, ColorCreate(50, 50, 70, 255));
   DrawText(PChar('+'), VX + 46 + BW div 2 - 3, FCY + 4, 11, ColorCreate(220, 220, 220, 255));
   if CK(VX + 46, FCY, BW, RH) then
      V := Min(Hi, V + St);
   Result := V <> OV;
   FCY := FCY + RH + 1;
end;

function TGenEditor.BS(const L: string; var V: byte; Lo, Hi: byte): boolean;
var
   T: Integer;
begin
   T := V;
   Result := IS2(L, T, Lo, Hi, 1);
   V := byte(T);
end;

function TGenEditor.FS(const L: string; var V: Single; Lo, Hi, St: Single; D: Integer): boolean;
var
   LW, VX, BW: Integer;
   OV: Single;
   Fm, VS: string;
begin
   Result := False;
   if (FCY + RH < FC0) or (FCY > FC1) then
   begin
      FCY := FCY + RH + 1;
      Exit;
   end;
   OV := V;
   LW := 130;
   BW := 22;
   VX := FCX + LW + BW + 2;
   DrawText(PChar(L), FCX, FCY + 4, 10, ColorCreate(200, 200, 200, 255));
   DrawRectangle(FCX + LW, FCY, BW, RH - 1, ColorCreate(50, 50, 70, 255));
   DrawText(PChar('-'), FCX + LW + BW div 2 - 3, FCY + 4, 11, ColorCreate(220, 220, 220, 255));
   if CK(FCX + LW, FCY, BW, RH) then
      V := Max(Lo, V - St);
   DrawRectangle(VX, FCY, 44, RH - 1, ColorCreate(35, 35, 50, 255));
   Fm := '%.' + IntToStr(D) + 'f';
   VS := Format(Fm, [V]);
   DrawText(PChar(VS), VX + 22 - MeasureText(PChar(VS), 10) div 2, FCY + 4, 10, ColorCreate(240, 240, 100, 255));
   DrawRectangle(VX + 46, FCY, BW, RH - 1, ColorCreate(50, 50, 70, 255));
   DrawText(PChar('+'), VX + 46 + BW div 2 - 3, FCY + 4, 11, ColorCreate(220, 220, 220, 255));
   if CK(VX + 46, FCY, BW, RH) then
      V := Min(Hi, V + St);
   Result := V <> OV;
   FCY := FCY + RH + 1;
end;

function TGenEditor.TG(const L: string; var V: boolean): boolean;
var
   BX: Integer;
   BC, LC: TColor;
begin
   Result := False;
   if (FCY + RH < FC0) or (FCY > FC1) then
   begin
      FCY := FCY + RH + 1;
      Exit;
   end;
   BX := FCX + EW - 50;
   if V then
   begin
      BC := ColorCreate(60, 200, 80, 255);
      LC := ColorCreate(60, 200, 80, 255);
   end
   else
   begin
      BC := ColorCreate(80, 80, 80, 255);
      LC := ColorCreate(160, 160, 160, 255);
   end;
   DrawText(PChar(L), FCX, FCY + 4, 10, LC);
   DrawRectangle(BX, FCY, 44, RH - 1, BC);
   if V then
      DrawText(PChar('ON'), BX + 10, FCY + 4, 10, ColorCreate(20, 20, 20, 255))
   else
      DrawText(PChar('OFF'), BX + 6, FCY + 4, 10, ColorCreate(20, 20, 20, 255));
   if CK(BX, FCY, 44, RH) then
   begin
      V := not V;
      Result := True;
   end;
   FCY := FCY + RH + 1;
end;

procedure TGenEditor.Tabs;
var
   TW, X1, X2, X3: Integer;
   C1, C2, C3: TColor;
begin
   if (FCY + RH < FC0) or (FCY > FC1) then
   begin
      FCY := FCY + RH + 2;
      Exit;
   end;
   TW := (EW - 8) div 3;
   X1 := FCX;
   X2 := FCX + TW + 2;
   X3 := FCX + (TW + 2) * 2;
   if FBTab = btPlains then
      C1 := CPL
   else
      C1 := ColorCreate(40, 60, 40, 255);
   if FBTab = btDesert then
      C2 := CDS
   else
      C2 := ColorCreate(60, 50, 20, 255);
   if FBTab = btForest then
      C3 := CFO
   else
      C3 := ColorCreate(20, 50, 30, 255);
   DrawRectangle(X1, FCY, TW, RH - 1, C1);
   DrawText(PChar('Plains'), X1 + TW div 2 - MeasureText('Plains', 10) div 2, FCY + 4, 10, ColorCreate(220, 220, 220, 255));
   DrawRectangle(X2, FCY, TW, RH - 1, C2);
   DrawText(PChar('Desert'), X2 + TW div 2 - MeasureText('Desert', 10) div 2, FCY + 4, 10, ColorCreate(220, 220, 220, 255));
   DrawRectangle(X3, FCY, TW, RH - 1, C3);
   DrawText(PChar('Forest'), X3 + TW div 2 - MeasureText('Forest', 10) div 2, FCY + 4, 10, ColorCreate(220, 220, 220, 255));
   if CK(X1, FCY, TW, RH) then
      FBTab := btPlains;
   if CK(X2, FCY, TW, RH) then
      FBTab := btDesert;
   if CK(X3, FCY, TW, RH) then
      FBTab := btForest;
   FCY := FCY + RH + 2;
end;

function TGenEditor.CB: PBiomeParams;
begin
   case FBTab of
      btDesert:
         Result := @FParams^.BiomeDesert;
      btForest:
         Result := @FParams^.BiomeForest;
      else
         Result := @FParams^.BiomePlains;
   end;
end;

procedure TGenEditor.FI;
var
   C: Integer;
begin
   if IsKeyPressed(KEY_BACKSPACE) and (Length(FFile) > 0) then
      Delete(FFile, Length(FFile), 1);
   if IsKeyPressed(KEY_ENTER) or IsKeyPressed(KEY_ESCAPE) then
      FFileEdit := False;
   C := GetCharPressed;
   while C > 0 do
   begin
      if (C >= 32) and (C < 127) and (Length(FFile) < 60) then
         FFile := FFile + Chr(C);
      C := GetCharPressed;
   end;
end;

procedure TGenEditor.Update(D: Single);
var
   PW, PH: Integer;
   Sc, OX, OY: Single;
begin
   FRegen := False;
   FReset := False;
   FLoad := False;
   FDelta := D;
   PW := GetScreenWidth;
   PH := GetScreenHeight;
   if (PW > 0) and (PH > 0) then
   begin
      Sc := Min(PW / 1280.0, PH / 720.0);
      OX := (PW - 1280 * Sc) * 0.5;
      OY := (PH - 720 * Sc) * 0.5;
      FVX := Round((GetMouseX - OX) / Sc);
      FVY := Round((GetMouseY - OY) / Sc);
   end
   else
   begin
      FVX := GetMouseX;
      FVY := GetMouseY;
   end;
   if IsMouseButtonDown(MOUSE_BUTTON_LEFT) and (FHI >= 0) then
      FHT := FHT + D
   else
   begin
      FHT := 0;
      FHI := -1;
   end;
   if FFileEdit then
      FI;
end;

procedure TGenEditor.Draw;
var
   P: PGenParams;
   L: PLightSettings;
   B: PBiomeParams;
   HW, BLY, CH, MS, ThH, ThY, SBH: Integer;
   FCY2: Integer;
   VF: Single;
   BB: TColor;
   SFN: string;
begin
   P := FParams;
   L := FLighting;
   DrawRectangle(FPX, FPY, EW, EH, CBG);
   DrawRectangleLinesEx(RectangleCreate(FPX, FPY, EW, EH), 1, ColorCreate(80, 80, 120, 255));
   BD;
   FRegen := BT('REGENERATE WORLD', CRG) or FRegen;
   FReset := BT('Reset to Defaults', CRS) or FReset;
   SR;
   { Surface Shape }
   SH('Surface Shape', FSec.Surface, CSS);
   if FSec.Surface then
   begin
      IS2('Base Surface Y', P^.BaseSurface, 10, 120, 1);
      IS2('Surface Amplitude', P^.SurfaceAmp, 2, 40, 1);
      IS2('Min Surface', P^.MinSurface, 5, 60, 1);
      IS2('Max Surface', P^.MaxSurface, 40, 200, 1);
      FS('Frequency', P^.SurfaceFreq, 0.005, 0.1, 0.002, 3);
      IS2('Octaves', P^.SurfaceOctaves, 1, 6, 1);
      FS('Lacunarity', P^.SurfaceLacun, 1.5, 3.0, 0.1, 2);
      FS('Gain', P^.SurfaceGain, 0.2, 0.8, 0.05, 2);
      SR;
   end;
   { Depth Zones }
   SH('Depth Zones', FSec.Depth, CSD);
   if FSec.Depth then
   begin
      IS2('Dirt Depth', P^.DepthDirt, 2, 20, 1);
      IS2('Dirt+Stone Trans', P^.DepthDirtStone, 10, 60, 1);
      IS2('Stone Depth', P^.DepthStone, 50, 200, 2);
      IS2('Sandstone Extra', P^.SandstoneExtra, 0, 10, 1);
      IS2('Bedrock Rows', P^.BedrockRows, 1, 6, 1);
      SR;
   end;
   { Cave System — three sub-groups with colour-coded labels }
   SH('Cave System', FSec.Caves, CCV);
   if FSec.Caves then
   begin
      TG('Caves Enabled', P^.CavesEnabled);
      IS2('Cave Start Depth', P^.CaveStartDepth, 0, 20, 1);
      FS('Freq X', P^.CaveFreqX, 0.02, 0.2, 0.005, 3);
      FS('Freq Y', P^.CaveFreqY, 0.02, 0.2, 0.005, 3);
      IS2('Octaves', P^.CaveOctaves, 1, 6, 1);
      SR;
      DrawText(PChar('-- Tunnels --'), FCX, FCY + 4, 10, CTU);
      FCY := FCY + RH;
      FS('Surf. Threshold', P^.CaveThreshold, 0.01, 0.40, 0.01, 2);
      FS('Deep Threshold', P^.CaveThresholdDeep, 0.01, 0.45, 0.01, 2);
      SR;
      DrawText(PChar('-- Domain Warp --'), FCX, FCY + 4, 10, CWP);
      FCY := FCY + RH;
      FS('Warp Strength', P^.CaveWarpStrength, 0, 60, 2.0, 1);
      FS('Warp Frequency', P^.CaveWarpFreq, 0.005, 0.05, 0.002, 3);
      SR;
      DrawText(PChar('-- Chambers --'), FCX, FCY + 4, 10, CCH);
      FCY := FCY + RH;
      TG('Chambers Enabled', P^.ChamberEnabled);
      FS('Chamber Freq', P^.ChamberFreq, 0.005, 0.04, 0.002, 3);
      IS2('Chamber Octaves', P^.ChamberOctaves, 1, 4, 1);
      FS('Chamber Thresh', P^.ChamberThreshold, 0.05, 0.40, 0.01, 2);
      FS('Chamber Warp', P^.ChamberWarpStrength, 0, 80, 4.0, 1);
      SR;
   end;
   { Ore Veins }
   SH('Ore Veins', FSec.Veins, CVN);
   if FSec.Veins then
   begin
      FS('Granite Thresh', P^.GraniteThreshold, 0.1, 0.9, 0.05, 2);
      FS('Granite Freq', P^.GraniteFreq, 0.02, 0.3, 0.01, 3);
      FS('Marble Thresh', P^.MarbleThreshold, 0.1, 0.9, 0.05, 2);
      FS('Marble Freq', P^.MarbleFreq, 0.02, 0.3, 0.01, 3);
      FS('Clay Thresh', P^.ClayThreshold, 0.1, 0.9, 0.05, 2);
      FS('Gravel Thresh', P^.GravelThreshold, 0.1, 0.9, 0.05, 2);
      SR;
   end;
   { Biomes }
   SH('Biomes', FSec.Biomes, CBM);
   if FSec.Biomes then
   begin
      FS('Biome Freq', P^.BiomeFreq, 0.002, 0.05, 0.001, 3);
      IS2('Biome Octaves', P^.BiomeOctaves, 1, 4, 1);
      FS('Desert Thresh', P^.DesertThreshold, 0.1, 0.6, 0.05, 2);
      FS('Forest Thresh', P^.ForestThreshold, 0.3, 0.9, 0.05, 2);
      SR;
      Tabs;
      B := CB;
      IS2('Min Width (tiles)', B^.MinBiomeWidth, 16, 2000, 8);
      IS2('Max Width (tiles)', B^.MaxBiomeWidth, 32, 4096, 8);
      SR;
      IS2('Surface Offset Y', B^.SurfaceOffsetY, -20, 20, 1);
      FS('Amp Bonus', B^.SurfaceAmpBonus, 0, 20, 0.5, 1);
      IS2('Dirt Override', B^.DepthDirtOverride, 0, 20, 1);
      IS2('D+S Override', B^.DepthDirtStoneOverride, 0, 60, 1);
      IS2('Sandstone Depth', B^.SandstoneDepth, 0, 10, 1);
      FS('Granite Thr', B^.GraniteThreshold, 0, 0.9, 0.05, 2);
      FS('Marble Thr', B^.MarbleThreshold, 0, 0.9, 0.05, 2);
      FS('Clay Thr', B^.ClayThreshold, 0, 0.9, 0.05, 2);
      FS('Gravel Thr', B^.GravelThreshold, 0, 0.9, 0.05, 2);
      FS('Cave Density', B^.CaveDensityMult, 0.1, 3.0, 0.1, 2);
      SR;
   end;
   { Deep Zone }
   SH('Deep Zone', FSec.Deep, CDP);
   if FSec.Deep then
   begin
      FS('Granite Ratio', P^.DeepGraniteRatio, 0, 1, 0.05, 2);
      SR;
   end;
   { Vegetation }
   SH('Vegetation', FSec.Vegetation, CVG);
   if FSec.Vegetation then
   begin
      DrawText(PChar('-- Plains --'), FCX, FCY + 4, 10, CPL);
      FCY := FCY + RH;
      TG('Trees', P^.VegPlains.TreeEnabled);
      FS('Tree Density', P^.VegPlains.TreeDensity, 0, 1, 0.05, 2);
      IS2('Min Height', P^.VegPlains.TreeMinHeight, 2, 8, 1);
      IS2('Max Height', P^.VegPlains.TreeMaxHeight, 4, 16, 1);
      IS2('Canopy Radius', P^.VegPlains.TreeCanopyRadius, 2, 8, 1);
      IS2('Canopy Height', P^.VegPlains.TreeCanopyHeight, 1, 6, 1);
      TG('Shrubs', P^.VegPlains.ShrubEnabled);
      FS('Shrub Density', P^.VegPlains.ShrubDensity, 0, 1, 0.05, 2);
      SR;
      DrawText(PChar('-- Desert --'), FCX, FCY + 4, 10, CDS);
      FCY := FCY + RH;
      TG('Cacti', P^.VegDesert.CactusEnabled);
      FS('Cactus Density', P^.VegDesert.CactusDensity, 0, 1, 0.05, 2);
      IS2('Min Height', P^.VegDesert.CactusMinHeight, 2, 6, 1);
      IS2('Max Height', P^.VegDesert.CactusMaxHeight, 4, 12, 1);
      FS('Arm Chance', P^.VegDesert.CactusArmChance, 0, 1, 0.05, 2);
      SR;
      DrawText(PChar('-- Forest --'), FCX, FCY + 4, 10, CFO);
      FCY := FCY + RH;
      TG('Trees', P^.VegForest.TreeEnabled);
      FS('Tree Density', P^.VegForest.TreeDensity, 0, 1, 0.05, 2);
      IS2('Min Height', P^.VegForest.TreeMinHeight, 2, 10, 1);
      IS2('Max Height', P^.VegForest.TreeMaxHeight, 6, 20, 1);
      IS2('Canopy Radius', P^.VegForest.TreeCanopyRadius, 3, 10, 1);
      IS2('Canopy Height', P^.VegForest.TreeCanopyHeight, 2, 8, 1);
      TG('Shrubs', P^.VegForest.ShrubEnabled);
      FS('Shrub Density', P^.VegForest.ShrubDensity, 0, 1, 0.05, 2);
      SR;
   end;
   { Cave Decor }
   SH('Cave Decor', FSec.CaveDecor, CCD);
   if FSec.CaveDecor then
   begin
      TG('Roots', P^.CaveDecor.RootsEnabled);
      FS('Root Density', P^.CaveDecor.RootsDensity, 0, 1, 0.05, 2);
      IS2('Root Min Len', P^.CaveDecor.RootsMinLen, 1, 6, 1);
      IS2('Root Max Len', P^.CaveDecor.RootsMaxLen, 2, 12, 1);
      TG('Vines', P^.CaveDecor.VinesEnabled);
      FS('Vine Density', P^.CaveDecor.VinesDensity, 0, 1, 0.05, 2);
      IS2('Vine Min Len', P^.CaveDecor.VinesMinLen, 1, 6, 1);
      IS2('Vine Max Len', P^.CaveDecor.VinesMaxLen, 3, 16, 1);
      TG('Stalactites', P^.CaveDecor.StalEnabled);
      FS('Stal Density', P^.CaveDecor.StalDensity, 0, 1, 0.05, 2);
      IS2('Stal Min Len', P^.CaveDecor.StalMinLen, 1, 4, 1);
      IS2('Stal Max Len', P^.CaveDecor.StalMaxLen, 2, 8, 1);
      TG('Mushrooms', P^.CaveDecor.MushEnabled);
      FS('Mush Density', P^.CaveDecor.MushDensity, 0, 1, 0.05, 2);
      IS2('Mush Min Depth', P^.CaveDecor.MushMinDepth, 4, 30, 1);
      TG('Moss', P^.CaveDecor.MossEnabled);
      FS('Moss Density', P^.CaveDecor.MossDensity, 0, 1, 0.05, 2);
      SR;
   end;
   { Lighting }
   if Assigned(L) then
   begin
      SH('Lighting', FSec.Lighting, CLT);
      if FSec.Lighting then
      begin
         TG('Lighting Enabled', L^.Enabled);
         SR;
         DrawText(PChar('-- Sky --'), FCX, FCY + 4, 10, CLT);
         FCY := FCY + RH;
         BS('Sky Red', L^.SkyR, 0, 255);
         BS('Sky Green', L^.SkyG, 0, 255);
         BS('Sky Blue', L^.SkyB, 0, 255);
         BS('Ambient Min', L^.AmbientLight, 0, 60);
         SR;
         DrawText(PChar('-- Falloff --'), FCX, FCY + 4, 10, CLT);
         FCY := FCY + RH;
         BS('Air Falloff', L^.FalloffAir, 1, 60);
         BS('Solid Falloff', L^.FalloffSolid, 8, 255);
         BS('Decor Falloff', L^.FalloffDecor, 1, 80);
         SR;
         DrawText(PChar('-- Mushroom Emitter --'), FCX, FCY + 4, 10, CLT);
         FCY := FCY + RH;
         BS('Brightness', L^.MushroomBrightness, 0, 255);
         BS('Red', L^.MushroomR, 0, 255);
         BS('Green', L^.MushroomG, 0, 255);
         BS('Blue', L^.MushroomB, 0, 255);
         SR;
         TG('Background Dim', L^.DimBackground);
         FS('Dim Factor', L^.BackgroundDimFactor, 0.1, 1.0, 0.05, 2);
         SR;
      end;
   end;
   { Save / Load }
   SH('Save / Load', FSec.SaveLoad, CSL);
   if FSec.SaveLoad then
   begin
      if (FCY + RH >= FC0) and (FCY <= FC1) then
      begin
         DrawRectangle(FCX, FCY, EW - 8, RH - 1, IfThen(FFileEdit, ColorCreate(50, 50, 80, 255), ColorCreate(30, 30, 50, 255)));
         SFN := FFile;
         while (Length(SFN) > 0) and (MeasureText(PChar(SFN), 10) > EW - 16) do
            SFN := Copy(SFN, 2, MaxInt);
         if FFileEdit then
         begin
            if ((GetTime * 2) - Trunc(GetTime * 2)) < 0.5 then
               BB := ColorCreate(220, 220, 60, 255)
            else
               BB := ColorCreate(200, 200, 200, 255);
            DrawText(PChar(SFN + '|'), FCX + 4, FCY + 4, 10, BB);
         end
         else
            DrawText(PChar(SFN), FCX + 4, FCY + 4, 10, ColorCreate(200, 200, 200, 255));
         if CK(FCX, FCY, EW - 8, RH) then
            FFileEdit := not FFileEdit;
         FCY := FCY + RH + 2;
      end;
      if (FCY + RH >= FC0) and (FCY <= FC1) then
      begin
         HW := (EW - 8) div 2 - 2;
         BLY := FCY;
         DrawRectangle(FCX, BLY, HW, RH - 1, CSV);
         DrawText(PChar('Save'), FCX + HW div 2 - 16, BLY + 4, 11, ColorCreate(20, 20, 20, 255));
         DrawRectangle(FCX + HW + 4, BLY, HW, RH - 1, CLD);
         DrawText(PChar('Load'), FCX + HW + 4 + HW div 2 - 16, BLY + 4, 11, ColorCreate(20, 20, 20, 255));
         if CK(FCX, BLY, HW, RH) then
         begin
            if SaveGenParams(FFile, P^) then
            begin
               FMsg := 'Saved: ' + FFile;
               FStatusOK := True;
            end
            else
            begin
               FMsg := 'Save failed: ' + FFile;
               FStatusOK := False;
            end;
            FFileEdit := False;
         end;
         if CK(FCX + HW + 4, BLY, HW, RH) then
         begin
            if LoadGenParams(FFile, P^) then
            begin
               FMsg := 'Loaded: ' + FFile;
               FStatusOK := True;
               FLoad := True;
            end
            else
            begin
               FMsg := 'Load failed: ' + FFile;
               FStatusOK := False;
            end;
            FFileEdit := False;
         end;
         FCY := FCY + RH + 2;
         if (FMsg <> '') and (FCY <= FC1) then
         begin
            DrawText(PChar(FMsg), FCX, FCY + 4, 9, IfThen(FStatusOK, COK, CER));
            FCY := FCY + 16;
         end;
      end;
   end;
   { Scrollbar }
   FCY2 := FCY + FScrollY + 8;
   CH := FCY2 - FPY;
   MS := Max(0, CH - EH + 20);
   if FScrollY > MS then
      FScrollY := MS;
   if FScrollY < 0 then
      FScrollY := 0;
   if IP then
   begin
      SBH := EH - 4;
      VF := Min(1.0, EH / Max(1, CH));
      ThH := Max(20, Round(SBH * VF));
      if MS > 0 then
         ThY := FPY + 2 + Round((SBH - ThH) * (FScrollY / MS))
      else
         ThY := FPY + 2;
      DrawRectangle(FPX + EW - 6, FPY + 2, 4, SBH, ColorCreate(50, 50, 70, 200));
      DrawRectangle(FPX + EW - 6, ThY, 4, ThH, ColorCreate(120, 120, 180, 220));
      if not FFileEdit then
         if GetMouseWheelMove <> 0 then
            FScrollY := Max(0, Min(MS, FScrollY - Round(GetMouseWheelMove * RH * 3)));
   end;
end;

end.
