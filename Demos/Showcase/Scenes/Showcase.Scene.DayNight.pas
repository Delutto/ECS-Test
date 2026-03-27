unit Showcase.Scene.DayNight;

{$mode objfpc}{$H+}

{ Demo 7 - Day/Night Cycle
  NEW: procedural sky gradient, star-field, sun/moon sprites,
       mountain/tree-line silhouette, grass+earth ground strip.
  +/-=speed  P=pause  Click timeline bar to set time }
interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Events, P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.Event,
   P2D.Components.DayNight, P2D.Systems.DayNight, Showcase.Common;

type
   TDayNightDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FWorldE: TEntity;
      FDNSys: TDayNightSystem2D;
      FSpeed: single;
      FDNID: integer;
      FPLog: array[0..5] of string;
      FPN: integer;
      { Procedurally generated scene textures }
      FTexSun: TTexture2D;      { 48x48 sun sprite          }
      FTexMoon: TTexture2D;     { 36x36 moon sprite         }
      FTexStars: TTexture2D;    { 512x200 star-field        }
      FTexMtn: TTexture2D;      { 512x160 mountain silhouette }
      FTexTrees: TTexture2D;    { 512x80  tree-line          }
      FTexGround: TTexture2D;   { 256x60  grass + earth      }
      procedure GenSceneTextures;
      procedure FreeSceneTextures;
      procedure OnPhase(AEvent: TEvent2D);
      function DN: TDayNightComponent2D;
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AW, AH: integer);
      procedure Update(ADelta: single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Systems.SceneManager;

constructor TDayNightDemoScene.Create(AW, AH: integer);
begin
   inherited Create('DayNight');
   FScreenW := AW;
   FScreenH := AH;
end;

function TDayNightDemoScene.DN: TDayNightComponent2D;
begin
   Result := TDayNightComponent2D(FWorldE.GetComponentByID(FDNID));
end;

procedure TDayNightDemoScene.GenSceneTextures;
var
   Img: TImage;
   I, X, H: integer;
begin
   { ── 48x48 sun sprite: golden disc with corona }
   Img := GenImageColor(48, 48, ColorCreate(0, 0, 0, 0));
   { outer glow }
   ImageDrawRectangle(@Img, 8, 8, 32, 32, ColorCreate(255, 220, 60, 120));
   ImageDrawRectangle(@Img, 4, 4, 40, 40, ColorCreate(255, 200, 40, 60));
   { main disc }
   ImageDrawRectangle(@Img, 10, 10, 28, 28, ColorCreate(255, 230, 80, 255));
   ImageDrawRectangle(@Img, 12, 12, 24, 24, ColorCreate(255, 245, 120, 255));
   { centre bright spot }
   ImageDrawRectangle(@Img, 18, 18, 12, 12, ColorCreate(255, 255, 200, 255));
   { corona rays (thin rectangles radiating outward) }
   ImageDrawRectangle(@Img, 22, 0, 4, 8, ColorCreate(255, 220, 60, 200));
   ImageDrawRectangle(@Img, 22, 40, 4, 8, ColorCreate(255, 220, 60, 200));
   ImageDrawRectangle(@Img, 0, 22, 8, 4, ColorCreate(255, 220, 60, 200));
   ImageDrawRectangle(@Img, 40, 22, 8, 4, ColorCreate(255, 220, 60, 200));
   ImageDrawRectangle(@Img, 4, 4, 6, 6, ColorCreate(255, 210, 50, 160));
   ImageDrawRectangle(@Img, 38, 4, 6, 6, ColorCreate(255, 210, 50, 160));
   ImageDrawRectangle(@Img, 4, 38, 6, 6, ColorCreate(255, 210, 50, 160));
   ImageDrawRectangle(@Img, 38, 38, 6, 6, ColorCreate(255, 210, 50, 160));
   FTexSun := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { ── 36x36 moon sprite: silver disc with craters }
   Img := GenImageColor(36, 36, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 4, 4, 28, 28, ColorCreate(200, 200, 220, 200));
   ImageDrawRectangle(@Img, 6, 6, 24, 24, ColorCreate(215, 215, 235, 240));
   ImageDrawRectangle(@Img, 8, 8, 20, 20, ColorCreate(225, 225, 245, 255));
   { craters }
   ImageDrawRectangle(@Img, 10, 10, 5, 5, ColorCreate(190, 190, 210, 220));
   ImageDrawRectangle(@Img, 20, 16, 4, 4, ColorCreate(190, 190, 210, 220));
   ImageDrawRectangle(@Img, 14, 20, 4, 4, ColorCreate(190, 190, 210, 220));
   { limb shadow }
   ImageDrawRectangle(@Img, 24, 4, 8, 28, ColorCreate(160, 160, 180, 120));
   FTexMoon := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { ── 512x200 star field }
   Img := GenImageColor(512, 200, ColorCreate(0, 0, 0, 0));
   Randomize;
   for I := 0 to 249 do
   begin
      X := Random(512);
      if Random(8) = 0 then
         ImageDrawRectangle(@Img, X, Random(180), 3, 3, ColorCreate(240 + Random(15), 240 + Random(15), 200 + Random(55), 220))
      else
         ImageDrawRectangle(@Img, X, Random(190), 1, 1, ColorCreate(160 + Random(90), 160 + Random(90), 160 + Random(90), 160 + Random(80)));
   end;
   FTexStars := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { ── 512x160 mountain silhouette }
   Img := GenImageColor(512, 160, ColorCreate(0, 0, 0, 0));
   for X := 0 to 511 do
   begin
      H := Round(60 + 40 * Cos(X * 0.012) + 20 * Sin(X * 0.025) + 15 * Cos(X * 0.055));
      H := Max(10, Min(130, H));
      ImageDrawRectangle(@Img, X, 160 - H, 1, H, ColorCreate(60, 58, 72, 255));
   end;
   { snow caps }
   for X := 0 to 511 do
   begin
      H := Round(60 + 40 * Cos(X * 0.012) + 20 * Sin(X * 0.025) + 15 * Cos(X * 0.055));
      H := Max(10, Min(130, H));
      if H > 90 then
         ImageDrawRectangle(@Img, X, 160 - H, 1, Min(H div 5, 18), ColorCreate(220, 228, 240, 230));
   end;
   FTexMtn := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { ── 512x80 tree-line silhouette }
   Img := GenImageColor(512, 80, ColorCreate(0, 0, 0, 0));
   for X := 0 to 511 do
   begin
      H := Round(36 + 16 * Sin(X * 0.05) + 8 * Cos(X * 0.12) + 6 * Sin(X * 0.25));
      H := Max(12, Min(68, H));
      ImageDrawRectangle(@Img, X, 80 - H, 1, H, ColorCreate(28, 54, 28, 255));
   end;
   FTexTrees := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { ── 256x60 ground strip (grass + earth) }
   Img := GenImageColor(256, 60, ColorCreate(56, 36, 18, 255));
   ImageDrawRectangle(@Img, 0, 0, 256, 16, ColorCreate(40, 110, 32, 255));
   ImageDrawRectangle(@Img, 0, 0, 256, 4, ColorCreate(60, 140, 48, 255));
   for I := 0 to 11 do
      ImageDrawRectangle(@Img, I * 22 + Random(10), 4 + Random(5), 5, Random(5) + 3, ColorCreate(26, 96, 22, 255));
   ImageDrawRectangle(@Img, 0, 22, 256, 2, ColorCreate(44, 28, 14, 255));
   FTexGround := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TDayNightDemoScene.FreeSceneTextures;

   procedure U(var T: TTexture2D);
   begin
      if T.Id > 0 then
      begin
         UnloadTexture(T);
         T.Id := 0;
      end;
   end;

begin
   U(FTexSun);
   U(FTexMoon);
   U(FTexStars);
   U(FTexMtn);
   U(FTexTrees);
   U(FTexGround);
end;

procedure TDayNightDemoScene.OnPhase(AEvent: TEvent2D);
const
   PN: array[0..4] of string = ('Night', 'Dawn', 'Day', 'Dusk', 'Evening');
var
   Ev: TDayNightPhaseEvent2D;
   S: string;
   I: integer;
begin
   Ev := TDayNightPhaseEvent2D(AEvent);
   S := Format('-> %s (t=%.2f)', [PN[Ev.NewPhase mod 5], Ev.TimeOfDay]);
   if FPN < 6 then
   begin
      FPLog[FPN] := S;
      Inc(FPN);
   end
   else
   begin
      for I := 0 to 4 do
         FPLog[I] := FPLog[I + 1];
      FPLog[5] := S;
   end;
end;

procedure TDayNightDemoScene.DoLoad;
begin
   FDNSys := TDayNightSystem2D(World.AddSystem(TDayNightSystem2D.Create(World)));
end;

procedure TDayNightDemoScene.DoEnter;
var
   D: TDayNightComponent2D;
begin
   FSpeed := 60;
   FPN := 0;
   FDNID := ComponentRegistry.GetComponentID(TDayNightComponent2D);
   FWorldE := World.CreateEntity('WorldClock');
   D := TDayNightComponent2D.Create;
   D.TimeOfDay := 0.3;
   D.CycleDuration := 60;
   FWorldE.AddComponent(D);
   GenSceneTextures;
   World.Init;
   World.EventBus.Subscribe(TDayNightPhaseEvent2D, @OnPhase);
end;

procedure TDayNightDemoScene.DoExit;
begin
   World.EventBus.Unsubscribe(TDayNightPhaseEvent2D, @OnPhase);
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FreeSceneTextures;
end;

procedure TDayNightDemoScene.Update(ADelta: single);
var
   D: TDayNightComponent2D;
   MX: integer;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   D := DN;
   if IsKeyPressed(KEY_P) then
      D.Paused := not D.Paused;
   if IsKeyDown(KEY_EQUAL) then
      FSpeed := Min(600, FSpeed + 1);
   if IsKeyDown(KEY_MINUS) then
      FSpeed := Max(1, FSpeed - 1);
   D.CycleDuration := 60 * (60 / FSpeed);
   if IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
   begin
      MX := GetMouseX;
      if (GetMouseY > SCR_H - FOOTER_H - 30) and (GetMouseY < SCR_H - FOOTER_H) then
         D.TimeOfDay := Max(0, Min(1, (MX - 40) / Single(SCR_W - 80)));
   end;
   World.Update(ADelta);
end;

procedure TDayNightDemoScene.Render;
const
   PN: array[TDayPhase2D] of string = ('Night', 'Dawn', 'Day', 'Dusk', 'EveNight');
var
   D: TDayNightComponent2D;
   I, SX, RepW: integer;
   T, NightAlpha, SunAlpha, MoonAlpha: single;
   SkyTop, SkyBot: TColor;
   BodX, BodY: integer;
   HF: single;
begin
   D := DN;
   T := D.TimeOfDay;

  { ── Dynamic sky gradient ────────────────────────────────────────────────
    Phase mapping:  0.0=midnight  0.25=sunrise  0.5=noon  0.75=sunset  1.0=midnight
    We interpolate top/bottom sky colours between key anchor colours. }

   { Night alpha: highest at midnight, zero at noon }
   if T < 0.25 then
      NightAlpha := 1 - T / 0.25
   else
   if T < 0.75 then
      NightAlpha := 0
   else
      NightAlpha := (T - 0.75) / 0.25;

   SunAlpha := Max(0, 1 - Abs(T - 0.5) * 4);   { peaks at noon }
   MoonAlpha := 1 - SunAlpha;                  { inverse }

   { Interpolate sky top colour }
   SkyTop := ColorCreate(Round(8 + (30 - 8) * (1 - NightAlpha) + (80 - 38) * SunAlpha), Round(8 + (90 - 8) * (1 - NightAlpha) + (140 - 98) * SunAlpha), Round(16 + (160 - 16) * (1 - NightAlpha) + (200 - 176) * SunAlpha), 255);
   SkyBot := ColorCreate(Round(20 + (120 - 20) * (1 - NightAlpha) + (200 - 140) * SunAlpha), Round(20 + (160 - 20) * (1 - NightAlpha) + (220 - 180) * SunAlpha), Round(40 + (220 - 40) * (1 - NightAlpha) + (240 - 240) * SunAlpha), 255);

   { Sky gradient }
   DrawRectangleGradientV(0, DEMO_AREA_Y, SCR_W, DEMO_AREA_H - 80, SkyTop, SkyBot);

   { ── Star field — fades with daylight }
   if (NightAlpha > 0.02) and (FTexStars.Id > 0) then
   begin
      RepW := 0;
      while RepW < SCR_W do
      begin
         DrawTexturePro(FTexStars, RectangleCreate(0, 0, 512, 200),
            RectangleCreate(RepW, DEMO_AREA_Y, 512, DEMO_AREA_H div 2),
            Vector2Create(0, 0), 0, ColorCreate(255, 255, 255, Round(NightAlpha * 220)));
         Inc(RepW, 512);
      end;
   end;

   { ── Sun / Moon celestial body }
   SX := Round(T * SCR_W);
   { Sun: visible 0.2..0.8, peaks at noon (0.5) }
   if (T > 0.15) and (T < 0.85) and (FTexSun.Id > 0) then
   begin
      BodX := SX - 24;
      BodY := HEADER_H + 60 + Round(Sin((T - 0.15) / (0.85 - 0.15) * Pi) * (-80));
      DrawTexturePro(FTexSun, RectangleCreate(0, 0, 48, 48),
         RectangleCreate(BodX, BodY, 48, 48), Vector2Create(0, 0), 0,
         ColorCreate(255, 255, 255, Min(255, Round(SunAlpha * 2.0 * 255))));
   end
   else
   if FTexMoon.Id > 0 then
   begin
      { Moon: visible when sun is below horizon }
      BodX := SX - 18;
      if T < 0.5 then
         BodY := HEADER_H + 70 + Round(Sin(T / 0.25 * Pi) * (-60))
      else
         BodY := HEADER_H + 70 + Round(Sin((T - 0.75) / 0.25 * Pi) * (-60));
      DrawTexturePro(FTexMoon, RectangleCreate(0, 0, 36, 36),
         RectangleCreate(BodX, BodY, 36, 36), Vector2Create(0, 0), 0,
         ColorCreate(255, 255, 255, Round(MoonAlpha * 200)));
   end;

   { ── Mountain silhouette (mid distance) }
   if FTexMtn.Id > 0 then
   begin
      RepW := 0;
      while RepW < SCR_W do
      begin
         DrawTexturePro(FTexMtn, RectangleCreate(0, 0, 512, 160),
            RectangleCreate(RepW, SCR_H - FOOTER_H - 220, 512, 160),
            Vector2Create(0, 0), 0,
            ColorCreate(255, 255, 255, Round(180 + NightAlpha * 75)));
         Inc(RepW, 512);
      end;
   end;

   { ── Tree-line silhouette (near distance) }
   if FTexTrees.Id > 0 then
   begin
      RepW := 0;
      while RepW < SCR_W do
      begin
         DrawTexturePro(FTexTrees, RectangleCreate(0, 0, 512, 80),
            RectangleCreate(RepW, SCR_H - FOOTER_H - 150, 512, 80),
            Vector2Create(0, 0), 0,
            ColorCreate(255, 255, 255, Round(200 + NightAlpha * 55)));
         Inc(RepW, 512);
      end;
   end;

   { ── Ground strip }
   if FTexGround.Id > 0 then
   begin
      RepW := 0;
      while RepW < SCR_W do
      begin
         DrawTexturePro(FTexGround, RectangleCreate(0, 0, 256, 60),
            RectangleCreate(RepW, SCR_H - FOOTER_H - 80, 256, 80),
            Vector2Create(0, 0), 0, WHITE);
         Inc(RepW, 256);
      end;
   end
   else
      DrawRectangle(0, SCR_H - FOOTER_H - 80, SCR_W, 80, ColorCreate(30, 80, 30, 255));

   { ── Night-time darkness overlay }
   if NightAlpha > 0 then
      DrawRectangle(0, DEMO_AREA_Y, SCR_W, DEMO_AREA_H,
         ColorCreate(4, 4, 12, Round(NightAlpha * 120)));

   DrawHeader('Demo 7 - Day and Night Cycle (TDayNightComponent2D)');
   DrawFooter('P=pause   +/-=speed   Click timeline bar to set time');

   DrawPanel(30, DEMO_AREA_Y + 20, 320, 180, 'Clock');
   HF := T * 24;
   DrawText(PChar(Format('Time: %02d:%02d', [Trunc(HF), Round((HF - Trunc(HF)) * 60)])),
      42, DEMO_AREA_Y + 44, 18, COL_WARN);
   DrawText(PChar('Phase: ' + PN[D.CurrentPhase]), 42, DEMO_AREA_Y + 70, 14, COL_TEXT);
   DrawText(PChar(Format('Ambient: %.2f', [D.AmbientLight])), 42, DEMO_AREA_Y + 90, 13, COL_TEXT);
   DrawText(PChar(Format('Speed x%.0f', [FSpeed])), 42, DEMO_AREA_Y + 110, 12, COL_DIMTEXT);
   if D.Paused then
      DrawText('PAUSED', 42, DEMO_AREA_Y + 130, 16, COL_BAD);

   DrawPanel(380, DEMO_AREA_Y + 20, 400, 180, 'Phase Transitions');
   for I := 0 to FPN - 1 do
      DrawText(PChar(FPLog[I]), 392, DEMO_AREA_Y + 44 + I * 26, 12, COL_TEXT);

   { ── Timeline bar }
   DrawRectangle(40, SCR_H - FOOTER_H - 26, SCR_W - 80, 14, ColorCreate(60, 60, 60, 180));
   DrawRectangle(40, SCR_H - FOOTER_H - 26, Round((SCR_W - 80) * T), 14, COL_WARN);
   DrawRectangleLinesEx(RectangleCreate(40, SCR_H - FOOTER_H - 26, SCR_W - 80, 14), 1, COL_DIMTEXT);
   DrawText('0:00', 34, SCR_H - FOOTER_H - 42, 10, COL_DIMTEXT);
   DrawText('24:00', SCR_W - 56, SCR_H - FOOTER_H - 42, 10, COL_DIMTEXT);
end;

end.
