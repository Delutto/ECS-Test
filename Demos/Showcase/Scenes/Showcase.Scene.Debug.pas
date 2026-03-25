unit Showcase.Scene.Debug;

{$mode objfpc}{$H+}

{ Demo 26 - Debug Utilities (TDebugDraw + TLogger + P2D.Utils.Math)
  TDebugDraw.Instance (global singleton):
    Enabled, ShowGrid, GridSize, GridColor
    DrawRect, DrawCircle, DrawLine, DrawText, DrawGrid, DrawCross
  TLogger.Instance (global alias Logger):
    Levels: llDebug < llInfo < llWarn < llError
    All messages stored in memory + printed to console (coloured on Windows).
    LogFile set -> llError auto-saves.
  P2D.Utils.Math free functions:
    Lerp(A,B,T), Clamp(V,Lo,Hi) [Single+Integer], Vec2Lerp(A,B,T),
    Vec2Distance(A,B), SignF(V), ApproachF(Cur,Tgt,Step)
  Controls: G=toggle grid  D=toggle TDebugDraw  1-4=log levels  C=clear log  L=move target }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Utils.Debug, P2D.Utils.Logger, P2D.Utils.Math, Showcase.Common;

type
   TDebugDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FLerpT, FLerpDir: Single;
      FApproachCur, FApproachTgt: Single;
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

constructor TDebugDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('Debug');
   FScreenW := AW;
   FScreenH := AH;
end;

procedure TDebugDemoScene.DoLoad;
begin
end;

procedure TDebugDemoScene.DoEnter;
begin
   FLerpT := 0;
   FLerpDir := 1;
   FApproachCur := 50;
   FApproachTgt := 750;
   TDebugDraw.Instance.Enabled := True;
   TDebugDraw.Instance.ShowGrid := False;
   TDebugDraw.Instance.GridSize := 40;
   TDebugDraw.Instance.GridColor := ColorCreate(60, 60, 80, 80);
   Logger.Info('Debug demo entered.');
   Logger.Debug('TDebugDraw and TLogger are singletons.');
   World.Init;
end;

procedure TDebugDemoScene.DoExit;
begin
   TDebugDraw.Instance.ShowGrid := False;
   Logger.Info('Debug demo exited.');
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TDebugDemoScene.Update(ADelta: Single);
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_G) then
      TDebugDraw.Instance.ShowGrid := not TDebugDraw.Instance.ShowGrid;
   if IsKeyPressed(KEY_D) then
      TDebugDraw.Instance.Enabled := not TDebugDraw.Instance.Enabled;
   if IsKeyPressed(KEY_ONE) then
      Logger.Debug('Debug message — verbose detail.');
   if IsKeyPressed(KEY_TWO) then
      Logger.Info('Info message — normal event.');
   if IsKeyPressed(KEY_THREE) then
      Logger.Warn('Warning — something unexpected.');
   if IsKeyPressed(KEY_FOUR) then
      Logger.Error('Error — something went wrong!');
   if IsKeyPressed(KEY_C) then
      Logger.Clear;
   FLerpT := FLerpT + FLerpDir * ADelta * 0.4;
   if FLerpT >= 1 then
   begin
      FLerpT := 1;
      FLerpDir := -1;
   end;
   if FLerpT <= 0 then
   begin
      FLerpT := 0;
      FLerpDir := 1;
   end;
   if IsKeyPressed(KEY_L) then
      FApproachTgt := IfThen(FApproachTgt > 400, 50.0, 750.0);
   FApproachCur := ApproachF(FApproachCur, FApproachTgt, 120 * ADelta);
   World.Update(ADelta);
end;

procedure TDebugDemoScene.Render;
const
   DY = DEMO_AREA_Y + 20;
var
   A, B, Mid: TVector2;
   Dist: Single;
   I: Integer;
   ZV: TVector2;
begin
   ClearBackground(COL_BG);
   if TDebugDraw.Instance.Enabled then
   begin
      ZV.X := 0;
      ZV.Y := 0;
      TDebugDraw.Instance.DrawGrid(ZV);
      TDebugDraw.Instance.DrawRect(RectangleCreate(40, DY, 160, 80), ColorCreate(200, 100, 100, 255));
      TDebugDraw.Instance.DrawCircle(Vector2Create(280, DY + 40), 40, ColorCreate(100, 200, 100, 255));
      TDebugDraw.Instance.DrawLine(Vector2Create(360, DY), Vector2Create(500, DY + 80), ColorCreate(100, 160, 255, 255));
      TDebugDraw.Instance.DrawCross(Vector2Create(580, DY + 40), 40, ColorCreate(255, 200, 60, 255));
      DrawText('DrawRect', 44, DY + 84, 11, COL_DIMTEXT);
      DrawText('DrawCircle', 252, DY + 84, 11, COL_DIMTEXT);
      DrawText('DrawLine', 400, DY + 84, 11, COL_DIMTEXT);
      DrawText('DrawCross', 556, DY + 84, 11, COL_DIMTEXT);
   end
   else
      DrawText('[DEBUG DRAW DISABLED - press D]', 40, DY + 40, 13, COL_BAD);
   DrawPanel(30, DY + 110, SCR_W - 60, 270, 'P2D.Utils.Math Functions');
   A.X := 60;
   A.Y := DY + 160;
   B.X := 600;
   B.Y := DY + 160;
   Mid := Vec2Lerp(A, B, FLerpT);
   DrawLine(Round(A.X), Round(A.Y), Round(B.X), Round(B.Y), COL_DIMTEXT);
   DrawCircle(Round(A.X), Round(A.Y), 5, COL_GOOD);
   DrawCircle(Round(B.X), Round(B.Y), 5, COL_GOOD);
   DrawCircle(Round(Mid.X), Round(Mid.Y), 8, COL_ACCENT);
   DrawText(PChar(Format('Vec2Lerp(A,B,T=%.2f) -> (%.0f,%.0f)', [FLerpT, Mid.X, Mid.Y])), 42, DY + 175, 11, COL_TEXT);
   Dist := Vec2Distance(A, B);
   DrawText(PChar(Format('Vec2Distance(A,B) = %.0f px', [Dist])), 42, DY + 193, 11, COL_DIMTEXT);
   DrawLine(60, DY + 230, 750, DY + 230, COL_DIMTEXT);
   DrawCircle(Round(FApproachTgt), DY + 230, 6, COL_WARN);
   DrawCircle(Round(FApproachCur), DY + 230, 8, COL_ACCENT);
   DrawText(PChar(Format('ApproachF(Cur=%.0f,Tgt=%.0f,Step=120/s)', [FApproachCur, FApproachTgt])), 42, DY + 244, 11, COL_TEXT);
   DrawText('Press L to move target.', 42, DY + 260, 10, COL_DIMTEXT);
   DrawText(PChar(Format('Clamp(%.1f,0,1)=%.1f  SignF(-3.7)=%.0f', [FLerpT * 1.5, Clamp(FLerpT * 1.5, 0.0, 1.0), SignF(-3.7)])), 42, DY + 280, 11, COL_TEXT);
   DrawPanel(30, DY + 390, SCR_W - 60, 100, 'TLogger Status (see console)');
   DrawText(PChar(Format('Log entries: %d', [Logger.GetLogCount])), 42, DY + 414, 12, COL_TEXT);
   DrawText('1=Debug  2=Info  3=Warn  4=Error  C=clear', 42, DY + 434, 11, COL_DIMTEXT);
   DrawText(PChar('TDebugDraw: ' + IfThen(TDebugDraw.Instance.Enabled, 'ENABLED', 'DISABLED') + '  Grid: ' + IfThen(TDebugDraw.Instance.ShowGrid, 'ON', 'OFF')), 42, DY + 454, 11, COL_TEXT);
   DrawHeader('Demo 26 - Debug Utilities (TDebugDraw + TLogger + P2D.Utils.Math)');
   DrawFooter('G=grid  D=TDebugDraw  1-4=log  C=clear  L=move target');
end;

end.
