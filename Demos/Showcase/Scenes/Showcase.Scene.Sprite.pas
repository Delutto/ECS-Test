unit Showcase.Scene.Sprite;

{$mode objfpc}{$H+}

{ Demo 12 - Sprite Rendering and Z-Order (TZOrderRenderSystem)
  KEY CONCEPTS
  TSpriteComponent.ZOrder  - integer sort key; lower = drawn first (behind).
  TSpriteComponent.Flip    - flNone/flHorizontal/flVertical/flBoth.
  TSpriteComponent.Origin  - rotation/scale pivot in local pixel space.
  TSpriteComponent.Tint    - RGBA multiplier applied at draw time.
  TSpriteComponent.Visible - when False entity is skipped entirely.
  TSpriteComponent.OwnsTexture - True means destructor calls UnloadTexture.
  TZOrderRenderSystem      - builds a per-frame Z-buffer, sorts by ZOrder
                             (insertion sort), then calls DrawTexturePro.
  ATLAS: 128x64 CPU image with 4x 32x32 coloured tiles, generated at runtime.
  Controls: TAB=select  Z/X=ZOrder  F=flip  V=visible  T=tint  A/D=rotate  Arrows=move }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Sprite,
   P2D.Systems.ZOrderRender,
   Showcase.Common;

const
   NUM_SP = 5;

type
   TSpriteRenderDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH, FSel: Integer;
      FEntities: array[0..NUM_SP - 1] of TEntity;
      FTintIdx: array[0..NUM_SP - 1] of Integer;
      FAtlas: TTexture2D;
      FTRID, FSID: Integer;
      procedure GenAtlas;
      function GetSpr(I: Integer): TSpriteComponent;
      function GetTr(I: Integer): TTransformComponent;
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
   TINTS: array[0..4] of TColor = (
      (R: 255; G: 255; B: 255; A: 255), (R: 255; G: 100; B: 100; A: 255), (R: 100; G: 255; B: 100; A: 255),
      (R: 100; G: 160; B: 255; A: 255), (R: 255; G: 240; B: 60; A: 255));
   TNAMES: array[0..4] of String = ('WHITE', 'RED', 'GREEN', 'BLUE', 'YELLOW');
   SNAMES: array[0..NUM_SP - 1] of String = ('Star', 'Moon', 'Sun', 'Cloud', 'Tree');

constructor TSpriteRenderDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('Sprite');
   FScreenW := AW;
   FScreenH := AH;
   FSel := 0;
end;

procedure TSpriteRenderDemoScene.GenAtlas;
{ GenImageColor allocates CPU RGBA image.
  ImageDrawRectangle draws coloured tiles into it.
  LoadTextureFromImage uploads to GPU (requires GL context = after window init).
  UnloadImage frees the CPU copy — the GPU texture survives independently. }
var
   Img: TImage;
   Cols: array[0..3] of TColor;
   I, TX: Integer;
begin
   Cols[0] := ColorCreate(200, 80, 80, 255);
   Cols[1] := ColorCreate(80, 180, 80, 255);
   Cols[2] := ColorCreate(80, 120, 220, 255);
   Cols[3] := ColorCreate(220, 200, 60, 255);
   Img := GenImageColor(128, 64, ColorCreate(20, 20, 30, 255));
   for I := 0 to 3 do
   begin
      TX := I * 32;
      ImageDrawRectangle(@Img, TX + 2, 2, 28, 28, Cols[I]);
      ImageDrawRectangle(@Img, TX + 6, 6, 12, 12, ColorCreate(255, 255, 255, 80));
   end;
   FAtlas := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TSpriteRenderDemoScene.DoLoad;
begin
  { TZOrderRenderSystem priority=100, RenderLayer=rlWorld.
    Requires TSpriteComponent+TTransformComponent on entities. }
   World.AddSystem(TZOrderRenderSystem.Create(World));
end;

procedure TSpriteRenderDemoScene.DoEnter;
const
   PX: array[0..NUM_SP - 1] of Single = (100, 280, 480, 640, 800);
   PY: array[0..NUM_SP - 1] of Single = (280, 180, 300, 200, 260);
   ZO: array[0..NUM_SP - 1] of Integer = (0, 5, 10, 15, 20);
var
   I: Integer;
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
      Tr.Scale := Vector2Create(2, 2);           { 2x scale for visibility }
      E.AddComponent(Tr);
      Spr := TSpriteComponent.Create;
      Spr.Texture := FAtlas;
      Spr.OwnsTexture := False;               { scene owns atlas, freed in DoExit }
      Spr.SourceRect := RectangleCreate((I mod 4) * 32, 0, 32, 32);
      Spr.Origin := Vector2Create(16, 16); { pivot at centre of 32x32 tile }
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

function TSpriteRenderDemoScene.GetSpr(I: Integer): TSpriteComponent;
begin
   Result := TSpriteComponent(FEntities[I].GetComponentByID(FSID));
end;

function TSpriteRenderDemoScene.GetTr(I: Integer): TTransformComponent;
begin
   Result := TTransformComponent(FEntities[I].GetComponentByID(FTRID));
end;

procedure TSpriteRenderDemoScene.Update(ADelta: Single);
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
   { ZOrder: simple integer; TZOrderRenderSystem re-sorts every frame }
   if IsKeyPressed(KEY_Z) then
      Inc(Spr.ZOrder, 5);
   if IsKeyPressed(KEY_X) then
      Dec(Spr.ZOrder, 5);
   { Flip: negates SourceRect.Width before DrawTexturePro }
   if IsKeyPressed(KEY_F) then
   begin
      if Spr.Flip = flNone then
         Spr.Flip := flHorizontal
      else
         Spr.Flip := flNone;
   end;
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
   I: Integer;
   Spr: TSpriteComponent;
   Tr: TTransformComponent;
   Col: TColor;
begin
   ClearBackground(ColorCreate(18, 18, 28, 255));
   World.Render;
   DrawHeader('Demo 12 - Sprite Rendering and Z-Order (TZOrderRenderSystem)');
   DrawFooter('TAB=select  Z/X=ZOrder  F=flip  V=visible  T=tint  A/D=rotate  Arrows=move');
   DrawPanel(SCR_W - 310, DEMO_AREA_Y + 10, 300, 220, 'Selected: ' + SNAMES[FSel]);
   Spr := GetSpr(FSel);
   Tr := GetTr(FSel);
   if Assigned(Spr) then
   begin
      DrawText(PChar('ZOrder  : ' + IntToStr(Spr.ZOrder)), SCR_W - 300, DEMO_AREA_Y + 36, 12, COL_TEXT);
      DrawText(PChar('Flip    : ' + IfThen(Spr.Flip = flHorizontal, 'HORIZONTAL', 'NONE')),
         SCR_W - 300, DEMO_AREA_Y + 54, 12, COL_TEXT);
      DrawText(PChar('Visible : ' + IfThen(Spr.Visible, 'TRUE', 'FALSE')),
         SCR_W - 300, DEMO_AREA_Y + 72, 12, IfThen(Spr.Visible, COL_GOOD, COL_BAD));
      DrawText(PChar('Tint    : ' + TNAMES[FTintIdx[FSel]]), SCR_W - 300, DEMO_AREA_Y + 90, 12, COL_TEXT);
      DrawText(PChar(Format('Rotation: %.1f deg', [Tr.Rotation])), SCR_W - 300, DEMO_AREA_Y + 108, 12, COL_TEXT);
      DrawText('OwnsTexture: FALSE', SCR_W - 300, DEMO_AREA_Y + 126, 11, COL_DIMTEXT);
   end;
   DrawPanel(SCR_W - 310, DEMO_AREA_Y + 240, 300, 180, 'Z-Order Stack (back to front)');
   for I := 0 to NUM_SP - 1 do
   begin
      Spr := GetSpr(I);
      Col := IfThen(I = FSel, COL_ACCENT, COL_TEXT);
      DrawText(PChar(Format('Z=%3d  %s%s', [Spr.ZOrder, SNAMES[I], IfThen(not Spr.Visible, ' [hidden]', '')])),
         SCR_W - 300, DEMO_AREA_Y + 264 + I * 30, 12, Col);
   end;
   Tr := GetTr(FSel);
   DrawCircleLines(Round(Tr.Position.X), Round(Tr.Position.Y), 38, COL_ACCENT);
end;

end.
