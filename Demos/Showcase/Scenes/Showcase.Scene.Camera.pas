unit Showcase.Scene.Camera;

{$mode objfpc}{$H+}

{ Demo 15 - Camera: textured world landmarks (castle/trees/mountains/player). }
interface

uses
   SysUtils, StrUtils, Math, raylib, P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Camera2D, P2D.Systems.Camera, Showcase.Common;

type
   TCameraDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FTarget, FCamE: TEntity;
      FCamSys: TCameraSystem;
      FTRID, FCID: integer;
      FTexFloor, FTexMtn, FTexCastle, FTexTree, FTexPlayer: TTexture2D;
      procedure GenWorldTextures;
      procedure FreeWorldTextures;
      function CamComp: TCamera2DComponent;
      function TargetTr: TTransformComponent;
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
   WW = 1800;
   WH = 600;

function IfStr(B: boolean; const T, F: string): string;
begin
   if B then
      Result := T
   else
      Result := F;
end;

function IfCol(B: boolean; const T, F: TColor): TColor;
begin
   if B then
      Result := T
   else
      Result := F;
end;

function IfInt(B: boolean; T, F: integer): integer;
begin
   if B then
      Result := T
   else
      Result := F;
end;

constructor TCameraDemoScene.Create(AW, AH: integer);
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

procedure TCameraDemoScene.GenWorldTextures;
var
   Img: TImage;
begin
   Img := GenImageColor(80, 80, ColorCreate(54, 50, 44, 255));
   ImageDrawRectangle(@Img, 1, 1, 78, 78, ColorCreate(64, 60, 52, 255));
   ImageDrawRectangle(@Img, 0, 40, 80, 2, ColorCreate(44, 40, 35, 255));
   ImageDrawRectangle(@Img, 40, 0, 2, 40, ColorCreate(44, 40, 35, 255));
   ImageDrawRectangle(@Img, 1, 1, 78, 2, ColorCreate(80, 74, 62, 200));
   FTexFloor := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(120, 80, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 0, 40, 120, 40, ColorCreate(80, 76, 90, 255));
   ImageDrawRectangle(@Img, 10, 20, 60, 60, ColorCreate(100, 96, 110, 255));
   ImageDrawRectangle(@Img, 40, 4, 40, 76, ColorCreate(120, 116, 130, 255));
   ImageDrawRectangle(@Img, 52, 0, 16, 10, ColorCreate(230, 240, 255, 255));
   FTexMtn := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(80, 120, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 0, 30, 80, 90, ColorCreate(110, 100, 88, 255));
   ImageDrawRectangle(@Img, 2, 32, 76, 86, ColorCreate(120, 110, 96, 255));
   ImageDrawRectangle(@Img, 0, 0, 18, 34, ColorCreate(110, 100, 88, 255));
   ImageDrawRectangle(@Img, 62, 0, 18, 34, ColorCreate(110, 100, 88, 255));
   ImageDrawRectangle(@Img, 28, 0, 24, 34, ColorCreate(110, 100, 88, 255));
   ImageDrawRectangle(@Img, 30, 50, 20, 28, ColorCreate(60, 80, 130, 220));
   ImageDrawRectangle(@Img, 26, 80, 28, 40, ColorCreate(44, 34, 24, 200));
   FTexCastle := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(40, 80, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 16, 48, 8, 32, ColorCreate(100, 70, 40, 255));
   ImageDrawRectangle(@Img, 4, 24, 32, 30, ColorCreate(44, 120, 44, 255));
   ImageDrawRectangle(@Img, 8, 8, 24, 24, ColorCreate(56, 140, 56, 255));
   ImageDrawRectangle(@Img, 14, 0, 12, 14, ColorCreate(68, 160, 68, 255));
   FTexTree := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(16, 28, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 3, 0, 10, 10, ColorCreate(220, 190, 160, 255));
   ImageDrawRectangle(@Img, 0, 10, 16, 12, ColorCreate(80, 140, 210, 255));
   ImageDrawRectangle(@Img, 1, 10, 4, 12, ColorCreate(255, 255, 255, 80));
   ImageDrawRectangle(@Img, 0, 22, 7, 6, ColorCreate(60, 100, 50, 255));
   ImageDrawRectangle(@Img, 9, 22, 7, 6, ColorCreate(60, 100, 50, 255));
   FTexPlayer := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TCameraDemoScene.FreeWorldTextures;

   procedure U(var T: TTexture2D);
   begin
      if T.Id > 0 then
      begin
         UnloadTexture(T);
         T.Id := 0;
      end;
   end;

begin
   U(FTexFloor);
   U(FTexMtn);
   U(FTexCastle);
   U(FTexTree);
   U(FTexPlayer);
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
   GenWorldTextures;
   FTarget := World.CreateEntity('Target');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(500, WH div 2);
   FTarget.AddComponent(Tr);
   FCamE := World.CreateEntity('Camera');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(500, WH div 2);
   FCamE.AddComponent(Tr);
   Cam := TCamera2DComponent.Create;
   Cam.Zoom := 1.4;
   Cam.FollowSpeed := 5.0;
   Cam.UseBounds := True;
   Cam.Bounds := TRectF.Create(0, 0, WW, WH);
   Cam.Target := FTarget;
   FCamE.AddComponent(Cam);
   World.Init;
end;

procedure TCameraDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FreeWorldTextures;
end;

procedure TCameraDemoScene.Update(ADelta: single);
var
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
   Spd: single;
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
      if Cam.FollowSpeed > 100 then
         Cam.FollowSpeed := 5
      else
         Cam.FollowSpeed := 9999;
   World.Update(ADelta);
end;

procedure TCameraDemoScene.Render;
var
   Cam: TCamera2DComponent;
   RayC: TCamera2D;
   Tr: TTransformComponent;
   X, Y: integer;
begin
   ClearBackground(ColorCreate(16, 16, 26, 255));
   Cam := CamComp;
   RayC := FCamSys.GetRaylibCamera;
   FCamSys.BeginCameraMode;
   if FTexFloor.Id > 0 then
   begin
      Y := 0;
      while Y < WH do
      begin
         X := 0;
         while X < WW do
         begin
            DrawTexturePro(FTexFloor, RectangleCreate(0, 0, 80, 80), RectangleCreate(X, Y, 80, 80), Vector2Create(0, 0), 0,
               IfCol(((X div 80 + Y div 80) mod 2) = 0, WHITE, ColorCreate(220, 220, 220, 255)));
            Inc(X, 80);
         end;
         Inc(Y, 80);
      end;
   end;
   DrawRectangleLinesEx(RectangleCreate(0, 0, WW, WH), 4, ColorCreate(60, 60, 90, 255));
   if FTexMtn.Id > 0 then
   begin
      DrawTexturePro(FTexMtn, RectangleCreate(0, 0, 120, 80), RectangleCreate(80, WH - 130, 240, 130), Vector2Create(0, 0), 0, WHITE);
      DrawTexturePro(FTexMtn, RectangleCreate(0, 0, 120, 80), RectangleCreate(WW - 320, WH - 130, 240, 130), Vector2Create(0, 0), 0, WHITE);
   end;
   if FTexTree.Id > 0 then
   begin
      DrawTexturePro(FTexTree, RectangleCreate(0, 0, 40, 80), RectangleCreate(200, WH - 120, 60, 120), Vector2Create(0, 0), 0, WHITE);
      DrawTexturePro(FTexTree, RectangleCreate(0, 0, 40, 80), RectangleCreate(350, WH - 120, 60, 120), Vector2Create(0, 0), 0, WHITE);
      DrawTexturePro(FTexTree, RectangleCreate(0, 0, 40, 80), RectangleCreate(WW - 350, WH - 120, 60, 120), Vector2Create(0, 0), 0, WHITE);
      DrawTexturePro(FTexTree, RectangleCreate(0, 0, 40, 80), RectangleCreate(WW - 200, WH - 120, 60, 120), Vector2Create(0, 0), 0, WHITE);
   end;
   if FTexCastle.Id > 0 then
      DrawTexturePro(FTexCastle, RectangleCreate(0, 0, 80, 120),
         RectangleCreate(WW div 2 - 60, WH - 180, 120, 180), Vector2Create(0, 0), 0, WHITE)
   else
      DrawRectangle(WW div 2 - 60, WH - 180, 120, 180, ColorCreate(110, 100, 90, 255));
   DrawText('Castle', WW div 2 - 20, WH - 192, 12, COL_DIMTEXT);
   if Cam.UseBounds then
      DrawRectangleLinesEx(
         RectangleCreate(Cam.Bounds.X, Cam.Bounds.Y, Cam.Bounds.W, Cam.Bounds.H), 2, ColorCreate(255, 200, 60, 100));
   Tr := TargetTr;
   if FTexPlayer.Id > 0 then
      DrawTexturePro(FTexPlayer, RectangleCreate(0, 0, 16, 28),
         RectangleCreate(Round(Tr.Position.X) - 8, Round(Tr.Position.Y) - 14, 16, 28), Vector2Create(0, 0), 0, WHITE)
   else
      DrawCircle(Round(Tr.Position.X), Round(Tr.Position.Y), 14, COL_ACCENT);
   DrawText('TARGET', Round(Tr.Position.X) - 22, Round(Tr.Position.Y) + 16, 10, COL_TEXT);
   FCamSys.EndCameraMode;
   DrawHeader('Demo 15 - Camera System (TCamera2DComponent + TCameraSystem)');
   DrawFooter('WASD=move target  +/-=zoom  B=toggle bounds  F=toggle smooth/snap');
   DrawPanel(SCR_W - 298, DEMO_AREA_Y + 10, 288, 190, 'Camera State');
   DrawText(PChar(Format('Zoom        : %.2f', [Cam.Zoom])), SCR_W - 288, DEMO_AREA_Y + 34, 12, COL_TEXT);
   DrawText(PChar(Format('FollowSpeed : %.0f', [Cam.FollowSpeed])), SCR_W - 288, DEMO_AREA_Y + 54, 12, COL_TEXT);
   DrawText(PChar('UseBounds   : ' + IfStr(Cam.UseBounds, 'TRUE', 'FALSE')), SCR_W - 288, DEMO_AREA_Y + 74, 12, IfCol(Cam.UseBounds, COL_GOOD, COL_BAD));
   DrawText(PChar(Format('RayTarget.X : %.1f', [RayC.Target.X])), SCR_W - 288, DEMO_AREA_Y + 96, 12, COL_DIMTEXT);
   DrawText(PChar(Format('RayTarget.Y : %.1f', [RayC.Target.Y])), SCR_W - 288, DEMO_AREA_Y + 114, 12, COL_DIMTEXT);
end;

end.
