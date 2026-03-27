unit Showcase.Scene.Parallax;

{$mode objfpc}{$H+}

{ Demo 16 - Parallax  NEW: star-field sky + grass/earth ground strip. }
interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Camera2D, P2D.Components.ParallaxLayer,
   P2D.Systems.Parallax, P2D.Systems.Camera, Showcase.Common;

type
   TParallaxDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FCamE: TEntity;
      FCamSys: TCameraSystem;
      FLayers: array[0..2] of TTexture2D;
      FTexStars, FTexGrnd: TTexture2D;
      FTRID: integer;
      procedure GenTextures;
      procedure FreeTextures;
      function CamTr: TTransformComponent;
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
   P2D.Core.System, P2D.Systems.SceneManager;

const
   SNAMES: array[0..2] of string = ('Mountains SF=0.05', 'Hills SF=0.20', 'Trees SF=0.50');
   SF: array[0..2] of single = (0.05, 0.20, 0.50);

function IfTI(B: boolean; T, F: integer): integer;
begin
   if B then
      Result := T
   else
      Result := F;
end;

constructor TParallaxDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Parallax');
   FScreenW := AW;
   FScreenH := AH;
end;

function TParallaxDemoScene.CamTr: TTransformComponent;
begin
   Result := TTransformComponent(FCamE.GetComponentByID(FTRID));
end;

procedure TParallaxDemoScene.GenTextures;
var
   Img: TImage;
   Clr: array[0..2] of TColor;
   I, X, H, SS: integer;
begin
   Clr[0] := ColorCreate(55, 55, 95, 210);
   Clr[1] := ColorCreate(34, 90, 54, 220);
   Clr[2] := ColorCreate(18, 68, 28, 235);
   for I := 0 to 2 do
   begin
      Img := GenImageColor(512, 240, ColorCreate(0, 0, 0, 0));
      for X := 0 to 511 do
      begin
         H := Round(80 + 60 * Cos(X * 0.014 * (I + 1)) + 28 * Sin(X * 0.038 * (I + 1)) + 18 * Cos(X * 0.075));
         H := Max(18, Min(200, H));
         ImageDrawRectangle(@Img, X, 240 - H, 1, H, Clr[I]);
      end;
      FLayers[I] := LoadTextureFromImage(Img);
      UnloadImage(Img);
   end;
   Img := GenImageColor(512, 200, ColorCreate(6, 8, 26, 255));
   Randomize;
   for I := 0 to 219 do
   begin
      X := Random(512);
      if Random(8) = 0 then
         ImageDrawRectangle(@Img, X, Random(180), 3, 3, ColorCreate(240 + Random(15), 240 + Random(15), 200 + Random(55), 230))
      else
         ImageDrawRectangle(@Img, X, Random(190), 1, 1, ColorCreate(160 + Random(90), 160 + Random(90), 160 + Random(90), 160 + Random(80)));
   end;
   ImageDrawRectangle(@Img, 410, 18, 44, 44, ColorCreate(230, 232, 210, 230));
   ImageDrawRectangle(@Img, 418, 24, 30, 32, ColorCreate(240, 242, 224, 240));
   FTexStars := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(256, 48, ColorCreate(70, 44, 22, 255));
   ImageDrawRectangle(@Img, 0, 0, 256, 18, ColorCreate(46, 128, 36, 255));
   ImageDrawRectangle(@Img, 0, 0, 256, 4, ColorCreate(66, 160, 52, 255));
   for I := 0 to 11 do
      ImageDrawRectangle(@Img, I * 22 + Random(10), 4 + Random(6), 5, Random(6) + 3, ColorCreate(28, 108, 24, 255));
   FTexGrnd := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TParallaxDemoScene.FreeTextures;

   procedure U(var T: TTexture2D);
   begin
      if T.Id > 0 then
      begin
         UnloadTexture(T);
         T.Id := 0;
      end;
   end;

var
   I: integer;
begin
   for I := 0 to 2 do
      U(FLayers[I]);
   U(FTexStars);
   U(FTexGrnd);
end;

procedure TParallaxDemoScene.DoLoad;
begin
   World.AddSystem(TParallaxSystem2D.Create(World, FScreenW, FScreenH));
   FCamSys := TCameraSystem(World.AddSystem(TCameraSystem.Create(World, FScreenW, FScreenH)));
end;

procedure TParallaxDemoScene.DoEnter;
var
   I: integer;
   E: TEntity;
   Tr: TTransformComponent;
   PL: TParallaxLayerComponent2D;
   Cam: TCamera2DComponent;
begin
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   GenTextures;
   FCamE := World.CreateEntity('Camera');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(0, 0);
   FCamE.AddComponent(Tr);
   Cam := TCamera2DComponent.Create;
   Cam.Zoom := 1;
   Cam.FollowSpeed := 9999;
   Cam.UseBounds := False;
   FCamE.AddComponent(Cam);
   for I := 0 to 2 do
   begin
      E := World.CreateEntity('Layer' + IntToStr(I));
      Tr := TTransformComponent.Create;
      Tr.Position := Vector2Create(0, I * 55.0);
      Tr.Scale := Vector2Create(2, 2);
      E.AddComponent(Tr);
      PL := TParallaxLayerComponent2D.Create;
      PL.Texture := FLayers[I];
      PL.ScrollFactorX := SF[I];
      PL.ScrollFactorY := 0;
      PL.TileH := True;
      PL.TileV := False;
      PL.ZOrder := I;
      PL.Tint := WHITE;
      E.AddComponent(PL);
   end;
   World.Init;
end;

procedure TParallaxDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FreeTextures;
end;

procedure TParallaxDemoScene.Update(ADelta: single);
var
   Tr: TTransformComponent;
   Spd: single;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   Tr := CamTr;
   Spd := 260 * ADelta;
   if IsKeyDown(KEY_A) then
      Tr.Position.X := Tr.Position.X - Spd;
   if IsKeyDown(KEY_D) then
      Tr.Position.X := Tr.Position.X + Spd;
   if IsKeyDown(KEY_W) then
      Tr.Position.Y := Tr.Position.Y - Spd;
   if IsKeyDown(KEY_S) then
      Tr.Position.Y := Tr.Position.Y + Spd;
   World.Update(ADelta);
end;

procedure TParallaxDemoScene.Render;
var
   Tr: TTransformComponent;
   I, RepW, DstY: integer;
begin
   DrawRectangleGradientV(0, DEMO_AREA_Y, SCR_W, DEMO_AREA_H, ColorCreate(6, 8, 26, 255), ColorCreate(28, 40, 86, 255));
   if FTexStars.Id > 0 then
   begin
      RepW := 0;
      while RepW < SCR_W do
      begin
         DrawTexturePro(FTexStars, RectangleCreate(0, 0, 512, 200),
            RectangleCreate(RepW, DEMO_AREA_Y, 512, DEMO_AREA_H * 2 div 3), Vector2Create(0, 0), 0, WHITE);
         Inc(RepW, 512);
      end;
   end;
   World.RenderByLayer(rlBackground);
   DstY := SCR_H - FOOTER_H - 70;
   if FTexGrnd.Id > 0 then
   begin
      RepW := 0;
      while RepW < SCR_W do
      begin
         DrawTexturePro(FTexGrnd, RectangleCreate(0, 0, 256, 48), RectangleCreate(RepW, DstY, 256, 70), Vector2Create(0, 0), 0, WHITE);
         Inc(RepW, 256);
      end;
   end
   else
      DrawRectangle(0, DstY, SCR_W, 70, ColorCreate(30, 80, 30, 255));
   DrawHeader('Demo 16 - Parallax Backgrounds (TParallaxLayerComponent2D)');
   DrawFooter('WASD = scroll camera to see depth-based parallax effect');
   DrawPanel(SCR_W - 300, DEMO_AREA_Y + 10, 290, 178, 'Layer Scroll Factors');
   for I := 0 to 2 do
      DrawText(PChar(SNAMES[I]), SCR_W - 290, DEMO_AREA_Y + 34 + I * 50, 12, COL_TEXT);
   Tr := CamTr;
   DrawPanel(SCR_W - 300, DEMO_AREA_Y + 198, 290, 64, 'Camera Position');
   DrawText(PChar(Format('X: %.0f   Y: %.0f', [Tr.Position.X, Tr.Position.Y])), SCR_W - 290, DEMO_AREA_Y + 222, 13, COL_ACCENT);
end;

end.
