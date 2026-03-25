unit Showcase.Scene.Parallax;

{$mode objfpc}{$H+}

{ Demo 16 - Parallax Backgrounds (TParallaxLayerComponent2D + TParallaxSystem2D)
  TParallaxSystem2D (RenderLayer=rlBackground, prio 10):
    Sorts entities by TParallaxLayerComponent2D.ZOrder.
    RawOffX = CamTargetX * ScrollFactorX.
    If TileH: wraps RawOffX into [0..DrawW) for seamless tiling.
    Draws enough copies to fill the screen.
  ScrollFactor=0.05 (far mountains), 0.20 (hills), 0.50 (trees).
  Controls: WASD=scroll camera }
interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Camera2D, P2D.Components.ParallaxLayer,
   P2D.Systems.Parallax, P2D.Systems.Camera, Showcase.Common;

type
   TParallaxDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FCamE: TEntity;
      FCamSys: TCameraSystem;
      FTextures: array[0..2] of TTexture2D;
      FTRID: Integer;
      procedure GenTextures;
      function CamTr: TTransformComponent;
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
   P2D.Core.System,
   P2D.Systems.SceneManager;

const
   SNAMES: array[0..2] of String = ('Mountains SF=0.05', 'Hills SF=0.20', 'Trees SF=0.50');
   SF: array[0..2] of Single = (0.05, 0.20, 0.50);

constructor TParallaxDemoScene.Create(AW, AH: Integer);
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
{ Generate three 512x240 silhouette images (mountains, hills, tree-line).
  Cosine+sine waves produce jagged profiles; colours differ per layer. }
var
   Img: TImage;
   Clr: array[0..2] of TColor;
   I, X, H: Integer;
begin
   Clr[0] := ColorCreate(60, 60, 100, 200);
   Clr[1] := ColorCreate(40, 100, 60, 200);
   Clr[2] := ColorCreate(20, 80, 20, 230);
   for I := 0 to 2 do
   begin
      Img := GenImageColor(512, 240, ColorCreate(0, 0, 0, 0));
      for X := 0 to 511 do
      begin
         H := Round(80 + 60 * Cos(X * 0.015 * (I + 1)) + 30 * Sin(X * 0.04 * (I + 1)) + 20 * Cos(X * 0.08));
         H := Max(20, Min(200, H));
         ImageDrawRectangle(@Img, X, 240 - H, 1, H, Clr[I]);
      end;
      FTextures[I] := LoadTextureFromImage(Img);
      UnloadImage(Img);
   end;
end;

procedure TParallaxDemoScene.DoLoad;
begin
   World.AddSystem(TParallaxSystem2D.Create(World, FScreenW, FScreenH));
   FCamSys := TCameraSystem(World.AddSystem(TCameraSystem.Create(World, FScreenW, FScreenH)));
end;

procedure TParallaxDemoScene.DoEnter;
var
   I: Integer;
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
      Tr.Position := Vector2Create(0, I * 60.0);
      Tr.Scale := Vector2Create(2, 2);
      E.AddComponent(Tr);
      PL := TParallaxLayerComponent2D.Create;
      PL.Texture := FTextures[I];
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
var
   I: Integer;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   for I := 0 to 2 do
      if FTextures[I].Id > 0 then
      begin
         UnloadTexture(FTextures[I]);
         FTextures[I].Id := 0;
      end;
end;

procedure TParallaxDemoScene.Update(ADelta: Single);
var
   Tr: TTransformComponent;
   Spd: Single;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   Tr := CamTr;
   Spd := 250 * ADelta;
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
   I: Integer;
begin
   DrawRectangleGradientV(0, DEMO_AREA_Y, SCR_W, DEMO_AREA_H,
      ColorCreate(30, 50, 100, 255), ColorCreate(60, 80, 40, 255));
   World.RenderByLayer(rlBackground);
   DrawRectangle(0, SCR_H - FOOTER_H - 80, SCR_W, 80, ColorCreate(30, 80, 30, 255));
   DrawHeader('Demo 16 - Parallax Backgrounds (TParallaxLayerComponent2D)');
   DrawFooter('WASD = scroll camera to see depth-based parallax effect');
   DrawPanel(SCR_W - 300, DEMO_AREA_Y + 10, 290, 160, 'Layer Scroll Factors');
   for I := 0 to 2 do
      DrawText(PChar(SNAMES[I]), SCR_W - 290, DEMO_AREA_Y + 34 + I * 44, 11, COL_TEXT);
   Tr := CamTr;
   DrawPanel(SCR_W - 300, DEMO_AREA_Y + 180, 290, 60, 'Camera Position');
   DrawText(PChar(Format('X: %.0f   Y: %.0f', [Tr.Position.X, Tr.Position.Y])),
      SCR_W - 290, DEMO_AREA_Y + 204, 13, COL_ACCENT);
end;

end.
