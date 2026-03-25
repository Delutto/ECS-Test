unit Showcase.Scene.DayNight;

{$mode objfpc}{$H+}

{ Demo 7 - Day/Night Cycle
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
   World.Init;
   World.EventBus.Subscribe(TDayNightPhaseEvent2D, @OnPhase);
end;

procedure TDayNightDemoScene.DoExit;
begin
   World.EventBus.Unsubscribe(TDayNightPhaseEvent2D, @OnPhase);
   World.ShutdownSystems;
   World.DestroyAllEntities;
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
   I, SX: integer;
   HF: single;
begin
   D := DN;
   ClearBackground(D.CurrentSkyColor);
   DrawRectangle(0, SCR_H - FOOTER_H - 80, SCR_W, 80, ColorCreate(30, 80, 30, 255));
   SX := Round(D.TimeOfDay * SCR_W);
   if (D.TimeOfDay > 0.2) and (D.TimeOfDay < 0.8) then
      DrawCircle(SX, HEADER_H + 80, 28, ColorCreate(255, 230, 80, 240))
   else
      DrawCircle(SX, HEADER_H + 80, 22, ColorCreate(220, 220, 255, 200));
   DrawHeader('Demo 7 - Day and Night Cycle (TDayNightComponent2D)');
   DrawFooter('P=pause   +/-=speed   Click timeline bar to set time');
   DrawPanel(30, DEMO_AREA_Y + 20, 320, 180, 'Clock');
   HF := D.TimeOfDay * 24;
   DrawText(PChar(Format('Time: %02d:%02d', [Trunc(HF), Round((HF - Trunc(HF)) * 60)])), 42, DEMO_AREA_Y + 44, 18, COL_WARN);
   DrawText(PChar('Phase: ' + PN[D.CurrentPhase]), 42, DEMO_AREA_Y + 70, 14, COL_TEXT);
   DrawText(PChar(Format('Ambient: %.2f', [D.AmbientLight])), 42, DEMO_AREA_Y + 90, 13, COL_TEXT);
   DrawText(PChar(Format('Speed x%.0f', [FSpeed])), 42, DEMO_AREA_Y + 110, 12, COL_DIMTEXT);
   if D.Paused then
      DrawText('PAUSED', 42, DEMO_AREA_Y + 130, 16, COL_BAD);
   DrawPanel(380, DEMO_AREA_Y + 20, 400, 180, 'Phase Transitions');
   for I := 0 to FPN - 1 do
      DrawText(PChar(FPLog[I]), 392, DEMO_AREA_Y + 44 + I * 26, 12, COL_TEXT);
   DrawRectangle(40, SCR_H - FOOTER_H - 26, SCR_W - 80, 14, ColorCreate(60, 60, 60, 180));
   DrawRectangle(40, SCR_H - FOOTER_H - 26, Round((SCR_W - 80) * D.TimeOfDay), 14, COL_WARN);
   DrawRectangleLinesEx(RectangleCreate(40, SCR_H - FOOTER_H - 26, SCR_W - 80, 14), 1, COL_DIMTEXT);
   DrawText('0:00', 34, SCR_H - FOOTER_H - 42, 10, COL_DIMTEXT);
   DrawText('24:00', SCR_W - 56, SCR_H - FOOTER_H - 42, 10, COL_DIMTEXT);
end;

end.
