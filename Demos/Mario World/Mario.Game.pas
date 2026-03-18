unit Mario.Game;

{$mode ObjFPC}{$H+}

{ =============================================================================
  Mario.Game — TMarioGame

  With the Scene Manager in place, TMarioGame becomes a thin bootstrap class:

    OnInit     → generates procedural assets, sets up input bindings,
                  creates + registers the three scenes, and activates the
                  Title scene immediately.

    OnUpdate   → delegates entirely to SceneManager.Update(ADelta).
                  No per-scene logic lives here anymore.

    OnRender   → delegates entirely to SceneManager.Render.
                  Each scene's own Render method handles ClearBackground,
                  camera mode, parallax, and HUD.

    OnShutdown → frees the three scene objects (the manager unloads them
                  first in its destructor) and releases procedural textures.

  The entire restart / game-over flow that was previously handled by
  DoRestart is now driven by scene transitions:
    Player dies → TGameplayScene subscribes TPlayerDiedEvent →
                   SceneManager.ChangeScene('GameOver')
    Player presses R on GameOver → SceneManager.ChangeScene('Gameplay') →
                   TGameplayScene.DoExit cleans up → TGameplayScene.DoEnter
                   rebuilds everything.
  ============================================================================= }

interface

uses
   SysUtils, raylib,
   P2D.Core.Engine,
   P2D.Core.Scene,
   Mario.Assets,
   Mario.Common,
   Mario.InputSetup,
   Mario.Scenes;

type

   { TMarioGame }

   TMarioGame = class(TEngine2D)
   private
      FTitleScene   : TTitleScene;
      FGameplayScene: TGameplayScene;
      FGameOverScene: TGameOverScene;
      FResolutions  : array of TResEntry;
      FResIndex     : Integer;
      procedure BuildResolutionList;
   protected
      procedure OnInit; override;
      procedure OnUpdate(ADelta: Single); override;
      procedure OnRender; override;
      procedure OnShutdown; override;
   public
      constructor Create;
   end;

implementation

constructor TMarioGame.Create;
begin
   inherited Create(800, 600, 'Pascal2D - Super Mario World Demo', 60);
end;

procedure TMarioGame.BuildResolutionList;
   procedure Add(W, H: Integer);
   var
      N: Integer;
   begin
      N := Length(FResolutions);
      SetLength(FResolutions, N+1);
      FResolutions[N].W := W;
      FResolutions[N].H := H;
   end;
var
   MonW: Integer;
begin
   MonW := GetMonitorWidth(GetCurrentMonitor);
   Add(VIRTUAL_W, VIRTUAL_H);
   if MonW >= 1280 then
      Add(1280, 720);
   if MonW >= 1600 then
      Add(1600, 960);
   if MonW >= 1920 then
      Add(1920, 1080);
end;

procedure TMarioGame.OnInit;
begin
   BuildResolutionList;

   { Register player input bindings. }
   SetupPlayerInput;

   { Generate all procedural textures (requires active OpenGL context). }
   GenerateAssets;

   { Create the three scenes.
     Scene objects are owned by TMarioGame; the manager holds non-owning references. TMarioGame.OnShutdown frees them after the manager is done. }
   FTitleScene    := TTitleScene.Create(ScreenW, ScreenH);
   FGameplayScene := TGameplayScene.Create(ScreenW, ScreenH);
   FGameOverScene := TGameOverScene.Create(ScreenW, ScreenH);

   { Register scenes with the manager (calls Load on each). }
   SceneManager.RegisterScene(FTitleScene);
   SceneManager.RegisterScene(FGameplayScene);
   SceneManager.RegisterScene(FGameOverScene);

   { Activate the title screen immediately. }
   SceneManager.ChangeSceneImmediate('Title');
end;

procedure TMarioGame.OnUpdate(ADelta: Single);
var
   R: TResEntry;
begin
   SceneManager.Update(ADelta);
   if IsKeyPressed(KEY_TAB) and (Length(FResolutions) > 1) then
   begin
      FResIndex := (FResIndex + 1) mod Length(FResolutions);
      R := FResolutions[FResIndex];
      SetWindowResolution(R.W, R.H);   // from TEngine2D
   end;
end;

procedure TMarioGame.OnRender;
begin
   SceneManager.Render;
end;

procedure TMarioGame.OnShutdown;
begin
   { Step 1: Unregister — calls Exit (if active) + Unload on each scene, removes from FScenes. Runs while raylib context is still open. }
   SceneManager.UnregisterScene('GameOver');
   SceneManager.UnregisterScene('Gameplay');
   SceneManager.UnregisterScene('Title');

   { Step 2: Free — safe, manager has no references left. }
   FGameOverScene.Free;
   FGameplayScene.Free;
   FTitleScene.Free;

   { Step 3: Release procedural textures. }
   UnloadAssets;
end;

end.

