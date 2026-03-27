unit Showcase.Scene.Tween;

{$mode objfpc}{$H+}

{ Demo 20 - Tween }
interface

uses
   SysUtils, StrUtils, Math, raylib, P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Tween, P2D.Systems.Tween, Showcase.Common;

const
   NUM_TW = 6;

type
   TTweenDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FEntity: TEntity;
      FTweenSys: TTweenSystem2D;
      FTRID, FTWID: integer;
      FPingPong: boolean;
      FValues: array[0..NUM_TW - 1] of single;
      FBalls: array[0..NUM_TW - 1] of TTexture2D;
      FRailTex: TTexture2D;
      procedure GenTextures;
      procedure FreeTextures;
      procedure StartAllTweens;
      function TW: TTweenComponent2D;
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
   TW_NAMES: array[0..NUM_TW - 1] of string = ('Linear', 'InQuad', 'OutQuad', 'InOutQuad', 'OutBounce', 'OutElastic');
   TW_COLS: array[0..NUM_TW - 1] of TColor = (
      (R: 180; G: 180; B: 180; A: 255), (R: 255; G: 100; B: 100; A: 255), (R: 100; G: 220; B: 100; A: 255),
      (R: 100; G: 160; B: 255; A: 255), (R: 255; G: 180; B: 60; A: 255), (R: 200; G: 80; B: 220; A: 255));
   TW_FUNCS: array[0..NUM_TW - 1] of TEasingFunc =
      (@EaseLinear, @EaseInQuad, @EaseOutQuad, @EaseInOutQuad, @EaseOutBounce, @EaseOutElastic);

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

constructor TTweenDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Tween');
   FScreenW := AW;
   FScreenH := AH;
   FPingPong := False;
end;

function TTweenDemoScene.TW: TTweenComponent2D;
begin
   Result := TTweenComponent2D(FEntity.GetComponentByID(FTWID));
end;

procedure TTweenDemoScene.GenTextures;
var
   Img: TImage;
   I: integer;
   C: TColor;
begin
   for I := 0 to NUM_TW - 1 do
   begin
      C := TW_COLS[I];
      Img := GenImageColor(20, 20, ColorCreate(0, 0, 0, 0));
      ImageDrawRectangle(@Img, 2, 0, 16, 20, C);
      ImageDrawRectangle(@Img, 0, 2, 20, 16, C);
      ImageDrawRectangle(@Img, 0, 0, 4, 4, ColorCreate(0, 0, 0, 0));
      ImageDrawRectangle(@Img, 16, 0, 4, 4, ColorCreate(0, 0, 0, 0));
      ImageDrawRectangle(@Img, 0, 16, 4, 4, ColorCreate(0, 0, 0, 0));
      ImageDrawRectangle(@Img, 16, 16, 4, 4, ColorCreate(0, 0, 0, 0));
      ImageDrawRectangle(@Img, 5, 4, 5, 4, ColorCreate(255, 255, 255, 120));
      FBalls[I] := LoadTextureFromImage(Img);
      UnloadImage(Img);
   end;
   Img := GenImageColor(200, 4, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 0, 1, 200, 2, ColorCreate(80, 80, 96, 200));
   ImageDrawRectangle(@Img, 0, 0, 200, 1, ColorCreate(110, 110, 130, 200));
   FRailTex := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TTweenDemoScene.FreeTextures;

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
   for I := 0 to NUM_TW - 1 do
      U(FBalls[I]);
   U(FRailTex);
end;

procedure TTweenDemoScene.StartAllTweens;
var
   I: integer;
   T: TTweenComponent2D;
begin
   T := TW;
   for I := 0 to NUM_TW - 1 do
   begin
      FValues[I] := 0;
      T.Start(TW_NAMES[I], @FValues[I], 0.0, 1.0, 2.0, TW_FUNCS[I], True, FPingPong, nil);
   end;
end;

procedure TTweenDemoScene.DoLoad;
begin
   FTweenSys := TTweenSystem2D(World.AddSystem(TTweenSystem2D.Create(World)));
end;

procedure TTweenDemoScene.DoEnter;
var
   Tr: TTransformComponent;
   TW2: TTweenComponent2D;
   I: integer;
begin
   FPingPong := False;
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FTWID := ComponentRegistry.GetComponentID(TTweenComponent2D);
   for I := 0 to NUM_TW - 1 do
      FValues[I] := 0;
   FEntity := World.CreateEntity('TweenEntity');
   Tr := TTransformComponent.Create;
   FEntity.AddComponent(Tr);
   TW2 := TTweenComponent2D.Create;
   FEntity.AddComponent(TW2);
   GenTextures;
   World.Init;
   StartAllTweens;
end;

procedure TTweenDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FreeTextures;
end;

procedure TTweenDemoScene.Update(ADelta: single);
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_SPACE) then
      StartAllTweens;
   if IsKeyPressed(KEY_P) then
   begin
      FPingPong := not FPingPong;
      StartAllTweens;
   end;
   World.Update(ADelta);
end;

procedure TTweenDemoScene.Render;
const
   TH = 62;
   BY = DEMO_AREA_Y + 36;
   BX = 190;
   BW = 650;
   BALL = 20;
var
   I, TY, DotX, RX: integer;
   Prog: single;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 20 - Tween and Easing (TTweenComponent2D + TTweenSystem2D)');
   DrawFooter('SPACE=restart all   P=toggle ping-pong');
   for I := 0 to NUM_TW - 1 do
   begin
      TY := BY + I * TH;
      Prog := FValues[I];
      DotX := BX + Round(Prog * BW);
      DrawText(PChar(TW_NAMES[I]), 10, TY + 14, 13, TW_COLS[I]);
      if FRailTex.Id > 0 then
      begin
         RX := BX;
         while RX < BX + BW do
         begin
            DrawTexturePro(FRailTex, RectangleCreate(0, 0, 200, 4),
               RectangleCreate(RX, TY + BALL div 2 + 5, Min(200, BX + BW - RX), 4), Vector2Create(0, 0), 0, WHITE);
            Inc(RX, 200);
         end;
      end
      else
         DrawLine(BX, TY + BALL div 2 + 4, BX + BW, TY + BALL div 2 + 4, COL_DIMTEXT);
      if FBalls[I].Id > 0 then
         DrawTexturePro(FBalls[I], RectangleCreate(0, 0, BALL, BALL),
            RectangleCreate(DotX - BALL div 2, TY, BALL, BALL), Vector2Create(0, 0), 0, WHITE)
      else
      begin
         DrawCircle(DotX, TY + BALL div 2, BALL div 2, TW_COLS[I]);
         DrawCircleLines(DotX, TY + BALL div 2, BALL div 2 + 2, COL_DIMTEXT);
      end;
      DrawText(PChar(Format('%.0f%%', [Prog * 100])), BX + BW + 10, TY + 10, 12, COL_TEXT);
   end;
   DrawPanel(10, DEMO_AREA_Y + 408, 400, 148, 'Code Pattern');
   DrawText('TC.Start(''name'',@MyVar,0.0,1.0,', 22, DEMO_AREA_Y + 432, 11, COL_TEXT);
   DrawText('         2.0,@EaseOutBounce,', 22, DEMO_AREA_Y + 448, 11, COL_TEXT);
   DrawText('         Loop=True,PingPong=False);', 22, DEMO_AREA_Y + 464, 11, COL_TEXT);
   DrawText('-> TTweenSystem2D writes eased value', 22, DEMO_AREA_Y + 484, 11, COL_DIMTEXT);
   DrawText('   directly into MyVar each frame.', 22, DEMO_AREA_Y + 500, 11, COL_DIMTEXT);
   DrawPanel(430, DEMO_AREA_Y + 408, 290, 90, 'PingPong');
   DrawText(PChar('PingPong: ' + IfStr(FPingPong, 'ON', 'OFF')), 442, DEMO_AREA_Y + 432, 13, IfCol(FPingPong, COL_GOOD, COL_DIMTEXT));
   DrawText('Swaps From <-> To each loop.', 442, DEMO_AREA_Y + 452, 11, COL_DIMTEXT);
end;

end.
