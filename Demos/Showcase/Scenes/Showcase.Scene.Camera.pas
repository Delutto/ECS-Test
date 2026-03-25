unit Showcase.Scene.Camera;

{$mode objfpc}{$H+}

{ Demo 15 - Camera System (TCamera2DComponent + TCameraSystem)
  TCameraSystem (prio 15):
    Each frame lerps camera Transform toward Target entity using FollowSpeed,
    clamps inside Bounds when UseBounds=True, writes TCamera2DComponent.RaylibCamera.
  BeginCameraMode/EndCameraMode wrap BeginMode2D/EndMode2D.
  Controls: WASD=move target  +/-=zoom  B=toggle bounds  F=smooth vs snap }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Camera2D,
   P2D.Systems.Camera, Showcase.Common;

type
   TCameraDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FTarget, FCamE: TEntity;
      FCamSys: TCameraSystem;
      FTRID, FCID: Integer;
      function CamComp: TCamera2DComponent;
      function TargetTr: TTransformComponent;
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

const
   WW = 1600;
   WH = 600;

constructor TCameraDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('Camera');
   FScreenW := AW;
   FScreenH := AH;
end;

function TCameraDemoScene.CamComp: TCamera2DComponent;
begin
   Result := TCamera2DComponent(FCamE.GetComponentByID(FCID));
end;

function TCameraDemoScene.TargetTr: TTransformComponent;
begin
   Result := TTransformComponent(FTarget.GetComponentByID(FTRID));
end;

procedure TCameraDemoScene.DoLoad;
begin
   FCamSys := TCameraSystem(World.AddSystem(TCameraSystem.Create(World, FScreenW, FScreenH)));
end;

procedure TCameraDemoScene.DoEnter;
var
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
begin
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FCID := ComponentRegistry.GetComponentID(TCamera2DComponent);
   FTarget := World.CreateEntity('Target');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(400, WH div 2);
   FTarget.AddComponent(Tr);
   FCamE := World.CreateEntity('Camera');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(400, WH div 2);
   FCamE.AddComponent(Tr);
   Cam := TCamera2DComponent.Create;
   Cam.Zoom := 1.5;               { world-to-screen scale }
   Cam.FollowSpeed := 5.0;        { lerp speed; 9999 = instant snap }
   Cam.UseBounds := True;         { clamp camera so world edge is never shown }
   Cam.Bounds := TRectF.Create(0, 0, WW, WH);
   Cam.Target := FTarget;         { TCameraSystem reads this each frame }
   FCamE.AddComponent(Cam);
   World.Init;
end;

procedure TCameraDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TCameraDemoScene.Update(ADelta: Single);
var
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
   Spd: Single;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   Tr := TargetTr;
   Cam := CamComp;
   Spd := 200 * ADelta;
   if IsKeyDown(KEY_A) then
      Tr.Position.X := Tr.Position.X - Spd;
   if IsKeyDown(KEY_D) then
      Tr.Position.X := Tr.Position.X + Spd;
   if IsKeyDown(KEY_W) then
      Tr.Position.Y := Tr.Position.Y - Spd;
   if IsKeyDown(KEY_S) then
      Tr.Position.Y := Tr.Position.Y + Spd;
   Tr.Position.X := Max(10, Min(WW - 10, Tr.Position.X));
   Tr.Position.Y := Max(10, Min(WH - 10, Tr.Position.Y));
   if IsKeyPressed(KEY_EQUAL) then
      Cam.Zoom := Min(4, Cam.Zoom + 0.25);
   if IsKeyPressed(KEY_MINUS) then
      Cam.Zoom := Max(0.25, Cam.Zoom - 0.25);
   if IsKeyPressed(KEY_B) then
      Cam.UseBounds := not Cam.UseBounds;
   if IsKeyPressed(KEY_F) then
   begin
      if Cam.FollowSpeed > 100 then
         Cam.FollowSpeed := 5
      else
         Cam.FollowSpeed := 9999;
   end;
   World.Update(ADelta);
end;

procedure TCameraDemoScene.Render;
var
   Cam: TCamera2DComponent;
   RayC: TCamera2D;
   Tr: TTransformComponent;
   X, Y: Integer;
   C: TColor;
begin
   ClearBackground(ColorCreate(18, 18, 28, 255));
   Cam := CamComp;
   RayC := FCamSys.GetRaylibCamera;
   { Draw world inside BeginMode2D/EndMode2D — all coords are world-space }
   FCamSys.BeginCameraMode;
   Y := 0;
   while Y < WH do
   begin
      X := 0;
      while X < WW do
      begin
         C := IfThen(((X div 80 + Y div 80) mod 2) = 0, ColorCreate(30, 30, 45, 255), ColorCreate(25, 25, 38, 255));
         DrawRectangle(X, Y, 80, 80, C);
         Inc(X, 80);
      end;
      Inc(Y, 80);
   end;
   DrawRectangleLinesEx(RectangleCreate(0, 0, WW, WH), 4, ColorCreate(60, 60, 90, 255));
   DrawRectangle(200, 200, 60, 60, ColorCreate(200, 80, 80, 200));
   DrawText('A', 200, 270, 12, COL_DIMTEXT);
   DrawRectangle(800, 300, 80, 80, ColorCreate(80, 200, 80, 200));
   DrawText('B', 800, 390, 12, COL_DIMTEXT);
   DrawRectangle(1400, 150, 70, 70, ColorCreate(80, 80, 200, 200));
   DrawText('C', 1400, 230, 12, COL_DIMTEXT);
   if Cam.UseBounds then
      DrawRectangleLinesEx(RectangleCreate(Cam.Bounds.X, Cam.Bounds.Y, Cam.Bounds.W, Cam.Bounds.H), 2, ColorCreate(255, 200, 60, 100));
   Tr := TargetTr;
   DrawCircle(Round(Tr.Position.X), Round(Tr.Position.Y), 16, COL_ACCENT);
   DrawText('TARGET', Round(Tr.Position.X) - 22, Round(Tr.Position.Y) + 20, 10, COL_TEXT);
   FCamSys.EndCameraMode;
   DrawHeader('Demo 15 - Camera System (TCamera2DComponent + TCameraSystem)');
   DrawFooter('WASD=move target  +/-=zoom  B=toggle bounds  F=toggle smooth/snap');
   DrawPanel(SCR_W - 295, DEMO_AREA_Y + 10, 285, 180, 'Camera State');
   DrawText(PChar(Format('Zoom        : %.2f', [Cam.Zoom])), SCR_W - 285, DEMO_AREA_Y + 34, 12, COL_TEXT);
   DrawText(PChar(Format('FollowSpeed : %.0f', [Cam.FollowSpeed])), SCR_W - 285, DEMO_AREA_Y + 54, 12, COL_TEXT);
   DrawText(PChar('UseBounds   : ' + IfThen(Cam.UseBounds, 'TRUE', 'FALSE')), SCR_W - 285, DEMO_AREA_Y + 74, 12, IfThen(Cam.UseBounds, COL_GOOD, COL_BAD));
   DrawText(PChar(Format('RayTarget.X : %.1f', [RayC.Target.X])), SCR_W - 285, DEMO_AREA_Y + 96, 12, COL_DIMTEXT);
   DrawText(PChar(Format('RayTarget.Y : %.1f', [RayC.Target.Y])), SCR_W - 285, DEMO_AREA_Y + 114, 12, COL_DIMTEXT);
end;

end.
