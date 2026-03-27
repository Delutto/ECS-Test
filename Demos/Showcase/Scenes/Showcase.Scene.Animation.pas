unit Showcase.Scene.Animation;

{$mode objfpc}{$H+}

{ Demo 13 - Animation: character silhouette atlas per pose. }
interface

uses
   SysUtils, StrUtils, Math, raylib, P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Sprite, P2D.Components.Animation,
   P2D.Systems.Animation, P2D.Systems.ZOrderRender, Showcase.Common;

type
   TAnimationDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FEntity: TEntity;
      FAtlas: TTexture2D;
      FPaused: boolean;
      FCurrentClip: string;
      FANID, FSID: integer;
      procedure GenAtlas;
      procedure BuildAnimations;
      function AC: TAnimationComponent;
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
   FW = 48;
   FH = 48;
   FC = 4;

function IfTStr(B: boolean; const T, F: string): string;
begin
   if B then
      Result := T
   else
      Result := F;
end;

function IfTCol(B: boolean; const T, F: TColor): TColor;
begin
   if B then
      Result := T
   else
      Result := F;
end;

function IfTInt(B: boolean; T, F: integer): integer;
begin
   if B then
      Result := T
   else
      Result := F;
end;

constructor TAnimationDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Animation');
   FScreenW := AW;
   FScreenH := AH;
   FPaused := False;
   FCurrentClip := 'idle';
end;

function TAnimationDemoScene.AC: TAnimationComponent;
begin
   Result := TAnimationComponent(FEntity.GetComponentByID(FANID));
end;

procedure TAnimationDemoScene.GenAtlas;
{ 4 rows x 4 cols of FW x FH.  Each row = one animation clip pose. }
var
   Img: TImage;
   Row, Col, TX, TY, LO, BO: integer;
   RC, ACC: array[0..3] of TColor;
begin
   RC[0] := ColorCreate(70, 110, 180, 255);
   RC[1] := ColorCreate(60, 150, 80, 255);
   RC[2] := ColorCreate(200, 120, 40, 255);
   RC[3] := ColorCreate(190, 60, 60, 255);
   ACC[0] := ColorCreate(80, 160, 255, 255);
   ACC[1] := ColorCreate(80, 220, 100, 255);
   ACC[2] := ColorCreate(255, 180, 60, 255);
   ACC[3] := ColorCreate(220, 60, 60, 255);
   Img := GenImageColor(FW * FC, FH * 4, ColorCreate(14, 14, 24, 255));
   for Row := 0 to 3 do
      for Col := 0 to FC - 1 do
      begin
         TX := Col * FW;
         TY := Row * FH;
         case Row of
            0:
            begin
               LO := 0;
               BO := 0;
            end;
            1:
            begin
               LO := IfTInt(Col mod 2 = 0, 4, -4);
               BO := 0;
            end;
            2:
            begin
               LO := IfTInt(Col mod 2 = 0, 6, -6);
               BO := -2;
            end;
            3:
            begin
               LO := -2 + Col * 2;
               BO := -4 + Col * 2;
            end;
            else
            begin
               LO := 0;
               BO := 0;
            end;
         end;
         ImageDrawRectangle(@Img, TX + FW div 2 - 8, TY + 4 + BO, 16, 14, ColorCreate(220, 190, 160, 255));
         ImageDrawRectangle(@Img, TX + FW div 2 - 10, TY + 18 + BO, 20, 16, RC[Row]);
         ImageDrawRectangle(@Img, TX + FW div 2 - 8, TY + 20 + BO, 4, 12, ColorCreate(255, 255, 255, 60));
         ImageDrawRectangle(@Img, TX + FW div 2 - 9, TY + 34 + BO, 8, Max(3, 10 + LO), ACC[Row]);
         ImageDrawRectangle(@Img, TX + FW div 2 + 1, TY + 34 + BO, 8, Max(3, 10 - LO), ACC[Row]);
         ImageDrawRectangle(@Img, TX + 2, TY + 2, 6, 6, ACC[Row]);
         if Row = 0 then
            ImageDrawRectangle(@Img, TX + 2, TY + 2, FW - 4, FH - 4, ColorCreate(255, 255, 255, 8 * Col));
      end;
   FAtlas := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TAnimationDemoScene.BuildAnimations;
var
   Anim: TAnimationComponent;
   A: TAnimation;
   Col: integer;
begin
   Anim := TAnimationComponent(FEntity.GetComponentByID(FANID));
   A := TAnimation.Create('idle', True);
   for Col := 0 to FC - 1 do
      A.AddFrame(RectangleCreate(Col * FW, 0, FW, FH), 0.40);
   Anim.AddAnimation(A);
   A := TAnimation.Create('walk', True);
   for Col := 0 to FC - 1 do
      A.AddFrame(RectangleCreate(Col * FW, FH, FW, FH), 0.15);
   Anim.AddAnimation(A);
   A := TAnimation.Create('run', True);
   for Col := 0 to FC - 1 do
      A.AddFrame(RectangleCreate(Col * FW, FH * 2, FW, FH), 0.07);
   Anim.AddAnimation(A);
   A := TAnimation.Create('jump', False);
   for Col := 0 to FC - 1 do
      A.AddFrame(RectangleCreate(Col * FW, FH * 3, FW, FH), 0.12);
   Anim.AddAnimation(A);
end;

procedure TAnimationDemoScene.DoLoad;
begin
   World.AddSystem(TAnimationSystem.Create(World));
   World.AddSystem(TZOrderRenderSystem.Create(World));
end;

procedure TAnimationDemoScene.DoEnter;
var
   Tr: TTransformComponent;
   Spr: TSpriteComponent;
   Anim: TAnimationComponent;
begin
   FPaused := False;
   FCurrentClip := 'idle';
   GenAtlas;
   FANID := ComponentRegistry.GetComponentID(TAnimationComponent);
   FSID := ComponentRegistry.GetComponentID(TSpriteComponent);
   FEntity := World.CreateEntity('AnimSprite');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(DEMO_AREA_CX - FW * 3 div 2, DEMO_AREA_CY - FH * 3 div 2);
   Tr.Scale := Vector2Create(3, 3);
   FEntity.AddComponent(Tr);
   Spr := TSpriteComponent.Create;
   Spr.Texture := FAtlas;
   Spr.OwnsTexture := False;
   Spr.SourceRect := RectangleCreate(0, 0, FW, FH);
   FEntity.AddComponent(Spr);
   Anim := TAnimationComponent.Create;
   FEntity.AddComponent(Anim);
   World.Init;
   BuildAnimations;
   AC.Play('idle');
end;

procedure TAnimationDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   if FAtlas.Id > 0 then
   begin
      UnloadTexture(FAtlas);
      FAtlas.Id := 0;
   end;
end;

procedure TAnimationDemoScene.Update(ADelta: single);
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_ONE) then
   begin
      AC.Play('idle');
      FCurrentClip := 'idle';
   end;
   if IsKeyPressed(KEY_TWO) then
   begin
      AC.Play('walk');
      FCurrentClip := 'walk';
   end;
   if IsKeyPressed(KEY_THREE) then
   begin
      AC.Play('run');
      FCurrentClip := 'run';
   end;
   if IsKeyPressed(KEY_FOUR) then
   begin
      AC.Play('jump');
      FCurrentClip := 'jump';
   end;
   if IsKeyPressed(KEY_F) then
      AC.Play(FCurrentClip, True);
   if IsKeyPressed(KEY_SPACE) then
      FPaused := not FPaused;
   if FPaused then
      World.Update(0)
   else
      World.Update(ADelta);
end;

procedure TAnimationDemoScene.Render;
var
   A: TAnimationComponent;
   RH: integer;
begin
   ClearBackground(ColorCreate(16, 16, 26, 255));
   DrawRectangleGradientV(0, DEMO_AREA_Y, SCR_W, DEMO_AREA_H, ColorCreate(20, 20, 34, 255), ColorCreate(12, 12, 20, 255));
   World.Render;
   DrawHeader('Demo 13 - Animation System (TAnimationSystem + TAnimationComponent)');
   DrawFooter('1=idle  2=walk  3=run  4=jump(one-shot)  F=force-restart  SPACE=pause');
   A := AC;
   DrawPanel(30, DEMO_AREA_Y + 10, 320, 200, 'Animation State');
   DrawText(PChar('Clip    : ' + A.CurrentName), 42, DEMO_AREA_Y + 34, 13, COL_ACCENT);
   DrawText(PChar('Frame   : ' + IntToStr(A.FrameIndex)), 42, DEMO_AREA_Y + 54, 12, COL_TEXT);
   DrawText(PChar('Finished: ' + IfTStr(A.Finished, 'YES (one-shot ended)', 'no')), 42, DEMO_AREA_Y + 72, 12, IfTCol(A.Finished, COL_WARN, COL_GOOD));
   DrawText(PChar('Paused  : ' + IfTStr(FPaused, 'YES', 'no')), 42, DEMO_AREA_Y + 90, 12, IfTCol(FPaused, COL_BAD, COL_TEXT));
   DrawPanel(30, DEMO_AREA_Y + 220, 320, 210, 'Atlas Preview (4 rows x 4 cols, 48x48)');
   DrawTexturePro(FAtlas, RectangleCreate(0, 0, FW * FC, FH * 4), RectangleCreate(40, DEMO_AREA_Y + 244, FW * FC div 2 + 4, FH * 4 div 2 + 4), Vector2Create(0, 0), 0, WHITE);
   if A.CurrentName = 'idle' then
      RH := 0
   else
   if A.CurrentName = 'walk' then
      RH := 1
   else
   if A.CurrentName = 'run' then
      RH := 2
   else
      RH := 3;
   DrawRectangleLinesEx(
      RectangleCreate(40, DEMO_AREA_Y + 244 + RH * (FH div 2 + 1), FW * FC div 2 + 4, FH div 2 + 2), 2, COL_ACCENT);
   DrawPanel(30, DEMO_AREA_Y + 440, 320, 110, 'Clips Defined');
   DrawText('idle  Loop=True  4 fr  0.40 s', 42, DEMO_AREA_Y + 462, 11, COL_TEXT);
   DrawText('walk  Loop=True  4 fr  0.15 s', 42, DEMO_AREA_Y + 480, 11, COL_TEXT);
   DrawText('run   Loop=True  4 fr  0.07 s', 42, DEMO_AREA_Y + 498, 11, COL_TEXT);
   DrawText('jump  Loop=False 4 fr  0.12 s', 42, DEMO_AREA_Y + 516, 11, COL_TEXT);
   DrawPanel(SCR_W - 330, DEMO_AREA_Y + 10, 320, 160, 'Pipeline');
   DrawText('TAnimationSystem.Update(dt)', SCR_W - 320, DEMO_AREA_Y + 34, 11, COL_ACCENT);
   DrawText('  Anim.Tick(dt,Rect)', SCR_W - 320, DEMO_AREA_Y + 52, 11, COL_TEXT);
   DrawText('  Spr.SourceRect:=Rect', SCR_W - 320, DEMO_AREA_Y + 70, 11, COL_TEXT);
   DrawText('TZOrderRenderSystem.Render', SCR_W - 320, DEMO_AREA_Y + 88, 11, COL_ACCENT);
   DrawText('  DrawTexturePro(Spr,...)', SCR_W - 320, DEMO_AREA_Y + 106, 11, COL_TEXT);
end;

end.
