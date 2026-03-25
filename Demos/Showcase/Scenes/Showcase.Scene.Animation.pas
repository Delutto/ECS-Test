unit Showcase.Scene.Animation;

{$mode objfpc}{$H+}

{ Demo 13 - Animation System (TAnimationSystem + TAnimationComponent)
  PIPELINE EACH FRAME
  TAnimationSystem.Update(dt)
    For every entity with both TAnimationComponent + TSpriteComponent:
      1. Anim.Tick(dt, Rect)   - advance frame timer, handle loop/one-shot,
                                 write current atlas rectangle into Rect.
      2. Spr.SourceRect := Rect - sprite now shows the correct frame.
  TZOrderRenderSystem.Render   - draws the sprite with updated SourceRect.

  TAnimation: named clip holding TAnimFrame array (SourceRect+Duration).
  Loop=False: Finished becomes True at last frame (one-shot).
  Play(Name, ForceRestart): switch clip; ForceRestart resets to frame 0.

  ATLAS: 4 rows x 4 cols of 48x48 tiles; row=clip, col=frame.
  Controls: 1=idle  2=walk  3=run  4=jump  F=force-restart  SPACE=pause }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Sprite, P2D.Components.Animation,
   P2D.Systems.Animation, P2D.Systems.ZOrderRender,
   Showcase.Common;

type
   TAnimationDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FEntity: TEntity;
      FAtlas: TTexture2D;
      FPaused: boolean;
      FCurrentClip: String;
      FANID, FSID: Integer;
      procedure GenAtlas;
      procedure BuildAnimations;
      function AC: TAnimationComponent;
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
   FW = 48;
   FH = 48;
   FC = 4;

constructor TAnimationDemoScene.Create(AW, AH: Integer);
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
{ 4 rows x 4 cols of FW x FH tiles.  Colour shifts rightward per column. }
var
   Img: TImage;
   Row, Col: Integer;
   TX, TY: Integer;
   RB: array[0..3] of TColor;
   C: TColor;
begin
   RB[0] := ColorCreate(80, 180, 255, 255);
   RB[1] := ColorCreate(80, 220, 100, 255);
   RB[2] := ColorCreate(255, 160, 60, 255);
   RB[3] := ColorCreate(220, 80, 80, 255);
   Img := GenImageColor(FW * FC, FH * 4, ColorCreate(10, 10, 20, 255));
   for Row := 0 to 3 do
      for Col := 0 to FC - 1 do
      begin
         TX := Col * FW;
         TY := Row * FH;
         C := ColorCreate(Round(RB[Row].R * (0.6 + 0.4 * Col / Max(1, FC - 1))), Round(RB[Row].G * (0.6 + 0.4 * Col / Max(1, FC - 1))), Round(RB[Row].B * (0.6 + 0.4 * Col / Max(1, FC - 1))), 255);
         ImageDrawRectangle(@Img, TX + 4, TY + 4, FW - 8, FH - 8, C);
         ImageDrawRectangle(@Img, TX + 4 + Col * 8, TY + FH - 12, 6, 6, ColorCreate(255, 255, 255, 200));
      end;
   FAtlas := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TAnimationDemoScene.BuildAnimations;
{ TAnimation is created with Create(Name, Loop).
  AddFrame(SourceRect, Duration) appends one TAnimFrame.
  TAnimationComponent.AddAnimation stores the clip in its map. }
var
   Anim: TAnimationComponent;
   A: TAnimation;
   Col: Integer;
begin
   Anim := TAnimationComponent(FEntity.GetComponentByID(FANID));
   { idle: 1 frame, loops }
   A := TAnimation.Create('idle', True);
   A.AddFrame(RectangleCreate(0, 0, FW, FH), 0.5);
   Anim.AddAnimation(A);
   { walk: 4 frames at 0.15 s, loops }
   A := TAnimation.Create('walk', True);
   for Col := 0 to FC - 1 do
      A.AddFrame(RectangleCreate(Col * FW, FH, FW, FH), 0.15);
   Anim.AddAnimation(A);
   { run: 4 frames at 0.07 s (twice walk speed), loops }
   A := TAnimation.Create('run', True);
   for Col := 0 to FC - 1 do
      A.AddFrame(RectangleCreate(Col * FW, FH * 2, FW, FH), 0.07);
   Anim.AddAnimation(A);
   { jump: 4 frames, NOT looping — Finished=True after last frame }
   A := TAnimation.Create('jump', False);
   for Col := 0 to FC - 1 do
      A.AddFrame(RectangleCreate(Col * FW, FH * 3, FW, FH), 0.12);
   Anim.AddAnimation(A);
end;

procedure TAnimationDemoScene.DoLoad;
begin
   World.AddSystem(TAnimationSystem.Create(World));    { prio 5  — before render }
   World.AddSystem(TZOrderRenderSystem.Create(World)); { prio 100 }
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
   Tr.Position := Vector2Create(DEMO_AREA_CX - 72, DEMO_AREA_CY - 72);
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

procedure TAnimationDemoScene.Update(ADelta: Single);
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
   { ForceRestart=True: re-plays even if the clip is already active }
   if IsKeyPressed(KEY_F) then
      AC.Play(FCurrentClip, True);
   if IsKeyPressed(KEY_SPACE) then
      FPaused := not FPaused;
   { Pass 0 delta when paused so Tick does not advance }
   if FPaused then
      World.Update(0)
   else
      World.Update(ADelta);
end;

procedure TAnimationDemoScene.Render;
var
   A: TAnimationComponent;
begin
   ClearBackground(ColorCreate(18, 18, 28, 255));
   World.Render;
   DrawHeader('Demo 13 - Animation System (TAnimationSystem + TAnimationComponent)');
   DrawFooter('1=idle  2=walk  3=run  4=jump(one-shot)  F=force-restart  SPACE=pause');
   A := AC;
   DrawPanel(30, DEMO_AREA_Y + 10, 320, 200, 'Animation State');
   DrawText(PChar('Clip    : ' + A.CurrentName), 42, DEMO_AREA_Y + 34, 13, COL_ACCENT);
   DrawText(PChar('Frame   : ' + IntToStr(A.FrameIndex)), 42, DEMO_AREA_Y + 54, 12, COL_TEXT);
   DrawText(PChar('Finished: ' + IfThen(A.Finished, 'YES (one-shot ended)', 'no')), 42, DEMO_AREA_Y + 72, 12, IfThen(A.Finished, COL_WARN, COL_GOOD));
   DrawText(PChar('Paused  : ' + IfThen(FPaused, 'YES', 'no')), 42, DEMO_AREA_Y + 90, 12, IfThen(FPaused, COL_BAD, COL_TEXT));
   DrawPanel(30, DEMO_AREA_Y + 220, 320, 160, 'Clips Defined');
   DrawText('idle  Loop=True  1 frame  0.50 s', 42, DEMO_AREA_Y + 244, 11, COL_TEXT);
   DrawText('walk  Loop=True  4 frames 0.15 s', 42, DEMO_AREA_Y + 262, 11, COL_TEXT);
   DrawText('run   Loop=True  4 frames 0.07 s', 42, DEMO_AREA_Y + 280, 11, COL_TEXT);
   DrawText('jump  Loop=False 4 frames 0.12 s', 42, DEMO_AREA_Y + 298, 11, COL_TEXT);
   DrawPanel(SCR_W - 330, DEMO_AREA_Y + 10, 320, 160, 'Pipeline');
   DrawText('TAnimationSystem.Update(dt)', SCR_W - 320, DEMO_AREA_Y + 34, 11, COL_ACCENT);
   DrawText('  Anim.Tick(dt,Rect)', SCR_W - 320, DEMO_AREA_Y + 52, 11, COL_TEXT);
   DrawText('  Spr.SourceRect:=Rect', SCR_W - 320, DEMO_AREA_Y + 70, 11, COL_TEXT);
   DrawText('TZOrderRenderSystem.Render', SCR_W - 320, DEMO_AREA_Y + 88, 11, COL_ACCENT);
   DrawText('  DrawTexturePro(Spr,...)', SCR_W - 320, DEMO_AREA_Y + 106, 11, COL_TEXT);
end;


end.
