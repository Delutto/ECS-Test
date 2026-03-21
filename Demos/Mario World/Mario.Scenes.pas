unit Mario.Scenes;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, raylib, Math,
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
  Mario.Assets,
  Mario.Level,
  Mario.Common,
  Mario.Events,
  Mario.Systems.Input,
  Mario.Systems.Player,
  Mario.Systems.Enemy,
  Mario.Systems.HUD,
  Mario.Systems.GameRules,
  Mario.Systems.Audio,
  Mario.Systems.ScorePopup,
  Mario.InputSetup;

type
  TTitleScene    = class;
  TGameplayScene = class;
  TGameOverScene = class;

  { TTitleScene }
  TTitleScene = class(TScene2D)
  private
    FScreenW: Integer;
    FScreenH: Integer;
    LogoSpr : TTexture2D;
  protected
    procedure DoLoad;  override;
    procedure DoEnter; override;
    procedure DoExit;  override;
  public
    constructor Create(AScreenW, AScreenH: Integer);
    procedure Update(ADelta: Single); override;
    procedure Render; override;
  end;

  { TGameplayScene }
  TGameplayScene = class(TScene2D)
  private
    FCamSys     : TCameraSystem;
    FScreenW    : Integer;
    FScreenH    : Integer;
    FAccumulator: Single;
    procedure RegisterSystems;
    procedure OnPlayerDied(AEvent: TEvent2D);
  protected
    procedure DoLoad;   override;
    procedure DoEnter;  override;
    procedure DoExit;   override;
    procedure DoUnload; override;
  public
    constructor Create(AScreenW, AScreenH: Integer);
    procedure Update(ADelta: Single); override;
    procedure Render; override;
    property CamSys: TCameraSystem read FCamSys;
  end;

  { TGameOverScene }
  TGameOverScene = class(TScene2D)
  private
    FScreenW: Integer;
    FScreenH: Integer;
  protected
    procedure DoLoad;  override;
    procedure DoEnter; override;
    procedure DoExit;  override;
  public
    constructor Create(AScreenW, AScreenH: Integer);
    procedure Update(ADelta: Single); override;
    procedure Render; override;
  end;

implementation

uses
  P2D.Core.ResourceManager,
  P2D.Core.InputManager,
  Mario.Entities;

{ TTitleScene }
constructor TTitleScene.Create(AScreenW, AScreenH: Integer);
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
var AudioSys: TAudioSystem;
begin
  AudioSys := TAudioSystem(World.GetSystem(TAudioSystem));
  if Assigned(AudioSys) then
	AudioSys.StopAllMusic;
  World.ShutdownSystems;
  World.DestroyAllEntities;
  UnloadTexture(LogoSpr);
end;

procedure TTitleScene.Update(ADelta: Single);
begin
  if IsKeyPressed(KEY_SPACE) then
	SceneManager.ChangeScene('Gameplay');
  World.Update(ADelta);
end;

procedure TTitleScene.Render;
begin
  ClearBackground(ColorCreate(92, 148, 252, 255));
  if TexBackground.Id > 0 then
    DrawTextureEx(TexBackground, Vector2Create((FScreenW - TexBackground.Width  * 2) / 2, (FScreenH - TexBackground.Height * 2)), 0, 2, WHITE);
  DrawTextureEx(LogoSpr, Vector2Create((FScreenW / 2) - (LogoSpr.Width  / 2) * 2, (FScreenH / 2) - (LogoSpr.Height / 2) * 2 - 75), 0, 2, WHITE);
  DrawText('Press SPACE to start', FScreenW div 2 - 140, FScreenH div 2 + 10, 22, WHITE);
  DrawFPS(FScreenW - 80, FScreenH - 20);
end;

{ ═══════════════════════════════════════════════════════════════════════════
  TGameplayScene
  ═══════════════════════════════════════════════════════════════════════════ }
constructor TGameplayScene.Create(AScreenW, AScreenH: Integer);
begin
  inherited Create('Gameplay');

  FCamSys  := nil;
  FScreenW := AScreenW;
  FScreenH := AScreenH;
end;

procedure TGameplayScene.RegisterSystems;
var
  W      : TWorld;
  TextSys: TTextSystem2D;
begin
  W := World;

  { ── System registration in priority order (sorted by TWorld.AddSystem) ── }
  W.AddSystem(TPlayerInputSystem.Create(W));        { priority  1 }
  W.AddSystem(TLifetimeSystem.Create(W));           { priority  2 }
  W.AddSystem(TTweenSystem2D.Create(W));            { priority  3 }
  W.AddSystem(TEnemySystem.Create(W));              { priority  3 }
  W.AddSystem(TAnimationSystem.Create(W));          { priority  5 }
  W.AddSystem(TStateMachineSystem2D.Create(W));     { priority  6 }
  W.AddSystem(TPlayerPhysicsSystem.Create(W));      { priority  7 }
  W.AddSystem(TPlayerAnimSystem.Create(W));         { priority  8 }
  W.AddSystem(TPhysicsSystem.Create(W));            { priority 10 }

  FCamSys := TCameraSystem.Create(W, FScreenW, FScreenH);
  W.AddSystem(FCamSys);                             { priority 15 }

  W.AddSystem(TCollisionSystem.Create(W));          { priority 20 }
  W.AddSystem(TGameRulesSystem.Create(W));          { priority 25 }
  W.AddSystem(TScorePopupSystem.Create(W));         { priority 26 }
  W.AddSystem(TTileMapSystem.Create(W));            { priority 30 }
  W.AddSystem(TMarioAudioSystem.Create(W));         { priority 50 }
  W.AddSystem(TRenderSystem.Create(W));             { priority 100 }

  TextSys             := TTextSystem2D.Create(W);
  TextSys.RenderLayer := rlWorld;
  W.AddSystem(TextSys);                             { priority 110 }

  W.AddSystem(THUDSystem.Create(W, FScreenW, FScreenH)); { priority 200 }
end;

procedure TGameplayScene.DoLoad;
begin
  RegisterSystems;
  World.EventBus.Subscribe(TPlayerDiedEvent, @OnPlayerDied);
end;

procedure TGameplayScene.DoEnter;
begin
  FAccumulator := 0;
  LoadLevel(World);
  World.Init;
end;

procedure TGameplayScene.DoExit;
var AudioSys: TAudioSystem;
begin
  AudioSys := TAudioSystem(World.GetSystem(TMarioAudioSystem));
  if Assigned(AudioSys) then
    AudioSys.StopAllMusic;
  World.ShutdownSystems;
  World.DestroyAllEntities;
  World.EventBus.Subscribe(TPlayerDiedEvent, @OnPlayerDied);
end;

procedure TGameplayScene.DoUnload;
begin end;

procedure TGameplayScene.OnPlayerDied(AEvent: TEvent2D);
begin
  SceneManager.ChangeScene('GameOver');
end;

procedure TGameplayScene.Update(ADelta: Single);
begin
  inherited Update(ADelta);
end;

procedure TGameplayScene.Render;
var
  Cam: TCamera2D;
begin
  if not Active then Exit;
  ClearBackground(ColorCreate(92, 148, 252, 255));

  if Assigned(FCamSys) then
  begin
    Cam := FCamSys.GetRaylibCamera;
    if TexBackground.Id > 0 then
      DrawTextureEx(TexBackground,
        Vector2Create(-Cam.Target.X * 0.3 + FScreenW / 2 - 256, (FScreenH - TexBackground.Height * 2)), 0, 2, WHITE);
    FCamSys.BeginCameraMode;
      World.RenderByLayer(rlWorld);
    FCamSys.EndCameraMode;
  end
  else
    World.RenderByLayer(rlWorld);

  World.RenderByLayer(rlScreen);
  DrawFPS(FScreenW - 80, FScreenH - 20);
end;

{ TGameOverScene }
constructor TGameOverScene.Create(AScreenW, AScreenH: Integer);
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
var AudioSys: TAudioSystem;
begin
  AudioSys := TAudioSystem(World.GetSystem(TAudioSystem));
  if Assigned(AudioSys) then
    AudioSys.StopAllMusic;
  World.ShutdownSystems;
  World.DestroyAllEntities;
end;

procedure TGameOverScene.Update(ADelta: Single);
begin
  if IsKeyPressed(KEY_R) then
    SceneManager.ChangeScene('Gameplay');
  World.Update(ADelta);
end;

procedure TGameOverScene.Render;
begin
  DrawRectangle(0, 0, FScreenW, FScreenH, ColorCreate(0, 0, 0, 160));
  DrawText('GAME OVER', FScreenW div 2 - 135, FScreenH div 2 - 30, 50, RED);
  DrawText('Press R to play again', FScreenW div 2 - 140, FScreenH div 2 + 40, 24, WHITE);
end;

end.
