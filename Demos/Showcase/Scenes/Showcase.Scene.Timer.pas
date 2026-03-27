unit Showcase.Scene.Timer;

{$mode objfpc}{$H+}

{ Demo 19 - Timer  NEW: 28x28 icon per timer (sword/heart/skull). }
interface

uses
   SysUtils, Math, raylib, P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Timer, P2D.Systems.Timer, Showcase.Common;

type
   TTimerDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FEntity: TEntity;
      FTimerSys: TTimerSystem2D;
      FTMID: integer;
      FFireLog: array[0..9] of string;
      FFireN, FTotalFires: integer;
      FIcoSword, FIcoHeart, FIcoSkull: TTexture2D;
      procedure GenIcons;
      procedure FreeIcons;
      procedure OnTimerFired(const AName: string);
      procedure LogFire(const S: string);
      function TC: TTimerComponent2D;
      procedure DrawTimerBar(const AName: string; AX, AY, AW: integer; const ALabel: string; AIco: TTexture2D);
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

constructor TTimerDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Timer');
   FScreenW := AW;
   FScreenH := AH;
   FTotalFires := 0;
end;

function TTimerDemoScene.TC: TTimerComponent2D;
begin
   Result := TTimerComponent2D(FEntity.GetComponentByID(FTMID));
end;

procedure TTimerDemoScene.GenIcons;
var
   Img: TImage;
begin
   Img := GenImageColor(28, 28, ColorCreate(28, 28, 42, 255));
   ImageDrawRectangle(@Img, 12, 2, 4, 18, ColorCreate(190, 200, 210, 255));
   ImageDrawRectangle(@Img, 6, 8, 16, 4, ColorCreate(190, 200, 210, 255));
   ImageDrawRectangle(@Img, 11, 20, 6, 6, ColorCreate(140, 100, 60, 255));
   FIcoSword := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(28, 28, ColorCreate(28, 28, 42, 255));
   ImageDrawRectangle(@Img, 4, 6, 8, 8, ColorCreate(220, 55, 55, 255));
   ImageDrawRectangle(@Img, 16, 6, 8, 8, ColorCreate(220, 55, 55, 255));
   ImageDrawRectangle(@Img, 2, 10, 24, 10, ColorCreate(220, 55, 55, 255));
   ImageDrawRectangle(@Img, 6, 20, 16, 6, ColorCreate(220, 55, 55, 255));
   ImageDrawRectangle(@Img, 10, 24, 8, 2, ColorCreate(220, 55, 55, 255));
   FIcoHeart := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(28, 28, ColorCreate(28, 28, 42, 255));
   ImageDrawRectangle(@Img, 6, 4, 16, 14, ColorCreate(200, 196, 188, 255));
   ImageDrawRectangle(@Img, 4, 10, 20, 12, ColorCreate(200, 196, 188, 255));
   ImageDrawRectangle(@Img, 6, 20, 16, 4, ColorCreate(200, 196, 188, 255));
   ImageDrawRectangle(@Img, 7, 21, 4, 4, ColorCreate(28, 28, 42, 255));
   ImageDrawRectangle(@Img, 17, 21, 4, 4, ColorCreate(28, 28, 42, 255));
   ImageDrawRectangle(@Img, 8, 9, 5, 6, ColorCreate(28, 28, 42, 255));
   ImageDrawRectangle(@Img, 15, 9, 5, 6, ColorCreate(28, 28, 42, 255));
   FIcoSkull := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TTimerDemoScene.FreeIcons;

   procedure U(var T: TTexture2D);
   begin
      if T.Id > 0 then
      begin
         UnloadTexture(T);
         T.Id := 0;
      end;
   end;

begin
   U(FIcoSword);
   U(FIcoHeart);
   U(FIcoSkull);
end;

procedure TTimerDemoScene.LogFire(const S: string);
var
   I: integer;
begin
   Inc(FTotalFires);
   if FFireN < 10 then
   begin
      FFireLog[FFireN] := S;
      Inc(FFireN);
   end
   else
   begin
      for I := 0 to 8 do
         FFireLog[I] := FFireLog[I + 1];
      FFireLog[9] := S;
   end;
end;

procedure TTimerDemoScene.OnTimerFired(const AName: string);
begin
   LogFire(Format('[FIRED] %s  (total=%d)', [AName, FTotalFires + 1]));
end;

procedure TTimerDemoScene.DoLoad;
begin
   FTimerSys := TTimerSystem2D(World.AddSystem(TTimerSystem2D.Create(World)));
end;

procedure TTimerDemoScene.DoEnter;
var
   Tr: TTransformComponent;
   T: TTimerComponent2D;
begin
   FFireN := 0;
   FTotalFires := 0;
   FTMID := ComponentRegistry.GetComponentID(TTimerComponent2D);
   FEntity := World.CreateEntity('TimerEntity');
   Tr := TTransformComponent.Create;
   FEntity.AddComponent(Tr);
   T := TTimerComponent2D.Create;
   T.Start('CoolDown', 3.0, False, @OnTimerFired);
   T.Start('Regen', 1.0, True, @OnTimerFired);
   T.Start('Boss', 5.0, False, @OnTimerFired);
   FEntity.AddComponent(T);
   GenIcons;
   World.Init;
   LogFire('Demo started – timers running.');
end;

procedure TTimerDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FreeIcons;
end;

procedure TTimerDemoScene.DrawTimerBar(const AName: string; AX, AY, AW: integer; const ALabel: string; AIco: TTexture2D);
var
   T: TTimerComponent2D;
   Prog: single;
   vActive: boolean;
   FillW: integer;
   BarCol: TColor;
   RemStr: string;
begin
   T := TC;
   vActive := T.IsActive(AName);
   Prog := T.Progress(AName);
   FillW := Round(AW * Prog);
   BarCol := ColorCreate(Round(255 * Prog), Round(255 * (1 - Prog)), 60, 255);
   if not vActive then
      BarCol := COL_DIMTEXT;
   if AIco.Id > 0 then
      DrawTexturePro(AIco, RectangleCreate(0, 0, 28, 28),
         RectangleCreate(AX - 38, AY - 2, 28, 28), Vector2Create(0, 0), 0, IfCol(vActive, WHITE, ColorCreate(100, 100, 100, 160)));
   DrawText(PChar(ALabel), AX, AY - 16, 12, IfCol(vActive, COL_TEXT, COL_DIMTEXT));
   DrawRectangle(AX, AY, AW, 20, ColorCreate(38, 38, 54, 255));
   if FillW > 0 then
      DrawRectangle(AX, AY, FillW, 20, BarCol);
   DrawRectangleLinesEx(RectangleCreate(AX, AY, AW, 20), 1, COL_DIMTEXT);
   if vActive then
      RemStr := Format('%.2f s left  (%.0f%%)', [T.Remaining(AName), Prog * 100])
   else
      RemStr := 'STOPPED / EXPIRED';
   DrawText(PChar(RemStr), AX + 6, AY + 4, 11, IfCol(vActive, WHITE, COL_DIMTEXT));
end;

procedure TTimerDemoScene.Update(ADelta: single);
var
   T: TTimerComponent2D;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   T := TC;
   if IsKeyPressed(KEY_ONE) then
      T.Start('CoolDown', 3.0, False, @OnTimerFired);
   if IsKeyPressed(KEY_TWO) then
      T.Start('Regen', 1.0, True, @OnTimerFired);
   if IsKeyPressed(KEY_THREE) then
      T.Start('Boss', 5.0, False, @OnTimerFired);
   if IsKeyPressed(KEY_S) then
   begin
      T.Stop('CoolDown');
      T.Stop('Regen');
      T.Stop('Boss');
      LogFire('[STOP] All timers stopped.');
   end;
   World.Update(ADelta);
end;

procedure TTimerDemoScene.Render;
const
   BAR_W = 480;
   BX = 100;
var
   I: integer;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 19 - Timer Component (TTimerComponent2D + TTimerSystem2D)');
   DrawFooter('1=CoolDown(3s)  2=Regen(1s repeat)  3=Boss(5s)  S=stop all');
   DrawPanel(BX - 50, DEMO_AREA_Y + 20, BAR_W + 60, 280, 'Active Timers');
   DrawTimerBar('CoolDown', BX, DEMO_AREA_Y + 60, BAR_W, 'CoolDown  (one-shot, 3.0 s)', FIcoSword);
   DrawTimerBar('Regen', BX, DEMO_AREA_Y + 120, BAR_W, 'Regen     (repeating, 1.0 s)', FIcoHeart);
   DrawTimerBar('Boss', BX, DEMO_AREA_Y + 180, BAR_W, 'Boss      (one-shot, 5.0 s)', FIcoSkull);
   DrawPanel(BX - 50, DEMO_AREA_Y + 310, BAR_W + 60, 240, 'Event Log (OnFired callbacks)');
   for I := 0 to FFireN - 1 do
      DrawText(PChar(FFireLog[I]), BX, DEMO_AREA_Y + 334 + I * 22, 11,
         IfCol(Pos('[FIRED]', FFireLog[I]) > 0, COL_GOOD, COL_DIMTEXT));
end;

end.
