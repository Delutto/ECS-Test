unit Showcase.Scene.Builder;

{$mode objfpc}{$H+}

{ Demo 11 - Entity Builder  NEW: 32x32 icon textures per archetype. }
interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Health,
   P2D.Components.Tag, P2D.Components.Inventory, P2D.Components.Lifetime,
   P2D.Core.EntityBuilder, Showcase.Common;

type
   TBuilderDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH, FTemplate, FSpawnedN: integer;
      FSpawned: array of TEntity;
      FTRID, FHID, FTAGID: integer;
      FIcons: array[1..5] of TTexture2D;
      procedure GenIcons;
      procedure FreeIcons;
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
   TC2: array[1..5] of TColor = (
      (R: 255; G: 120; B: 80; A: 255), (R: 80; G: 120; B: 255; A: 255), (R: 80; G: 220; B: 100; A: 255),
      (R: 255; G: 200; B: 60; A: 255), (R: 255; G: 80; B: 80; A: 255));

constructor TBuilderDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Builder');
   FScreenW := AW;
   FScreenH := AH;
end;

procedure TBuilderDemoScene.GenIcons;
var
   Img: TImage;
begin
   Img := GenImageColor(32, 32, ColorCreate(28, 28, 42, 255));
   ImageDrawRectangle(@Img, 14, 2, 4, 22, ColorCreate(180, 190, 200, 255));
   ImageDrawRectangle(@Img, 8, 10, 16, 4, ColorCreate(180, 190, 200, 255));
   ImageDrawRectangle(@Img, 13, 24, 6, 6, ColorCreate(140, 100, 60, 255));
   ImageDrawRectangle(@Img, 8, 4, 8, 8, ColorCreate(80, 120, 180, 200));
   FIcons[1] := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(32, 32, ColorCreate(28, 28, 42, 255));
   ImageDrawRectangle(@Img, 14, 6, 4, 20, ColorCreate(140, 100, 60, 255));
   ImageDrawRectangle(@Img, 8, 4, 16, 8, ColorCreate(160, 80, 220, 255));
   ImageDrawRectangle(@Img, 10, 6, 12, 4, ColorCreate(200, 140, 255, 255));
   ImageDrawRectangle(@Img, 13, 2, 6, 6, ColorCreate(220, 180, 255, 200));
   FIcons[2] := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(32, 32, ColorCreate(28, 28, 42, 255));
   ImageDrawRectangle(@Img, 6, 2, 4, 28, ColorCreate(80, 160, 60, 255));
   ImageDrawRectangle(@Img, 10, 15, 16, 2, ColorCreate(210, 180, 140, 255));
   ImageDrawRectangle(@Img, 24, 13, 4, 6, ColorCreate(255, 200, 80, 255));
   FIcons[3] := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(32, 32, ColorCreate(28, 28, 42, 255));
   ImageDrawRectangle(@Img, 8, 12, 16, 14, ColorCreate(200, 160, 40, 255));
   ImageDrawRectangle(@Img, 10, 14, 12, 10, ColorCreate(220, 190, 80, 255));
   ImageDrawRectangle(@Img, 12, 7, 8, 7, ColorCreate(160, 120, 30, 255));
   ImageDrawRectangle(@Img, 14, 16, 4, 4, ColorCreate(255, 220, 100, 255));
   FIcons[4] := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(32, 32, ColorCreate(28, 28, 42, 255));
   ImageDrawRectangle(@Img, 6, 12, 20, 8, ColorCreate(220, 60, 60, 255));
   ImageDrawRectangle(@Img, 4, 14, 6, 4, ColorCreate(200, 40, 40, 255));
   ImageDrawRectangle(@Img, 22, 12, 4, 8, ColorCreate(255, 120, 80, 255));
   FIcons[5] := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TBuilderDemoScene.FreeIcons;
var
   I: integer;
begin
   for I := 1 to 5 do
      if FIcons[I].Id > 0 then
      begin
         UnloadTexture(FIcons[I]);
         FIcons[I].Id := 0;
      end;
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
   GenIcons;
   World.Init;
end;

procedure TBuilderDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FreeIcons;
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
   X := 80 + Random(SCR_W - 370);
   Y := DEMO_AREA_Y + 60 + Random(DEMO_AREA_H - 100);
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
   Dst: TRectangle;
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
      if FIcons[FTemplate].Id > 0 then
      begin
         Dst := RectangleCreate(Round(Tr.Position.X) - 16, Round(Tr.Position.Y) - 16, 32, 32);
         DrawTexturePro(FIcons[FTemplate], RectangleCreate(0, 0, 32, 32), Dst, Vector2Create(0, 0), 0, WHITE);
      end
      else
         DrawCircle(Round(Tr.Position.X), Round(Tr.Position.Y), 10, TC2[FTemplate]);
      DrawText(PChar(E.Name), Round(Tr.Position.X) - 20, Round(Tr.Position.Y) + 18, 9, COL_DIMTEXT);
   end;
   DrawPanel(SCR_W - 350, DEMO_AREA_Y + 10, 340, 386, 'Builder Code (selected template)');
   if FIcons[FTemplate].Id > 0 then
      DrawTexturePro(FIcons[FTemplate], RectangleCreate(0, 0, 32, 32),
         RectangleCreate(SCR_W - 80, DEMO_AREA_Y + 18, 36, 36), Vector2Create(0, 0), 0, WHITE);
   DrawText(PChar('Template ' + IntToStr(FTemplate) + ': ' + TN[FTemplate]), SCR_W - 340, DEMO_AREA_Y + 34, 13, TC2[FTemplate]);
   for J := 0 to 5 do
      DrawText(PChar(Lines[FTemplate][J]), SCR_W - 340, DEMO_AREA_Y + 60 + J * 28, 12, COL_TEXT);
   DrawPanel(SCR_W - 350, DEMO_AREA_Y + 406, 340, 260, 'Templates (1-5)');
   for I := 1 to 5 do
   begin
      if FIcons[I].Id > 0 then
         DrawTexturePro(FIcons[I], RectangleCreate(0, 0, 32, 32),
            RectangleCreate(SCR_W - 344, DEMO_AREA_Y + 420 + (I - 1) * 44, 28, 28), Vector2Create(0, 0), 0, WHITE);
      if I = FTemplate then
      begin
         DrawRectangle(SCR_W - 312, DEMO_AREA_Y + 418 + (I - 1) * 44, 296, 30, ColorCreate(60, 80, 120, 120));
         DrawText(PChar(IntToStr(I) + '  ' + TN[I]), SCR_W - 304, DEMO_AREA_Y + 426 + (I - 1) * 44, 14, TC2[I]);
      end
      else
         DrawText(PChar(IntToStr(I) + '  ' + TN[I]), SCR_W - 304, DEMO_AREA_Y + 426 + (I - 1) * 44, 13, COL_DIMTEXT);
   end;
   DrawText(PChar('Spawned entities: ' + IntToStr(FSpawnedN)), 30, DEMO_AREA_Y + 18, 13, COL_TEXT);
end;

end.
