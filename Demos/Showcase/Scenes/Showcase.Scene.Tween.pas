unit Showcase.Scene.Tween;

{$mode objfpc}{$H+}

{ Demo 20 - Tween and Easing (TTweenComponent2D + TTweenSystem2D)
  TTweenSystem2D (prio 3): calls TC.Tick(dt, EntityID) each frame.
  Tick advances Elapsed, computes EasedT = Easing(T), writes
  StartVal + (EndVal-StartVal)*EasedT directly into *Target (PSingle).
  Loop=True: resets Elapsed on completion.
  PingPong=True+Loop: swaps StartVal<->EndVal each loop.
  Built-in easings: EaseLinear, EaseInQuad, EaseOutQuad,
    EaseInOutQuad, EaseOutBounce, EaseOutElastic.
  Controls: SPACE=restart all  P=toggle ping-pong }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Tween,
   P2D.Systems.Tween,
   Showcase.Common;

const
   NUM_TW = 6;

type
   TTweenDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FEntity: TEntity;
      FTweenSys: TTweenSystem2D;
      FTRID, FTWID: Integer;
      FPingPong: boolean;
      FValues: array[0..NUM_TW - 1] of Single;
      procedure StartAllTweens;
      function TW: TTweenComponent2D;
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
   TW_NAMES: array[0..NUM_TW - 1] of String = ('Linear', 'InQuad', 'OutQuad', 'InOutQuad', 'OutBounce', 'OutElastic');
   TW_COLS: array[0..NUM_TW - 1] of TColor = (
      (R: 180; G: 180; B: 180; A: 255), (R: 255; G: 100; B: 100; A: 255), (R: 100; G: 220; B: 100; A: 255),
      (R: 100; G: 160; B: 255; A: 255), (R: 255; G: 180; B: 60; A: 255), (R: 200; G: 80; B: 220; A: 255));
   TW_FUNCS: array[0..NUM_TW - 1] of TEasingFunc = (@EaseLinear, @EaseInQuad, @EaseOutQuad, @EaseInOutQuad, @EaseOutBounce, @EaseOutElastic);

constructor TTweenDemoScene.Create(AW, AH: Integer);
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

procedure TTweenDemoScene.StartAllTweens;
var
   I: Integer;
   T: TTweenComponent2D;
begin
   T := TW;
   for I := 0 to NUM_TW - 1 do
   begin
      FValues[I] := 0;
      { Pass address of FValues[I]; tween writes eased value directly into it }
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
   I: Integer;
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
   World.Init;
   StartAllTweens;
end;

procedure TTweenDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TTweenDemoScene.Update(ADelta: Single);
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
   TH = 56;
   BY = DEMO_AREA_Y + 40;
   BX = 200;
   BW = 650;
   DR = 8;
var
   I, TY, DotX: Integer;
   Prog: Single;
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
      DrawLine(BX, TY + DR + 8, BX + BW, TY + DR + 8, COL_DIMTEXT);
      DrawCircle(DotX, TY + DR + 8, DR, TW_COLS[I]);
      DrawCircleLines(DotX, TY + DR + 8, DR + 2, COL_DIMTEXT);
      DrawText(PChar(Format('%.0f%%', [Prog * 100])), BX + BW + 10, TY + 10, 12, COL_TEXT);
   end;
   DrawPanel(10, DEMO_AREA_Y + 390, 400, 140, 'Code Pattern');
   DrawText('TC.Start(''name'', @MyVar, 0.0, 1.0,', 22, DEMO_AREA_Y + 414, 11, COL_TEXT);
   DrawText('         2.0, @EaseOutBounce,', 22, DEMO_AREA_Y + 430, 11, COL_TEXT);
   DrawText('         Loop=True, PingPong=False);', 22, DEMO_AREA_Y + 446, 11, COL_TEXT);
   DrawText('-> TTweenSystem2D writes eased value', 22, DEMO_AREA_Y + 466, 11, COL_DIMTEXT);
   DrawText('   directly into MyVar each frame.', 22, DEMO_AREA_Y + 482, 11, COL_DIMTEXT);
   DrawPanel(430, DEMO_AREA_Y + 390, 280, 80, 'PingPong');
   DrawText(PChar('PingPong: ' + IfThen(FPingPong, 'ON', 'OFF')), 442, DEMO_AREA_Y + 414, 13, IfThen(FPingPong, COL_GOOD, COL_DIMTEXT));
   DrawText('Swaps From<->To each loop.', 442, DEMO_AREA_Y + 434, 11, COL_DIMTEXT);
end;

end.
