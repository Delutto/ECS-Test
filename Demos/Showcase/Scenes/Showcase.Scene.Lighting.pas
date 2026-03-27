unit Showcase.Scene.Lighting;

{$mode objfpc}{$H+}

{ Demo 6 - 2D Lighting System
  NEW: stone-wall backdrop, torch/lantern/magic-sphere sprites, player character sprite.
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
      { CPU-generated textures }
      FTexWall: TTexture2D;    { 64x64 dungeon stone wall }
      FTexFloor: TTexture2D;   { 64x64 stone floor slab   }
      FTexTorch: TTexture2D;   { 24x36 wall torch sprite   }
      FTexLantern: TTexture2D; { 20x28 lantern sprite      }
      FTexMagic: TTexture2D;   { 24x24 magic orb           }
      FTexPlayer: TTexture2D;  { 18x26 player character    }
      procedure GenSceneTextures;
      procedure FreeSceneTextures;
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

{ ── Texture generation ─────────────────────────────────────────────────── }
procedure TLightingDemoScene.GenSceneTextures;
var
   Img: TImage;
begin
   { 64x64 stone wall — dark, with mortar lines }
   Img := GenImageColor(64, 64, ColorCreate(40, 36, 30, 255));
   ImageDrawRectangle(@Img, 1, 1, 62, 62, ColorCreate(50, 45, 38, 255));
   ImageDrawRectangle(@Img, 0, 32, 64, 2, ColorCreate(32, 28, 23, 255));
   ImageDrawRectangle(@Img, 32, 0, 2, 32, ColorCreate(32, 28, 23, 255));
   ImageDrawRectangle(@Img, 1, 1, 62, 2, ColorCreate(62, 56, 46, 200));
   ImageDrawRectangle(@Img, 4, 4, 6, 6, ColorCreate(58, 52, 44, 180));
   ImageDrawRectangle(@Img, 36, 4, 6, 6, ColorCreate(58, 52, 44, 180));
   ImageDrawRectangle(@Img, 4, 36, 6, 6, ColorCreate(58, 52, 44, 180));
   ImageDrawRectangle(@Img, 36, 36, 6, 6, ColorCreate(58, 52, 44, 180));
   FTexWall := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { 64x64 stone floor slab — slightly lighter }
   Img := GenImageColor(64, 64, ColorCreate(48, 44, 36, 255));
   ImageDrawRectangle(@Img, 1, 1, 62, 62, ColorCreate(58, 53, 44, 255));
   ImageDrawRectangle(@Img, 0, 32, 64, 2, ColorCreate(40, 36, 30, 255));
   ImageDrawRectangle(@Img, 32, 0, 2, 32, ColorCreate(40, 36, 30, 255));
   ImageDrawRectangle(@Img, 1, 1, 62, 2, ColorCreate(70, 64, 54, 200));
   FTexFloor := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { 24x36 wall torch (handle + head + flame) }
   Img := GenImageColor(24, 36, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 10, 20, 4, 14, ColorCreate(100, 70, 35, 255));
   ImageDrawRectangle(@Img, 6, 16, 12, 6, ColorCreate(120, 90, 45, 255));
   ImageDrawRectangle(@Img, 7, 6, 10, 12, ColorCreate(255, 160, 30, 220));
   ImageDrawRectangle(@Img, 9, 2, 6, 10, ColorCreate(255, 210, 60, 200));
   ImageDrawRectangle(@Img, 10, 0, 4, 6, ColorCreate(255, 240, 130, 170));
   FTexTorch := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { 20x28 lantern (body + glow window + hook) }
   Img := GenImageColor(20, 28, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 8, 0, 4, 4, ColorCreate(120, 100, 60, 255));
   ImageDrawRectangle(@Img, 4, 4, 12, 16, ColorCreate(130, 110, 60, 255));
   ImageDrawRectangle(@Img, 6, 6, 8, 12, ColorCreate(255, 220, 100, 220));
   ImageDrawRectangle(@Img, 4, 20, 12, 6, ColorCreate(110, 90, 50, 255));
   ImageDrawRectangle(@Img, 8, 26, 4, 2, ColorCreate(90, 70, 40, 255));
   FTexLantern := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { 24x24 magic orb (concentric glow rings) }
   Img := GenImageColor(24, 24, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 4, 4, 16, 16, ColorCreate(60, 80, 220, 200));
   ImageDrawRectangle(@Img, 6, 6, 12, 12, ColorCreate(100, 130, 255, 230));
   ImageDrawRectangle(@Img, 8, 8, 8, 8, ColorCreate(160, 180, 255, 255));
   ImageDrawRectangle(@Img, 10, 10, 4, 4, ColorCreate(220, 230, 255, 255));
   ImageDrawRectangle(@Img, 7, 5, 4, 3, ColorCreate(255, 255, 255, 140));
   FTexMagic := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { 18x26 player character }
   Img := GenImageColor(18, 26, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 4, 0, 10, 9, ColorCreate(220, 190, 160, 255));
   ImageDrawRectangle(@Img, 0, 9, 18, 11, ColorCreate(80, 160, 220, 255));
   ImageDrawRectangle(@Img, 2, 9, 4, 11, ColorCreate(255, 255, 255, 80));
   ImageDrawRectangle(@Img, 0, 20, 8, 6, ColorCreate(60, 100, 50, 255));
   ImageDrawRectangle(@Img, 10, 20, 8, 6, ColorCreate(60, 100, 50, 255));
   FTexPlayer := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TLightingDemoScene.FreeSceneTextures;

   procedure U(var T: TTexture2D);
   begin
      if T.Id > 0 then
      begin
         UnloadTexture(T);
         T.Id := 0;
      end;
   end;

begin
   U(FTexWall);
   U(FTexFloor);
   U(FTexTorch);
   U(FTexLantern);
   U(FTexMagic);
   U(FTexPlayer);
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
   GenSceneTextures;
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
   FreeSceneTextures;
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
   TX, TY: integer;
   Dst: TRectangle;
begin
   ClearBackground(ColorCreate(10, 8, 16, 255));

   { ── Tile the dungeon wall texture as background }
   if FTexWall.Id > 0 then
   begin
      TY := DEMO_AREA_Y;
      while TY < SCR_H - FOOTER_H do
      begin
         TX := 0;
         while TX < SCR_W do
         begin
            DrawTexturePro(FTexWall, RectangleCreate(0, 0, 64, 64),
               RectangleCreate(TX, TY, 64, 64), Vector2Create(0, 0), 0, ColorCreate(255, 255, 255, 255));
            Inc(TX, 64);
         end;
         Inc(TY, 64);
      end;
   end;

   { ── Stone floor strip (the platform the lights stand on) }
   if FTexFloor.Id > 0 then
   begin
      TX := 0;
      while TX < SCR_W do
      begin
         DrawTexturePro(FTexFloor, RectangleCreate(0, 0, 64, 64),
            RectangleCreate(TX, 382, 64, 46), Vector2Create(0, 0), 0, WHITE);
         Inc(TX, 64);
      end;
   end
   else
      DrawRectangle(100, 380, 800, 10, ColorCreate(80, 60, 40, 255));

   { ── Light source sprites }
   if FTexTorch.Id > 0 then
      DrawTexturePro(FTexTorch, RectangleCreate(0, 0, 24, 36),
         RectangleCreate(188, 282, 24, 36), Vector2Create(0, 0), 0, WHITE)
   else
      DrawCircle(200, 310, 10, COL_WARN);
   DrawText('Torch (flicker)', 160, 330, 11, COL_DIMTEXT);

   if FTexLantern.Id > 0 then
      DrawTexturePro(FTexLantern, RectangleCreate(0, 0, 20, 28),
         RectangleCreate(690, 242, 20, 28), Vector2Create(0, 0), 0, WHITE)
   else
      DrawCircle(700, 260, 10, COL_WARN);
   DrawText('Lantern (steady)', 658, 278, 11, COL_DIMTEXT);

   if FTexMagic.Id > 0 then
      DrawTexturePro(FTexMagic, RectangleCreate(0, 0, 24, 24),
         RectangleCreate(488, 468, 24, 24), Vector2Create(0, 0), 0, WHITE)
   else
      DrawCircle(500, 480, 10, COL_WARN);
   DrawText('Magic (blue)', 460, 498, 11, COL_DIMTEXT);

   { ── Player character sprite }
   Tr := TTransformComponent(FPlayerE.GetComponentByID(FTRID));
   if FTexPlayer.Id > 0 then
   begin
      Dst := RectangleCreate(Round(Tr.Position.X) - 9, Round(Tr.Position.Y) - 13, 18, 26);
      DrawTexturePro(FTexPlayer, RectangleCreate(0, 0, 18, 26), Dst, Vector2Create(0, 0), 0, WHITE);
   end
   else
      DrawRectangle(Round(Tr.Position.X) - 10, Round(Tr.Position.Y) - 10, 20, 20, COL_ACCENT);

   { ── Lighting overlay (drawn last) }
   World.Render;

   DrawHeader('Demo 6 - 2D Lighting System (TLightEmitterComponent2D)');
   DrawFooter('LMB=move player   +/-=ambient darkness   F=toggle torch flicker');
   DrawPanel(SCR_W - 260, DEMO_AREA_Y + 10, 250, 180, 'Lighting');
   DrawText(PChar('Ambient: ' + IntToStr(FAmbient) + '/255'), SCR_W - 250, DEMO_AREA_Y + 34, 12, COL_TEXT);
   DrawText('4 light emitter entities', SCR_W - 250, DEMO_AREA_Y + 54, 12, COL_DIMTEXT);
   DrawText('lsCircle + additive blend', SCR_W - 250, DEMO_AREA_Y + 72, 12, COL_DIMTEXT);
   DrawPanel(SCR_W - 260, DEMO_AREA_Y + 200, 250, 210, 'Sprite Legend');
   if FTexTorch.Id > 0 then
      DrawTexturePro(FTexTorch, RectangleCreate(0, 0, 24, 36),
         RectangleCreate(SCR_W - 250, DEMO_AREA_Y + 220, 18, 27), Vector2Create(0, 0), 0, WHITE);
   DrawText('Torch', SCR_W - 228, DEMO_AREA_Y + 230, 11, COL_DIMTEXT);
   if FTexLantern.Id > 0 then
      DrawTexturePro(FTexLantern, RectangleCreate(0, 0, 20, 28),
         RectangleCreate(SCR_W - 250, DEMO_AREA_Y + 256, 16, 22), Vector2Create(0, 0), 0, WHITE);
   DrawText('Lantern', SCR_W - 228, DEMO_AREA_Y + 264, 11, COL_DIMTEXT);
   if FTexMagic.Id > 0 then
      DrawTexturePro(FTexMagic, RectangleCreate(0, 0, 24, 24),
         RectangleCreate(SCR_W - 250, DEMO_AREA_Y + 288, 20, 20), Vector2Create(0, 0), 0, WHITE);
   DrawText('Magic orb', SCR_W - 228, DEMO_AREA_Y + 295, 11, COL_DIMTEXT);
   if FTexPlayer.Id > 0 then
      DrawTexturePro(FTexPlayer, RectangleCreate(0, 0, 18, 26),
         RectangleCreate(SCR_W - 250, DEMO_AREA_Y + 320, 16, 23), Vector2Create(0, 0), 0, WHITE);
   DrawText('Player', SCR_W - 228, DEMO_AREA_Y + 328, 11, COL_DIMTEXT);
   if FTexWall.Id > 0 then
      DrawTexturePro(FTexWall, RectangleCreate(0, 0, 64, 64),
         RectangleCreate(SCR_W - 250, DEMO_AREA_Y + 356, 20, 20), Vector2Create(0, 0), 0, WHITE);
   DrawText('Wall tile', SCR_W - 228, DEMO_AREA_Y + 362, 11, COL_DIMTEXT);
end;

end.
