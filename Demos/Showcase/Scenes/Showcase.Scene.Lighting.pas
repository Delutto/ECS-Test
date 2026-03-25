unit Showcase.Scene.Lighting;

{$mode objfpc}{$H+}

{ Demo 6 - 2D Lighting System
  LMB=move player  +/-=ambient darkness  F=toggle torch flicker }
interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.LightEmitter,
   P2D.Systems.Lighting, Showcase.Common;

type
   TLightingDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FLightSys: TLightingSystem2D;
      FPlayerE, FTorchE: TEntity;
      FAmbient: byte;
      FTRID, FLID: integer;
      procedure MkLight(X, Y: single; C: TColor; R: single; Fl: boolean; out E: TEntity);
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

constructor TLightingDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Lighting');

   FScreenW := AW;
   FScreenH := AH;
end;

procedure TLightingDemoScene.MkLight(X, Y: single; C: TColor; R: single; Fl: boolean; out E: TEntity);
var
   Tr: TTransformComponent;
   LC: TLightEmitterComponent2D;
begin
   E := World.CreateEntity('Light');

   Tr := TTransformComponent.Create;
   Tr.Position.X := X;
   Tr.Position.Y := Y;
   E.AddComponent(Tr);

   LC := TLightEmitterComponent2D.Create;
   LC.Color := C;
   LC.Radius := R;
   LC.Intensity := 1;
   LC.Flicker := Fl;
   LC.FlickerSpeed := 7;
   LC.FlickerAmp := 0.25;
   E.AddComponent(LC);
end;

procedure TLightingDemoScene.DoLoad;
begin
   FLightSys := TLightingSystem2D(World.AddSystem(TLightingSystem2D.Create(World, FScreenW, FScreenH)));
end;

procedure TLightingDemoScene.DoEnter;
var
   Dummy: TEntity;
   Tr: TTransformComponent;
   LC: TLightEmitterComponent2D;
begin
   FAmbient := 200;
   FLightSys.AmbientR := 20;
   FLightSys.AmbientG := 20;
   FLightSys.AmbientB := 40;
   FLightSys.AmbientA := FAmbient;
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FLID := ComponentRegistry.GetComponentID(TLightEmitterComponent2D);
   MkLight(200, 310, ColorCreate(255, 200, 100, 255), 120, True, FTorchE);
   MkLight(700, 260, ColorCreate(255, 230, 160, 255), 100, False, Dummy);
   MkLight(500, 480, ColorCreate(80, 120, 255, 255), 140, False, Dummy);
   FPlayerE := World.CreateEntity('Player');
   Tr := TTransformComponent.Create;
   Tr.Position.X := DEMO_AREA_CX;
   Tr.Position.Y := DEMO_AREA_CY;
   FPlayerE.AddComponent(Tr);
   LC := TLightEmitterComponent2D.Create;
   LC.Color := ColorCreate(220, 220, 255, 255);
   LC.Radius := 80;
   LC.Intensity := 0.7;
   FPlayerE.AddComponent(LC);
   World.Init;
end;

procedure TLightingDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TLightingDemoScene.Update(ADelta: single);
var
   Tr: TTransformComponent;
   LC: TLightEmitterComponent2D;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyDown(KEY_EQUAL) and (FAmbient < 255) then
      Inc(FAmbient);
   if IsKeyDown(KEY_MINUS) and (FAmbient > 10) then
      Dec(FAmbient);
   FLightSys.AmbientA := FAmbient;
   if IsKeyPressed(KEY_F) then
   begin
      LC := TLightEmitterComponent2D(FTorchE.GetComponentByID(FLID));
      if Assigned(LC) then
         LC.Flicker := not LC.Flicker;
   end;
   if IsMouseButtonDown(MOUSE_BUTTON_LEFT) then
   begin
      Tr := TTransformComponent(FPlayerE.GetComponentByID(FTRID));
      Tr.Position.X := GetMouseX;
      Tr.Position.Y := GetMouseY;
   end;
   World.Update(ADelta);
end;

procedure TLightingDemoScene.Render;
var
   Tr: TTransformComponent;
begin
   ClearBackground(ColorCreate(10, 8, 16, 255));
   DrawRectangle(100, 380, 800, 10, ColorCreate(80, 60, 40, 255));
   DrawCircle(200, 310, 10, COL_WARN);
   DrawText('Torch (flicker)', 160, 330, 11, COL_DIMTEXT);
   DrawCircle(700, 260, 10, COL_WARN);
   DrawText('Lantern (steady)', 660, 280, 11, COL_DIMTEXT);
   DrawCircle(500, 480, 10, COL_WARN);
   DrawText('Magic (blue)', 460, 500, 11, COL_DIMTEXT);
   Tr := TTransformComponent(FPlayerE.GetComponentByID(FTRID));
   DrawRectangle(Round(Tr.Position.X) - 10, Round(Tr.Position.Y) - 10, 20, 20, COL_ACCENT);
   World.Render;
   DrawHeader('Demo 6 - 2D Lighting System (TLightEmitterComponent2D)');
   DrawFooter('LMB=move player   +/-=ambient darkness   F=toggle torch flicker');
   DrawPanel(SCR_W - 260, DEMO_AREA_Y + 10, 250, 130, 'Lighting');
   DrawText(PChar('Ambient: ' + IntToStr(FAmbient) + '/255'), SCR_W - 250, DEMO_AREA_Y + 34, 12, COL_TEXT);
   DrawText('4 light emitter entities', SCR_W - 250, DEMO_AREA_Y + 54, 12, COL_DIMTEXT);
   DrawText('lsCircle + additive blend', SCR_W - 250, DEMO_AREA_Y + 72, 12, COL_DIMTEXT);
end;

end.
