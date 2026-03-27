unit Showcase.Scene.Sprite;

{$mode objfpc}{$H+}

{ Demo 12 - Sprite: 256x128 atlas with Shield/Sword/Bomb/Coin/Crown icons. }

interface

uses
   SysUtils, StrUtils, Math, raylib, P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Sprite, P2D.Systems.ZOrderRender, Showcase.Common;

const
   NUM_SP = 5;

type
   TSpriteRenderDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH, FSel: integer;
      FEntities: array[0..NUM_SP - 1] of TEntity;
      FTintIdx: array[0..NUM_SP - 1] of integer;
      FAtlas: TTexture2D;
      FTRID, FSID: integer;
      procedure GenAtlas;
      function GetSpr(I: integer): TSpriteComponent;
      function GetTr(I: integer): TTransformComponent;
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
   TW = 64;
   TH = 64;
   TINTS: array[0..4] of TColor = ((R: 255; G: 255; B: 255; A: 255), (R: 255; G: 100; B: 100; A: 255),
      (R: 100; G: 255; B: 100; A: 255), (R: 100; G: 160; B: 255; A: 255), (R: 255; G: 240; B: 60; A: 255));
   TNAMES: array[0..4] of string = ('WHITE', 'RED', 'GREEN', 'BLUE', 'YELLOW');
   SNAMES: array[0..NUM_SP - 1] of string = ('Shield', 'Sword', 'Bomb', 'Coin', 'Crown');
   TCOL: array[0..NUM_SP - 1] of integer = (0, 1, 2, 3, 0);
   TROW: array[0..NUM_SP - 1] of integer = (0, 0, 0, 0, 1);

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

constructor TSpriteRenderDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Sprite');
   FScreenW := AW;
   FScreenH := AH;
   FSel := 0;
end;

procedure TSpriteRenderDemoScene.GenAtlas;
var
   Img: TImage;

   procedure Shield(TX, TY: integer);
   begin
      ImageDrawRectangle(@Img, TX + 8, TY + 4, TW - 16, TH - 18, ColorCreate(100, 140, 220, 255));
      ImageDrawRectangle(@Img, TX + 12, TY + TH - 20, TW - 24, 16, ColorCreate(100, 140, 220, 255));
      ImageDrawRectangle(@Img, TX + TW div 2 - 4, TY + TH - 8, 8, 8, ColorCreate(100, 140, 220, 255));
      ImageDrawRectangle(@Img, TX + TW div 2 - 6, TY + 16, 12, 20, ColorCreate(255, 220, 80, 255));
      ImageDrawRectangle(@Img, TX + TW div 2 - 2, TY + 12, 4, 28, ColorCreate(255, 248, 120, 255));
      ImageDrawRectangle(@Img, TX + 10, TY + 6, TW - 20, 4, ColorCreate(255, 255, 255, 80));
   end;

   procedure Sword(TX, TY: integer);
   begin
      ImageDrawRectangle(@Img, TX + TW div 2 - 3, TY + 4, 6, TH - 26, ColorCreate(200, 210, 220, 255));
      ImageDrawRectangle(@Img, TX + 8, TY + TH - 28, TW - 16, 6, ColorCreate(200, 160, 40, 255));
      ImageDrawRectangle(@Img, TX + TW div 2 - 4, TY + TH - 22, 8, 14, ColorCreate(140, 100, 60, 255));
      ImageDrawRectangle(@Img, TX + TW div 2 - 6, TY + TH - 10, 12, 8, ColorCreate(180, 140, 60, 255));
      ImageDrawRectangle(@Img, TX + TW div 2, TY + 6, 2, TH - 28, ColorCreate(255, 255, 255, 100));
   end;

   procedure Bomb(TX, TY: integer);
   begin
      ImageDrawRectangle(@Img, TX + 8, TY + 16, TW - 16, TH - 28, ColorCreate(58, 58, 58, 255));
      ImageDrawRectangle(@Img, TX + 12, TY + 12, TW - 24, 8, ColorCreate(58, 58, 58, 255));
      ImageDrawRectangle(@Img, TX + 12, TY + TH - 20, TW - 24, 8, ColorCreate(58, 58, 58, 255));
      ImageDrawRectangle(@Img, TX + TW div 2 - 2, TY + 4, 4, 14, ColorCreate(140, 100, 60, 255));
      ImageDrawRectangle(@Img, TX + TW div 2 - 4, TY + 2, 8, 6, ColorCreate(255, 200, 60, 255));
      ImageDrawRectangle(@Img, TX + 16, TY + 20, 10, 8, ColorCreate(255, 255, 255, 60));
   end;

   procedure Coin(TX, TY: integer);
   begin
      ImageDrawRectangle(@Img, TX + 8, TY + 4, TW - 16, TH - 8, ColorCreate(220, 180, 40, 255));
      ImageDrawRectangle(@Img, TX + 4, TY + 8, TW - 8, TH - 16, ColorCreate(220, 180, 40, 255));
      ImageDrawRectangle(@Img, TX + 14, TY + 10, TW - 28, TH - 20, ColorCreate(240, 200, 60, 255));
      ImageDrawRectangle(@Img, TX + 20, TY + 18, TW - 36, TH - 36, ColorCreate(220, 180, 40, 255));
      ImageDrawRectangle(@Img, TX + 12, TY + 10, 12, 10, ColorCreate(255, 255, 255, 80));
   end;

   procedure Crown(TX, TY: integer);
   begin
      ImageDrawRectangle(@Img, TX + 4, TY + TH - 18, TW - 8, 14, ColorCreate(220, 180, 40, 255));
      ImageDrawRectangle(@Img, TX + 4, TY + 8, 12, TH - 26, ColorCreate(220, 180, 40, 255));
      ImageDrawRectangle(@Img, TX + TW div 2 - 6, TY + 4, 12, TH - 22, ColorCreate(220, 180, 40, 255));
      ImageDrawRectangle(@Img, TX + TW - 16, TY + 8, 12, TH - 26, ColorCreate(220, 180, 40, 255));
      ImageDrawRectangle(@Img, TX + 6, TY + TH - 16, 8, 8, ColorCreate(220, 60, 60, 255));
      ImageDrawRectangle(@Img, TX + TW div 2 - 4, TY + TH - 16, 8, 8, ColorCreate(80, 180, 255, 255));
      ImageDrawRectangle(@Img, TX + TW - 14, TY + TH - 16, 8, 8, ColorCreate(80, 220, 100, 255));
   end;

begin
   Img := GenImageColor(TW * 4, TH * 2, ColorCreate(18, 18, 28, 255));
   Shield(0, 0);
   Sword(TW, 0);
   Bomb(TW * 2, 0);
   Coin(TW * 3, 0);
   Crown(0, TH);
   ImageDrawRectangle(@Img, TW + 4, TH + 4, TW - 8, TH - 8, ColorCreate(140, 60, 200, 255));
   ImageDrawRectangle(@Img, TW * 2 + 8, TH + 8, TW - 16, TH - 16, ColorCreate(140, 100, 60, 255));
   ImageDrawRectangle(@Img, TW * 3 + 4, TH + 8, TW - 8, TH - 16, ColorCreate(200, 200, 180, 255));
   FAtlas := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TSpriteRenderDemoScene.DoLoad;
begin
   World.AddSystem(TZOrderRenderSystem.Create(World));
end;

procedure TSpriteRenderDemoScene.DoEnter;
const
   PX: array[0..NUM_SP - 1] of single = (120, 300, 500, 680, 860);
   PY: array[0..NUM_SP - 1] of single = (290, 200, 310, 210, 275);
   ZO: array[0..NUM_SP - 1] of integer = (0, 5, 10, 15, 20);
var
   I: integer;
   E: TEntity;
   Tr: TTransformComponent;
   Spr: TSpriteComponent;
begin
   FSel := 0;
   GenAtlas;
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FSID := ComponentRegistry.GetComponentID(TSpriteComponent);
   for I := 0 to NUM_SP - 1 do
   begin
      FTintIdx[I] := 0;
      E := World.CreateEntity(SNAMES[I]);
      Tr := TTransformComponent.Create;
      Tr.Position := Vector2Create(PX[I], PY[I]);
      Tr.Scale := Vector2Create(1.6, 1.6);
      E.AddComponent(Tr);
      Spr := TSpriteComponent.Create;
      Spr.Texture := FAtlas;
      Spr.OwnsTexture := False;
      Spr.SourceRect := RectangleCreate(TCOL[I] * TW, TROW[I] * TH, TW, TH);
      Spr.Origin := Vector2Create(TW div 2, TH div 2);
      Spr.Tint := WHITE;
      Spr.ZOrder := ZO[I];
      Spr.Visible := True;
      E.AddComponent(Spr);
      FEntities[I] := E;
   end;
   World.Init;
end;

procedure TSpriteRenderDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   if FAtlas.Id > 0 then
   begin
      UnloadTexture(FAtlas);
      FAtlas.Id := 0;
   end;
end;

function TSpriteRenderDemoScene.GetSpr(I: integer): TSpriteComponent;
begin
   Result := TSpriteComponent(FEntities[I].GetComponentByID(FSID));
end;

function TSpriteRenderDemoScene.GetTr(I: integer): TTransformComponent;
begin
   Result := TTransformComponent(FEntities[I].GetComponentByID(FTRID));
end;

procedure TSpriteRenderDemoScene.Update(ADelta: single);
var
   Spr: TSpriteComponent;
   Tr: TTransformComponent;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_TAB) then
      FSel := (FSel + 1) mod NUM_SP;
   Spr := GetSpr(FSel);
   Tr := GetTr(FSel);
   if IsKeyPressed(KEY_Z) then
      Inc(Spr.ZOrder, 5);
   if IsKeyPressed(KEY_X) then
      Dec(Spr.ZOrder, 5);
   if IsKeyPressed(KEY_F) then
      if Spr.Flip = flNone then
         Spr.Flip := flHorizontal
      else
         Spr.Flip := flNone;
   if IsKeyPressed(KEY_V) then
      Spr.Visible := not Spr.Visible;
   if IsKeyPressed(KEY_T) then
   begin
      FTintIdx[FSel] := (FTintIdx[FSel] + 1) mod 5;
      Spr.Tint := TINTS[FTintIdx[FSel]];
   end;
   if IsKeyDown(KEY_A) then
      Tr.Rotation := Tr.Rotation - 90 * ADelta;
   if IsKeyDown(KEY_D) then
      Tr.Rotation := Tr.Rotation + 90 * ADelta;
   if IsKeyDown(KEY_LEFT) then
      Tr.Position.X := Tr.Position.X - 120 * ADelta;
   if IsKeyDown(KEY_RIGHT) then
      Tr.Position.X := Tr.Position.X + 120 * ADelta;
   if IsKeyDown(KEY_UP) then
      Tr.Position.Y := Tr.Position.Y - 120 * ADelta;
   if IsKeyDown(KEY_DOWN) then
      Tr.Position.Y := Tr.Position.Y + 120 * ADelta;
   World.Update(ADelta);
end;

procedure TSpriteRenderDemoScene.Render;
var
   I: integer;
   Spr: TSpriteComponent;
   Tr: TTransformComponent;
   Col: TColor;
begin
   ClearBackground(ColorCreate(18, 18, 28, 255));
   DrawRectangleGradientV(0, DEMO_AREA_Y, SCR_W, DEMO_AREA_H, ColorCreate(24, 24, 38, 255), ColorCreate(14, 14, 22, 255));
   World.Render;
   DrawHeader('Demo 12 - Sprite Rendering and Z-Order (TZOrderRenderSystem)');
   DrawFooter('TAB=select  Z/X=ZOrder  F=flip  V=visible  T=tint  A/D=rotate  Arrows=move');
   DrawPanel(SCR_W - 318, DEMO_AREA_Y + 10, 308, 260, 'Selected: ' + SNAMES[FSel]);
   Spr := GetSpr(FSel);
   Tr := GetTr(FSel);
   if Assigned(Spr) then
   begin
      DrawTexturePro(FAtlas, RectangleCreate(TCOL[FSel] * TW, TROW[FSel] * TH, TW, TH),
         RectangleCreate(SCR_W - 80, DEMO_AREA_Y + 18, 52, 52), Vector2Create(0, 0), 0, Spr.Tint);
      DrawText(PChar('ZOrder   : ' + IntToStr(Spr.ZOrder)), SCR_W - 308, DEMO_AREA_Y + 36, 12, COL_TEXT);
      DrawText(PChar('Flip     : ' + IfStr(Spr.Flip = flHorizontal, 'HORIZONTAL', 'NONE')), SCR_W - 308, DEMO_AREA_Y + 54, 12, COL_TEXT);
      DrawText(PChar('Visible  : ' + IfStr(Spr.Visible, 'TRUE', 'FALSE')), SCR_W - 308, DEMO_AREA_Y + 72, 12, IfCol(Spr.Visible, COL_GOOD, COL_BAD));
      DrawText(PChar('Tint     : ' + TNAMES[FTintIdx[FSel]]), SCR_W - 308, DEMO_AREA_Y + 90, 12, COL_TEXT);
      DrawText(PChar(Format('Rotation : %.1f deg', [Tr.Rotation])), SCR_W - 308, DEMO_AREA_Y + 108, 12, COL_TEXT);
      DrawText('Atlas: 256x128  8 tiles  64x64', SCR_W - 308, DEMO_AREA_Y + 144, 11, COL_DIMTEXT);
   end;
   DrawPanel(SCR_W - 318, DEMO_AREA_Y + 280, 308, 90, 'Atlas Thumbnail');
   DrawTexturePro(FAtlas, RectangleCreate(0, 0, TW * 4, TH * 2), RectangleCreate(SCR_W - 308, DEMO_AREA_Y + 298, 160, 60), Vector2Create(0, 0), 0, WHITE);
   DrawRectangleLinesEx(RectangleCreate(SCR_W - 308 + TCOL[FSel] * 40, DEMO_AREA_Y + 298 + TROW[FSel] * 30, 40, 30), 2, COL_ACCENT);
   DrawPanel(SCR_W - 318, DEMO_AREA_Y + 380, 308, NUM_SP * 36 + 30, 'Z-Order Stack');
   for I := 0 to NUM_SP - 1 do
   begin
      Spr := GetSpr(I);
      Col := IfCol(I = FSel, COL_ACCENT, COL_TEXT);
      DrawTexturePro(FAtlas, RectangleCreate(TCOL[I] * TW, TROW[I] * TH, TW, TH),
         RectangleCreate(SCR_W - 308, DEMO_AREA_Y + 404 + I * 36, 28, 28), Vector2Create(0, 0), 0, IfCol(not Spr.Visible, ColorCreate(80, 80, 80, 120), WHITE));
      DrawText(PChar(Format('Z=%3d  %s%s', [Spr.ZOrder, SNAMES[I], IfStr(not Spr.Visible, ' [hidden]', '')])),
         SCR_W - 275, DEMO_AREA_Y + 410 + I * 36, 12, Col);
   end;
   Tr := GetTr(FSel);
   DrawCircleLines(Round(Tr.Position.X), Round(Tr.Position.Y), 58, COL_ACCENT);
end;

end.
