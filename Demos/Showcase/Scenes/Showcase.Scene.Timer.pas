unit Showcase.Scene.Timer;

{$mode objfpc}{$H+}

{ Demo 19 - Timer Component (TTimerComponent2D + TTimerSystem2D)
  TTimerSystem2D (prio 1): calls TC.Tick(dt) for each entity.
  Tick decrements Remaining, fires OnFired callback, auto-resets Repeat timers.
  Start(Name, Duration, Repeat, OnFired): register or restart named timer.
  Stop(Name): deactivate (slot stays allocated).
  Progress(Name): [0..1] normalised; 0=just started, 1=expired.
  Remaining(Name): seconds left.
  MAX_TIMERS=8 per component; Start raises exception when full.
  Controls: 1=CoolDown(3s)  2=Regen(1s repeat)  3=Boss(5s)  S=stop all }
interface

uses
   SysUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Timer,
   P2D.Systems.Timer,
   Showcase.Common;

type
   TTimerDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FEntity: TEntity;
      FTimerSys: TTimerSystem2D;
      FTMID: Integer;
      FFireLog: array[0..9] of String;
      FFireN, FTotalFires: Integer;
      procedure OnTimerFired(const AName: String);
      procedure LogFire(const S: String);
      function TC: TTimerComponent2D;
      procedure DrawTimerBar(const AName: String; AX, AY, AW: Integer; ALabel: String);
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AW, AH: Integer);
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Systems.SceneManager;

constructor TTimerDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('Timer');
   FScreenW := AW;
   FScreenH := AH;
   FTotalFires := 0;
end;

function TTimerDemoScene.TC: TTimerComponent2D;
begin
   Result := TTimerComponent2D(FEntity.GetComponentByID(FTMID));
end;

procedure TTimerDemoScene.LogFire(const S: String);
var
   I: Integer;
begin
   Inc(FTotalFires);
   if FFireN < 10 then
   begin
      FFireLog[FFireN] := S;
      Inc(FFireN);
   end
   else
   begin
      for I := 0 to 8 do
         FFireLog[I] := FFireLog[I + 1];
      FFireLog[9] := S;
   end;
end;

procedure TTimerDemoScene.OnTimerFired(const AName: String);
begin
   LogFire(Format('[FIRED] %s  (total=%d)', [AName, FTotalFires + 1]));
end;

procedure TTimerDemoScene.DoLoad;
begin
   FTimerSys := TTimerSystem2D(World.AddSystem(TTimerSystem2D.Create(World)));
end;

procedure TTimerDemoScene.DoEnter;
var
   Tr: TTransformComponent;
   T: TTimerComponent2D;
begin
   FFireN := 0;
   FTotalFires := 0;
   FTMID := ComponentRegistry.GetComponentID(TTimerComponent2D);
   FEntity := World.CreateEntity('TimerEntity');
   Tr := TTransformComponent.Create;
   FEntity.AddComponent(Tr);
   T := TTimerComponent2D.Create;
   { Three timers registered up-front }
   T.Start('CoolDown', 3.0, False, @OnTimerFired);
   T.Start('Regen', 1.0, True, @OnTimerFired);
   T.Start('Boss', 5.0, False, @OnTimerFired);
   FEntity.AddComponent(T);
   World.Init;
   LogFire('Demo started. Timers initialized.');
end;

procedure TTimerDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TTimerDemoScene.DrawTimerBar(const AName: String; AX, AY, AW: Integer; ALabel: String);
var
   T: TTimerComponent2D;
   Prog: Single;
   vActive: boolean;
   FillW: Integer;
   BarCol: TColor;
   RemStr: String;
begin
   T := TC;
   vActive := T.IsActive(AName);
   Prog := T.Progress(AName);
   FillW := Round(AW * Prog);
   BarCol := ColorCreate(Round(255 * Prog), Round(255 * (1 - Prog)), 60, 255);
   if not vActive then
      BarCol := COL_DIMTEXT;
   DrawText(PChar(ALabel), AX, AY - 16, 12, IfThen(vActive, COL_TEXT, COL_DIMTEXT));
   DrawRectangle(AX, AY, AW, 20, ColorCreate(40, 40, 55, 255));
   if FillW > 0 then
      DrawRectangle(AX, AY, FillW, 20, BarCol);
   DrawRectangleLinesEx(RectangleCreate(AX, AY, AW, 20), 1, COL_DIMTEXT);
   if vActive then
      RemStr := Format('%.2f s left (%.0f%%)', [T.Remaining(AName), Prog * 100])
   else
      RemStr := 'STOPPED / EXPIRED';
   DrawText(PChar(RemStr), AX + 6, AY + 4, 11, IfThen(vActive, WHITE, COL_DIMTEXT));
end;

procedure TTimerDemoScene.Update(ADelta: Single);
var
   T: TTimerComponent2D;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   T := TC;
   if IsKeyPressed(KEY_ONE) then
      T.Start('CoolDown', 3.0, False, @OnTimerFired);
   if IsKeyPressed(KEY_TWO) then
      T.Start('Regen', 1.0, True, @OnTimerFired);
   if IsKeyPressed(KEY_THREE) then
      T.Start('Boss', 5.0, False, @OnTimerFired);
   if IsKeyPressed(KEY_S) then
   begin
      T.Stop('CoolDown');
      T.Stop('Regen');
      T.Stop('Boss');
      LogFire('[STOP] All timers stopped.');
   end;
   World.Update(ADelta);
end;

procedure TTimerDemoScene.Render;
const
   BAR_W = 500;
   BX = 80;
var
   I: Integer;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 19 - Timer Component (TTimerComponent2D + TTimerSystem2D)');
   DrawFooter('1=CoolDown(3s)  2=Regen(1s repeat)  3=Boss(5s)  S=stop all');
   DrawPanel(BX - 10, DEMO_AREA_Y + 20, BAR_W + 20, 280, 'Active Timers');
   DrawTimerBar('CoolDown', BX, DEMO_AREA_Y + 60, BAR_W, 'CoolDown  (one-shot, 3.0 s)');
   DrawTimerBar('Regen', BX, DEMO_AREA_Y + 120, BAR_W, 'Regen     (repeating, 1.0 s)');
   DrawTimerBar('Boss', BX, DEMO_AREA_Y + 180, BAR_W, 'Boss      (one-shot, 5.0 s)');
   DrawPanel(BX - 10, DEMO_AREA_Y + 310, BAR_W + 20, 240, 'Event Log (OnFired callbacks)');
   for I := 0 to FFireN - 1 do
      DrawText(PChar(FFireLog[I]), BX, DEMO_AREA_Y + 334 + I * 22, 11,
         IfThen(Pos('[FIRED]', FFireLog[I]) > 0, COL_GOOD, COL_DIMTEXT));
end;

end.
