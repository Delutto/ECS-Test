unit Showcase.Scene.Builder;

{$mode objfpc}{$H+}

{ Demo 11 - Entity Builder (TEntityBuilder2D)
  1-5=template  E=spawn  C=clear  Shows fluent API code and live entities }
interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Health,
   P2D.Components.Tag, P2D.Components.Inventory, P2D.Components.Lifetime,
   P2D.Core.EntityBuilder, Showcase.Common;

type
   TBuilderDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH, FTemplate, FSpawnedN: integer;
      FSpawned: array of TEntity;
      FTRID, FHID, FTAGID: integer;
      procedure Spawn;
      procedure ClearAll;
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

const
   TN: array[1..5] of string = ('Warrior', 'Mage', 'Archer', 'Merchant', 'Bullet');

const
   TC2: array[1..5] of TColor = (
      (R: 255; G: 120; B: 80; A: 255), (R: 80; G: 120; B: 255; A: 255), (R: 80; G: 220; B: 100; A: 255),
      (R: 255; G: 200; B: 60; A: 255), (R: 255; G: 80; B: 80; A: 255));

constructor TBuilderDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Builder');
   FScreenW := AW;
   FScreenH := AH;
end;

procedure TBuilderDemoScene.DoLoad;
begin
end;

procedure TBuilderDemoScene.DoEnter;
begin
   FTemplate := 1;
   FSpawnedN := 0;
   SetLength(FSpawned, 64);
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FHID := ComponentRegistry.GetComponentID(THealthComponent2D);
   FTAGID := ComponentRegistry.GetComponentID(TTagComponent2D);
   World.Init;
end;

procedure TBuilderDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TBuilderDemoScene.ClearAll;
var
   I: integer;
begin
   for I := 0 to FSpawnedN - 1 do
      if Assigned(FSpawned[I]) and FSpawned[I].Alive then
         World.DestroyEntity(FSpawned[I].ID);
   FSpawnedN := 0;
end;

procedure TBuilderDemoScene.Spawn;
var
   E: TEntity;
   X, Y: single;
begin
   if FSpawnedN >= 48 then
      ClearAll;
   Randomize;
   X := 80 + Random(SCR_W - 220);
   Y := DEMO_AREA_Y + 80 + Random(DEMO_AREA_H - 120);
   case FTemplate of
      1:
         E := TEntityBuilder2D.InWorld(World).Named('Warrior').WithTransform(X, Y).WithRigidBody.WithCollider(ctPlayer, 16, 24).WithHealth(120, 8, 0.8).WithTags(['warrior', 'melee', 'damageable']).Build;
      2:
         E := TEntityBuilder2D.InWorld(World).Named('Mage').WithTransform(X, Y).WithRigidBody(0.8).WithCollider(ctPlayer, 14, 20).WithHealth(60, 0, 0.4).WithTags(['mage', 'ranged', 'magic']).Build;
      3:
         E := TEntityBuilder2D.InWorld(World).Named('Archer').WithTransform(X, Y).WithRigidBody(0.9).WithCollider(ctPlayer, 14, 22).WithHealth(80, 2, 0.5).WithInventory(10).WithTags(['archer', 'ranged']).Build;
      4:
         E := TEntityBuilder2D.InWorld(World).Named('Merchant').WithTransform(X, Y).WithKinematic.WithCollider(ctNone, 18, 24, 0, 0, True).WithInventory(40).WithTags(['npc', 'friendly', 'shop']).Build;
      5:
         E := TEntityBuilder2D.InWorld(World).Named('Bullet').WithTransform(X, Y).WithKinematic.WithCollider(ctHazard, 6, 6, 0, 0, True).WithLifetime(3).WithTags(['projectile']).Build;
      else
         Exit;
   end;
   FSpawned[FSpawnedN] := E;
   Inc(FSpawnedN);
end;

procedure TBuilderDemoScene.Update(ADelta: single);
var
   I: integer;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   for I := 1 to 5 do
      if IsKeyPressed(KEY_ZERO + I) then
         FTemplate := I;
   if IsKeyPressed(KEY_E) then
      Spawn;
   if IsKeyPressed(KEY_C) then
      ClearAll;
   World.Update(ADelta);
end;

procedure TBuilderDemoScene.Render;
const
   Lines: array[1..5, 0..5] of string = (
      ('TEntityBuilder2D.InWorld(W)', '.Named(''Warrior'')', '.WithTransform(X,Y)', '.WithRigidBody', '.WithHealth(120,8,0.8)', '.WithTags([warrior]).Build'),
      ('TEntityBuilder2D.InWorld(W)', '.Named(''Mage'')', '.WithTransform(X,Y)', '.WithRigidBody(0.8)', '.WithHealth(60,0,0.4)', '.WithTags([magic]).Build'),
      ('TEntityBuilder2D.InWorld(W)', '.Named(''Archer'')', '.WithTransform(X,Y)', '.WithRigidBody(0.9)', '.WithInventory(10)', '.WithTags([ranged]).Build'),
      ('TEntityBuilder2D.InWorld(W)', '.Named(''Merchant'')', '.WithTransform(X,Y)', '.WithKinematic', '.WithInventory(40)', '.WithTags([shop]).Build'),
      ('TEntityBuilder2D.InWorld(W)', '.Named(''Bullet'')', '.WithTransform(X,Y)', '.WithKinematic', '.WithLifetime(3)', '.WithTags([projectile]).Build'));
var
   I, J: integer;
   E: TEntity;
   Tr: TTransformComponent;
   H: THealthComponent2D;
   TC3: TTagComponent2D;
   T: integer;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 11 - Entity Builder (TEntityBuilder2D fluent API)');
   DrawFooter('1-5=template   E=spawn   C=clear all spawned');
   for I := 0 to FSpawnedN - 1 do
   begin
      E := FSpawned[I];
      if not Assigned(E) or not E.Alive then
         Continue;
      Tr := TTransformComponent(E.GetComponentByID(FTRID));
      if not Assigned(Tr) then
         Continue;
      DrawCircle(Round(Tr.Position.X), Round(Tr.Position.Y), 10, TC2[FTemplate]);
      DrawText(PChar(E.Name), Round(Tr.Position.X) - 20, Round(Tr.Position.Y) + 12, 9, COL_DIMTEXT);
   end;
   DrawPanel(SCR_W - 340, DEMO_AREA_Y + 10, 330, 370, 'Builder Code (selected)');
   DrawText(PChar('Template ' + IntToStr(FTemplate) + ': ' + TN[FTemplate]),
      SCR_W - 330, DEMO_AREA_Y + 34, 13, TC2[FTemplate]);
   for J := 0 to 5 do
      DrawText(PChar(Lines[FTemplate][J]), SCR_W - 330, DEMO_AREA_Y + 58 + J * 28, 12, COL_TEXT);
   DrawPanel(SCR_W - 340, DEMO_AREA_Y + 390, 330, 240, 'Templates (1-5)');
   for I := 1 to 5 do
   begin
      if I = FTemplate then
      begin
         DrawRectangle(SCR_W - 336, DEMO_AREA_Y + 406 + (I - 1) * 42, 318, 38, ColorCreate(60, 80, 120, 120));
         DrawText(PChar(IntToStr(I) + ' ' + TN[I]), SCR_W - 326, DEMO_AREA_Y + 418 + (I - 1) * 42, 14, TC2[I]);
      end
      else
         DrawText(PChar(IntToStr(I) + ' ' + TN[I]), SCR_W - 326, DEMO_AREA_Y + 418 + (I - 1) * 42, 13, COL_DIMTEXT);
   end;
   DrawText(PChar('Spawned entities: ' + IntToStr(FSpawnedN)), 30, DEMO_AREA_Y + 20, 13, COL_TEXT);
end;

end.
