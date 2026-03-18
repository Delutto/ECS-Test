unit Mario.Scenes;

{$mode ObjFPC}{$H+}

{ ===================================================================================================================================
  Mario.Scenes — The three game scenes for the Mario demo.

  TTitleScene
    Draws a procedurally generated title screen.
    Pressing Enter or Space transitions to TGameplayScene.

  TGameplayScene
    Contains the complete ECS world: all systems, all entities.
    Replaces the old OnInit / DoRestart logic in TMarioGame.
    Pressing R restarts by re-entering this same scene (Exit → Enter).
    When the player dies the scene schedules a transition to TGameOverScene.

  TGameOverScene
    Draws a "GAME OVER" overlay.
    Pressing R transitions back to TGameplayScene (full restart).

  INTERACTION WITH TEngine2D
  ──────────────────────────
  TMarioGame.OnInit  → creates and registers all three scenes, then calls SceneManager.ChangeSceneImmediate('Title').
  TMarioGame.OnUpdate → delegates to SceneManager.Update(ADelta).
  TMarioGame.OnRender → delegates to SceneManager.Render, which calls the active scene's Render method.

  SCENE-TO-SCENE COMMUNICATION
  ─────────────────────────────
  Scenes communicate via TSceneManager.ChangeScene — no direct references between scene objects are needed or allowed.
  TGameplayScene subscribes to TPlayerDiedEvent via its World EventBus and schedules a transition to 'GameOver' when the event fires.
  =================================================================================================================================== }

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
   Mario.InputSetup;

type
   { =========================================================================
    TTitleScene — static title screen.
    Renders over the background texture with a title card.
    Pressing Enter or Space moves to the gameplay scene.
   ========================================================================= }
   TTitleScene = class(TScene2D)
   private
      FScreenW: Integer;
      FScreenH: Integer;

      LogoSpr: TTexture2D;
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AScreenW, AScreenH: Integer);
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

   { =========================================================================
    TGameplayScene — the main gameplay world.
    Owns all ECS systems and entities. Camera is kept as a field so that OnRender can call BeginMode2D / EndMode2D around rlWorld rendering.
   ========================================================================= }
   TGameplayScene = class(TScene2D)
   private
      FCamSys: TCameraSystem;
      FScreenW: Integer;
      FScreenH: Integer;

      FAccumulator: Single;

      procedure RegisterSystems;
      procedure OnPlayerDied(AEvent: TEvent2D);
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
      procedure DoUnload; override;
   public
      constructor Create(AScreenW, AScreenH: Integer);
      procedure Update(ADelta: Single); override;
      procedure Render; override;

      { Exposed so TMarioGame.OnRender can call BeginCameraMode/EndCameraMode if it needs to render additional world-space content. }
      property CamSys: TCameraSystem read FCamSys;
   end;

   { =========================================================================
    TGameOverScene — game-over overlay.
    Does not own a world. Draws directly over the frozen gameplay frame.
    Pressing R transitions back to the gameplay scene.
   ========================================================================= }

   { TGameOverScene }

   TGameOverScene = class(TScene2D)
   private
      FScreenW: Integer;
      FScreenH: Integer;
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
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

{$REGION 'TTitleScene' }
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
   { Play title BGM via direct raylib call; the ECS audio system belongs to TGameplayScene, not here.
     If a title music track is desired, load and play it here, and stop it in DoExit. }
   CreateMusicPlayer(World, BGM_TITLE);
   LogoSpr := TResourceManager2D.Instance.LoadTexture(LOGO_TEXTURE);
end;

procedure TTitleScene.DoExit;
var
   AudioSys: TAudioSystem;
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
   { No World to update. Check for player input to start the game. }
   if IsKeyPressed(KEY_SPACE) then
      SceneManager.ChangeScene('Gameplay');

   World.Update(ADelta);
end;

procedure TTitleScene.Render;
begin
   ClearBackground(ColorCreate(92, 148, 252, 255));

   { Draw the parallax background texture at scale 2 centred on screen. }
   if TexBackground.Id > 0 then
      DrawTextureEx(TexBackground, Vector2Create((FScreenW - TexBackground.Width * 2) / 2, (FScreenH - TexBackground.Height * 2)), 0, 2, WHITE);

   { Semi-transparent title card }
   //DrawRectangle(SW div 2 - 260, SH div 2 - 70, 520, 120, ColorCreate(0, 0, 0, 180));

   DrawTextureEx(LogoSpr, Vector2Create((FScreenW / 2) - (LogoSpr.width / 2) * 2, ((FScreenH / 2) - (LogoSpr.height / 2) * 2) - 75), 0, 2, WHITE);

   DrawText('Press SPACE to start', FScreenW div 2 - 140, FScreenH div 2 + 10, 22, WHITE);

   DrawFPS(FScreenW - 80, FScreenH - 20);
end;
{$ENDREGION}

{$REGION 'TGameplayScene'}
constructor TGameplayScene.Create(AScreenW, AScreenH: Integer);
begin
   inherited Create('Gameplay');

   FCamSys  := nil;
   FScreenW := AScreenW;
   FScreenH := AScreenH;
end;

procedure TGameplayScene.RegisterSystems;
var
   W: TWorld;
begin
   W := World;

   W.AddSystem(TPlayerInputSystem.Create(W));    { priority  1 }
   W.AddSystem(TEnemySystem.Create(W));          { priority  3 }
   W.AddSystem(TAnimationSystem.Create(W));      { priority  5 }
   W.AddSystem(TPlayerPhysicsSystem.Create(W));  { priority  7 }
   W.AddSystem(TPlayerAnimSystem.Create(W));     { priority  8 }
   W.AddSystem(TPhysicsSystem.Create(W));        { priority 10 }
   W.AddSystem(TCollisionSystem.Create(W));      { priority 20 }
   W.AddSystem(TGameRulesSystem.Create(W));      { priority 25 }
   W.AddSystem(TTileMapSystem.Create(W));        { priority 30 }
   W.AddSystem(TMarioAudioSystem.Create(W));     { priority 50 }
   W.AddSystem(TRenderSystem.Create(W));         { priority 100 }

   FCamSys := TCameraSystem.Create(W, FScreenW, FScreenH);
   W.AddSystem(FCamSys);                         { priority 15 }

   W.AddSystem(THUDSystem.Create(W, FScreenW, FScreenH)); { priority 200 }
end;

procedure TGameplayScene.DoLoad;
begin
   { Build the ECS: register all systems.
    Entities are NOT created here — they are created in DoEnter, which runs every time the scene becomes active (including after a restart). }
   RegisterSystems;

   { Subscribe to TPlayerDiedEvent so this scene can trigger a transition to the GameOver scene. The subscription is on this scene's own World EventBus,
    so it is automatically cleared when World.ShutdownSystems is called in DoExit, without any manual Unsubscribe call needed here. }
   World.EventBus.Subscribe(TPlayerDiedEvent, @OnPlayerDied);
end;

procedure TGameplayScene.DoEnter;
begin
   FAccumulator := 0;
   { Create all level entities.
    If this is not the first entry (i.e. a restart), the old entities were already purged in DoExit, so the World is clean. }
   LoadLevel(World);

   { World.Init calls S.Init on every registered system in priority order:
       TCameraSystem.Init    → locates camera entity and player entity.
       TGameRulesSystem.Init → subscribes to TEntityOverlapEvent.
       TMarioAudioSystem.Init → subscribes to gameplay events + starts music. }
   World.Init;
end;

procedure TGameplayScene.DoExit;
var
   AudioSys: TAudioSystem;
   IDs     : array of TEntityID;
   I       : Integer;
begin
   { 1. Stop music before touching the EventBus. }
   AudioSys := TAudioSystem(World.GetSystem(TMarioAudioSystem));
   if Assigned(AudioSys) then
      AudioSys.StopAllMusic;

   { 2. ShutdownSystems: cancels all EventBus subscriptions, clears event queues, invalidates system caches,
   resets FShutdownCalled so that World.Init can be called again in the next DoEnter. }
   World.ShutdownSystems;

   { 3. Destroy and purge all entities, freeing their components. }
   World.DestroyAllEntities;

   { 4. Re-subscribe TPlayerDiedEvent for the next DoEnter cycle.
   ShutdownSystems cleared the EventBus subscriptions, so we must restore this scene-level subscription explicitly. }
   World.EventBus.Subscribe(TPlayerDiedEvent, @OnPlayerDied);
end;

procedure TGameplayScene.DoUnload;
begin
   { World.Free is called by TScene2D.Destroy, which frees all systems.
     Nothing extra to release here. }
end;

procedure TGameplayScene.OnPlayerDied(AEvent: TEvent2D);
begin
   { Schedule transition to game-over scene. The transition is deferred, so the current Update/Render cycle finishes normally before the switch. }
   SceneManager.ChangeScene('GameOver');
end;

procedure TGameplayScene.Update(ADelta: Single);
const
   FIXED_DT : Single = 1.0 / 60.0;
   MAX_DELTA: Single = 0.25;
var
   Delta: Single;
begin
   if not Active or Paused then
      Exit;

   Delta        := Min(ADelta, MAX_DELTA);
   FAccumulator := FAccumulator + Delta;

   while FAccumulator >= FIXED_DT do
   begin
      World.FixedUpdate(FIXED_DT);
      FAccumulator := FAccumulator - FIXED_DT;
   end;

   { Variable update: input, animation, camera, game rules.
   PurgeDestroyed and EventBus.Dispatch are called inside World.Update. }
   World.Update(Delta);
end;

procedure TGameplayScene.Render;
var
   Cam: TCamera2D;
begin
   if not Active then
      Exit;

   ClearBackground(ColorCreate(92, 148, 252, 255));

   { Parallax background — scrolls at 30% of the camera target speed. }
   if Assigned(FCamSys) then
   begin
      Cam := FCamSys.GetRaylibCamera;
      if TexBackground.Id > 0 then
         DrawTextureEx(TexBackground, Vector2Create(-Cam.Target.X * 0.3 + FScreenW / 2 - 256, (FScreenH - TexBackground.Height * 2)), 0, 2, WHITE);

      { World-space rendering inside the camera transform. }
      FCamSys.BeginCameraMode;
      World.RenderByLayer(rlWorld);
      FCamSys.EndCameraMode;
   end
   else
   World.RenderByLayer(rlWorld);

   { Screen-space HUD — outside the camera transform. }
   World.RenderByLayer(rlScreen);

   DrawFPS(FScreenW - 80, FScreenH - 20);
end;
{$ENDREGION}

{$REGION 'TGameOverScene'}
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
var
   AudioSys: TAudioSystem;
begin
   AudioSys := TAudioSystem(World.GetSystem(TAudioSystem));
   if Assigned(AudioSys) then
      AudioSys.StopAllMusic;

   World.ShutdownSystems;

   World.DestroyAllEntities;
end;

procedure TGameOverScene.Update(ADelta: Single);
begin
   { R → full restart: transition back to Gameplay.
     TGameplayScene.DoExit destroys all entities and TGameplayScene.DoEnter recreates them, giving a clean slate. }
   if IsKeyPressed(KEY_R) then
      SceneManager.ChangeScene('Gameplay');

   World.Update(ADelta);
end;

{ Dark full-screen overlay — draws over whatever was last rendered.
  Because TEngine2D calls BeginDrawing/EndDrawing around OnRender, and  OnRender calls SceneManager.Render which delegates here,
  the framebuffer still contains the frozen gameplay frame from the previous Update cycle. }
procedure TGameOverScene.Render;
begin
   DrawRectangle(0, 0, FScreenW, FScreenH, ColorCreate(0, 0, 0, 160));

   DrawText('GAME OVER', FScreenW div 2 - 135, FScreenH div 2 - 30, 50, RED);

   DrawText('Press R to play again', FScreenW div 2 - 140, FScreenH div 2 + 40, 24, WHITE);
end;
{$ENDREGION}

end.
