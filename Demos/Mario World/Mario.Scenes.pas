unit Mario.Scenes;

{$mode objfpc}{$H+}

interface

uses
   SysUtils,
   raylib,
   Math,
   P2D.Core.Scene,
   P2D.Core.World,
   P2D.Core.Entity,
   P2D.Core.Types,
   P2D.Core.Event,
   P2D.Core.System,
   P2D.Systems.Audio,
   P2D.Systems.Physics,
   P2D.Systems.Collision,
   P2D.Systems.Animation,
   P2D.Systems.Particles,
   P2D.Systems.Render,
   P2D.Systems.Camera,
   P2D.Systems.TileMap,
   P2D.Systems.Lifetime,
   P2D.Systems.Tween,
   P2D.Systems.Text,
   P2D.Systems.StateMachine,
   P2D.Systems.Parallax,
   Mario.Assets,
   Mario.Level,
   Mario.Level2,
   Mario.Common,
   Mario.Events,
   Mario.Systems.Input,
   Mario.Systems.Player,
   Mario.Systems.Enemy,
   Mario.Systems.HUD,
   Mario.Systems.GameRules,
   Mario.Systems.Audio,
   Mario.Systems.ScorePopup,
   Mario.Systems.Swim,
   Mario.Systems.Fish,
   Mario.InputSetup;

type
   TTitleScene = class;
   TGameplayScene = class;
   TUnderwaterScene = class;
   TGameOverScene = class;

   { ── TTitleScene ────────────────────────────────────────────────────────── }
   TTitleScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      LogoSpr: TTexture2D;
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AScreenW, AScreenH: integer);
      procedure Update(ADelta: single); override;
      procedure Render; override;
   end;

   { ── TGameplayScene ─────────────────────────────────────────────────────── }
   TGameplayScene = class(TScene2D)
   private
      FCamSys: TCameraSystem;
      FScreenW, FScreenH: integer;
      FAccumulator: single;
      procedure RegisterSystems;
      procedure OnPlayerDied(AEvent: TEvent2D);
      procedure OnLevelComplete(AEvent: TEvent2D);
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
      procedure DoUnload; override;
   public
      constructor Create(AScreenW, AScreenH: integer);
      procedure Update(ADelta: single); override;
      procedure Render; override;
      property CamSys: TCameraSystem read FCamSys;
   end;

   { ── TUnderwaterScene ───────────────────────────────────────────────────── }
   TUnderwaterScene = class(TScene2D)
   private
      FCamSys: TCameraSystem;
      FScreenW, FScreenH: integer;
      procedure RegisterSystems;
      procedure OnPlayerDied(AEvent: TEvent2D);
      procedure OnLevelComplete(AEvent: TEvent2D);
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
      procedure DoUnload; override;
   public
      constructor Create(AScreenW, AScreenH: integer);
      procedure Update(ADelta: single); override;
      procedure Render; override;
   end;

   { ── TGameOverScene ─────────────────────────────────────────────────────── }
   TGameOverScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AScreenW, AScreenH: integer);
      procedure Update(ADelta: single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Core.ResourceManager,
   P2D.Core.InputManager,
   Mario.Entities;

{ ── shared RegisterSystems helper ─────────────────────────────────────────── }
procedure AddCoreSystems(W: TWorld; CamSys: TCameraSystem; ScreenW, ScreenH: integer; out TextSys: TTextSystem2D);
begin
   W.AddSystem(TPlayerInputSystem.Create(W));
   W.AddSystem(TLifetimeSystem.Create(W));
   W.AddSystem(TTweenSystem2D.Create(W));
   W.AddSystem(TEnemySystem.Create(W));
   W.AddSystem(TAnimationSystem.Create(W));
   W.AddSystem(TStateMachineSystem2D.Create(W));
   W.AddSystem(TPlayerPhysicsSystem.Create(W));
   W.AddSystem(TPlayerAnimSystem.Create(W));
   W.AddSystem(TPhysicsSystem.Create(W));
   W.AddSystem(CamSys);
   W.AddSystem(TCollisionSystem.Create(W));
   W.AddSystem(TGameRulesSystem.Create(W));
   W.AddSystem(TScorePopupSystem.Create(W));
   W.AddSystem(TTileMapSystem.Create(W));
   W.AddSystem(TMarioAudioSystem.Create(W));
   W.AddSystem(TRenderSystem.Create(W));
   TextSys := TTextSystem2D.Create(W);
   TextSys.RenderLayer := rlWorld;
   W.AddSystem(TextSys);
   W.AddSystem(THUDSystem.Create(W, ScreenW, ScreenH));
   W.AddSystem(TParallaxSystem2D.Create(W, ScreenW, ScreenH));
end;

{ ═══ TTitleScene ═════════════════════════════════════════════════════════════}
constructor TTitleScene.Create(AScreenW, AScreenH: integer);
begin
   inherited Create('Title');

   FScreenW := AScreenW;
   FScreenH := AScreenH;
end;

procedure TTitleScene.DoLoad;
begin
   World.AddSystem(TAudioSystem.Create(World));
end;

procedure TTitleScene.DoEnter;
begin
   CreateMusicPlayer(World, BGM_TITLE);
   LogoSpr := TResourceManager2D.Instance.LoadTexture(LOGO_TEXTURE);
end;

procedure TTitleScene.DoExit;
var
   A: TAudioSystem;
begin
   A := TAudioSystem(World.GetSystem(TAudioSystem));
   if Assigned(A) then
   begin
      A.StopAllMusic;
   end;
   World.ShutdownSystems;
   World.DestroyAllEntities;
   UnloadTexture(LogoSpr);
end;

procedure TTitleScene.Update(ADelta: single);
begin
   if IsKeyPressed(KEY_SPACE) then
   begin
      SceneManager.ChangeScene('Gameplay');
   end;
   World.Update(ADelta);
end;

procedure TTitleScene.Render;
begin
   ClearBackground(ColorCreate(92, 148, 252, 255));
   if TexBackground.Id > 0 then
   begin
      DrawTextureEx(TexBackground, Vector2Create((FScreenW - TexBackground.Width * 2) / 2, (FScreenH - TexBackground.Height * 2)), 0, 2, WHITE);
   end;
   DrawTextureEx(LogoSpr, Vector2Create((FScreenW / 2) - (LogoSpr.Width / 2) * 2, (FScreenH / 2) - (LogoSpr.Height / 2) * 2 - 75), 0, 2, WHITE);
   DrawText('Press SPACE to start', FScreenW div 2 - 140, FScreenH div 2 + 10, 22, WHITE);
   DrawFPS(FScreenW - 80, FScreenH - 20);
end;

{ ═══ TGameplayScene (Level 1) ════════════════════════════════════════════════}
constructor TGameplayScene.Create(AScreenW, AScreenH: integer);
begin
   inherited Create('Gameplay');

   FCamSys := nil;
   FScreenW := AScreenW;
   FScreenH := AScreenH;
end;

procedure TGameplayScene.RegisterSystems;
var
   W: TWorld;
   TextSys: TTextSystem2D;
begin
   W := World;
   FCamSys := TCameraSystem.Create(W, FScreenW, FScreenH);
   AddCoreSystems(W, FCamSys, FScreenW, FScreenH, TextSys);
end;

procedure TGameplayScene.DoLoad;
begin
   RegisterSystems;
   World.EventBus.Subscribe(TPlayerDiedEvent, @OnPlayerDied);
   World.EventBus.Subscribe(TLevelCompleteEvent, @OnLevelComplete);
end;

procedure TGameplayScene.DoEnter;
begin
   FAccumulator := 0;
   LoadLevel(World);
   World.Init;
end;

procedure TGameplayScene.DoUnload;
begin

end;

procedure TGameplayScene.DoExit;
var
   A: TAudioSystem;
begin
   A := TAudioSystem(World.GetSystem(TMarioAudioSystem));
   if Assigned(A) then
   begin
      A.StopAllMusic;
   end;
   World.ShutdownSystems;
   World.DestroyAllEntities;
   World.EventBus.Subscribe(TPlayerDiedEvent, @OnPlayerDied);
   World.EventBus.Subscribe(TLevelCompleteEvent, @OnLevelComplete);
end;

procedure TGameplayScene.OnPlayerDied(AEvent: TEvent2D);
begin
   SceneManager.ChangeScene('GameOver');
end;

procedure TGameplayScene.OnLevelComplete(AEvent: TEvent2D);
begin
   SceneManager.ChangeScene('Underwater');
end;

procedure TGameplayScene.Update(ADelta: single);
begin
   inherited Update(ADelta);
end;

procedure TGameplayScene.Render;
var
   Cam: TCamera2D;
begin
   if not Active then
   begin
      Exit;
   end;
   ClearBackground(ColorCreate(92, 148, 252, 255));
   World.RenderByLayer(rlBackground);
   if Assigned(FCamSys) then
   begin
      Cam := FCamSys.GetRaylibCamera;
      FCamSys.BeginCameraMode;
      World.RenderByLayer(rlWorld);
      FCamSys.EndCameraMode;
   end
   else
   begin
      World.RenderByLayer(rlWorld);
   end;
   World.RenderByLayer(rlScreen);
   DrawFPS(FScreenW - 80, FScreenH - 20);
end;

{ ═══ TUnderwaterScene (Level 2) ══════════════════════════════════════════════}
constructor TUnderwaterScene.Create(AScreenW, AScreenH: integer);
begin
   inherited Create('Underwater');
   FCamSys := nil;
   FScreenW := AScreenW;
   FScreenH := AScreenH;
end;

procedure TUnderwaterScene.RegisterSystems;
var
   W: TWorld;
   TextSys: TTextSystem2D;
begin
   W := World;
   FCamSys := TCameraSystem.Create(W, FScreenW, FScreenH);
   AddCoreSystems(W, FCamSys, FScreenW, FScreenH, TextSys);
   { Swim and Fish systems unique to this scene }
   W.AddSystem(TSwimSystem.Create(W));   { priority 4 — before TPlayerPhysicsSystem }
   W.AddSystem(TFishSystem.Create(W));   { priority 3 — same as TEnemySystem        }
end;

procedure TUnderwaterScene.DoLoad;
begin
   RegisterSystems;
   World.EventBus.Subscribe(TPlayerDiedEvent, @OnPlayerDied);
   World.EventBus.Subscribe(TLevelCompleteEvent, @OnLevelComplete);
end;

procedure TUnderwaterScene.DoEnter;
begin
   LoadLevel2(World);
   World.Init;
end;

procedure TUnderwaterScene.DoUnload;
begin

end;

procedure TUnderwaterScene.DoExit;
var
   A: TAudioSystem;
begin
   A := TAudioSystem(World.GetSystem(TMarioAudioSystem));
   if Assigned(A) then
   begin
      A.StopAllMusic;
   end;
   World.ShutdownSystems;
   World.DestroyAllEntities;
   World.EventBus.Subscribe(TPlayerDiedEvent, @OnPlayerDied);
   World.EventBus.Subscribe(TLevelCompleteEvent, @OnLevelComplete);
end;

procedure TUnderwaterScene.OnPlayerDied(AEvent: TEvent2D);
begin
   SceneManager.ChangeScene('GameOver');
end;

procedure TUnderwaterScene.OnLevelComplete(AEvent: TEvent2D);
begin
   SceneManager.ChangeScene('Gameplay');
end;

procedure TUnderwaterScene.Update(ADelta: single);
begin
   inherited Update(ADelta);
end;

procedure TUnderwaterScene.Render;
begin
   if not Active then
   begin
      Exit;
   end;
   { Deep water background colour — fills gaps between parallax tiles }
   ClearBackground(ColorCreate(5, 20, 80, 255));
   World.RenderByLayer(rlBackground);
   if Assigned(FCamSys) then
   begin
      FCamSys.BeginCameraMode;
      World.RenderByLayer(rlWorld);
      FCamSys.EndCameraMode;
   end
   else
   begin
      World.RenderByLayer(rlWorld);
   end;
   { Subtle blue overlay to reinforce underwater feeling }
   DrawRectangle(0, 0, FScreenW, FScreenH, ColorCreate(0, 30, 100, 35));
   World.RenderByLayer(rlScreen);
   DrawFPS(FScreenW - 80, FScreenH - 20);
end;

{ ═══ TGameOverScene ══════════════════════════════════════════════════════════}
constructor TGameOverScene.Create(AScreenW, AScreenH: integer);
begin
   inherited Create('GameOver');
   FScreenW := AScreenW;
   FScreenH := AScreenH;
end;

procedure TGameOverScene.DoLoad;
begin
   World.AddSystem(TAudioSystem.Create(World));
end;

procedure TGameOverScene.DoEnter;
begin
   CreateMusicPlayer(World, BGM_GAMEOVER, True, False);
end;

procedure TGameOverScene.DoExit;
var
   A: TAudioSystem;
begin
   A := TAudioSystem(World.GetSystem(TAudioSystem));
   if Assigned(A) then
   begin
      A.StopAllMusic;
   end;
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TGameOverScene.Update(ADelta: single);
begin
   if IsKeyPressed(KEY_R) then
   begin
      SceneManager.ChangeScene('Gameplay');
   end;
   World.Update(ADelta);
end;

procedure TGameOverScene.Render;
begin
   DrawRectangle(0, 0, FScreenW, FScreenH, ColorCreate(0, 0, 0, 160));
   DrawText('GAME OVER', FScreenW div 2 - 135, FScreenH div 2 - 30, 50, RED);
   DrawText('Press R to play again', FScreenW div 2 - 140, FScreenH div 2 + 40, 24, WHITE);
end;

end.
