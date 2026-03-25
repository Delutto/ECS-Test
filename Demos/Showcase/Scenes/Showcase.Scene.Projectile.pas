unit Showcase.Scene.Projectile;

{$mode objfpc}{$H+}

{ Demo 4 - Projectile System
  LMB=shoot toward mouse  SPACE=fan burst  G=toggle gravity  BACKSPACE=menu }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Projectile,
   P2D.Systems.Projectile, Showcase.Common;

type
   TProjectileDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH, FShotCount: integer;
      FUseGravity: boolean;
      FProjSys: TProjectileSystem2D;
      FCX, FCY: single;
      procedure FireAt(TX, TY, Offset, Grav: single);
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

constructor TProjectileDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Projectile');

   FScreenW := AW;
   FScreenH := AH;
end;

procedure TProjectileDemoScene.FireAt(TX, TY, Offset, Grav: single);
var
   E: TEntity;
   Tr: TTransformComponent;
   PC: TProjectileComponent2D;
   DX, DY, L, A: single;
begin
   E := World.CreateEntity('Bullet');
   Tr := TTransformComponent.Create;
   Tr.Position.X := FCX;
   Tr.Position.Y := FCY;
   E.AddComponent(Tr);
   PC := TProjectileComponent2D.Create;
   DX := TX - FCX;
   DY := TY - FCY;
   L := Sqrt(DX * DX + DY * DY);
   if L < 1 then
      L := 1;
   A := ArcTan2(DY / L, DX / L) + Offset * (Pi / 180);
   PC.DirectionX := Cos(A);
   PC.DirectionY := Sin(A);
   PC.Speed := 420;
   PC.Gravity := Grav;
   PC.Lifetime := 2.5;
   PC.HitsLeft := 1;
   E.AddComponent(PC);
   Inc(FShotCount);
end;

procedure TProjectileDemoScene.DoLoad;
begin
   FProjSys := TProjectileSystem2D(World.AddSystem(TProjectileSystem2D.Create(World)));
end;

procedure TProjectileDemoScene.DoEnter;
begin
   FUseGravity := False;
   FShotCount := 0;
   FCX := FScreenW * 0.15;
   FCY := FScreenH * 0.55;
   World.Init;
end;

procedure TProjectileDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TProjectileDemoScene.Update(ADelta: single);
var
   I: integer;
   MX, MY: single;
   Grav: single;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_G) then
      FUseGravity := not FUseGravity;
   Grav := IfThen(FUseGravity, 300, 0);
   MX := GetMouseX;
   MY := GetMouseY;
   if IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
      FireAt(MX, MY, 0, Grav);
   if IsKeyPressed(KEY_SPACE) then
      for I := -2 to 2 do
         FireAt(MX, MY, I * 12, Grav);
   World.Update(ADelta);
end;

procedure TProjectileDemoScene.Render;
var
   E: TEntity;
   Tr: TTransformComponent;
   PC: TProjectileComponent2D;
   TRID, PCID: integer;
   Pct: single;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 4 - Projectile System (TProjectileComponent2D)');
   DrawFooter('LMB=shoot   SPACE=fan burst (5)   G=toggle gravity arc');
   TRID := ComponentRegistry.GetComponentID(TTransformComponent);
   PCID := ComponentRegistry.GetComponentID(TProjectileComponent2D);
   for E in World.Entities.GetAll do
   begin
      if not E.Alive then
         Continue;
      PC := TProjectileComponent2D(E.GetComponentByID(PCID));
      if not Assigned(PC) then
         Continue;
      Tr := TTransformComponent(E.GetComponentByID(TRID));
      if not Assigned(Tr) then
         Continue;
      Pct := 1 - Min(1, PC.LifetimeTimer / PC.Lifetime);
      DrawCircle(Round(Tr.Position.X), Round(Tr.Position.Y), 5,
         ColorCreate(255, Round(200 * Pct), Round(80 * Pct), 255));
   end;
   DrawCircle(Round(FCX), Round(FCY), 14, COL_WARN);
   DrawText('Cannon', Round(FCX) - 20, Round(FCY) + 18, 12, COL_DIMTEXT);
   DrawPanel(SCR_W - 280, DEMO_AREA_Y + 10, 260, 150, 'Stats');
   DrawText(PChar('Gravity: ' + IfThen(FUseGravity, 'ON', 'OFF') + ' (G=toggle)'),
      SCR_W - 270, DEMO_AREA_Y + 34, 13, COL_TEXT);
   DrawText(PChar('Shots: ' + IntToStr(FShotCount)), SCR_W - 270, DEMO_AREA_Y + 54, 13, COL_TEXT);
   DrawText('Speed: 420 px/s', SCR_W - 270, DEMO_AREA_Y + 74, 12, COL_DIMTEXT);
   DrawText('Lifetime: 2.5 s', SCR_W - 270, DEMO_AREA_Y + 92, 12, COL_DIMTEXT);
end;

end.
