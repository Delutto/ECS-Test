unit Mario.Game;

{$mode ObjFPC}
{$H+}

interface

uses
   SysUtils,
   raylib,
   P2D.Core.Engine,
   P2D.Core.Scene,
   Mario.Assets,
   Mario.Common,
   Mario.InputSetup,
   Mario.Scenes;

type
   TMarioGame = class(TEngine2D)
   private
      FTitleScene: TTitleScene;
      FGameplayScene: TGameplayScene;
      FUnderwaterScene: TUnderwaterScene;
      FGameOverScene: TGameOverScene;
      FResolutions: array of TResEntry;
      FResIndex: Integer;
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
      SetLength(FResolutions, N + 1);
      FResolutions[N].W := W;
      FResolutions[N].H := H;
   end;

var
   MonW: Integer;
begin
   MonW := GetMonitorWidth(GetCurrentMonitor);
   Add(VIRTUAL_W, VIRTUAL_H);
   if MonW >= 1280 then
   begin
      Add(1280, 720)
   end;
   if MonW >= 1600 then
   begin
      Add(1600, 960)
   end;
   if MonW >= 1920 then
   begin
      Add(1920, 1080)
   end;
end;

procedure TMarioGame.OnInit;
begin
   BuildResolutionList;
   SetupPlayerInput;
   GenerateAssets;

   FTitleScene := TTitleScene.Create(ScreenW, ScreenH);
   FGameplayScene := TGameplayScene.Create(ScreenW, ScreenH);
   FUnderwaterScene := TUnderwaterScene.Create(ScreenW, ScreenH);   { ← NEW }
   FGameOverScene := TGameOverScene.Create(ScreenW, ScreenH);

   SceneManager.RegisterScene(FTitleScene);
   SceneManager.RegisterScene(FGameplayScene);
   SceneManager.RegisterScene(FUnderwaterScene);   { ← NEW }
   SceneManager.RegisterScene(FGameOverScene);

   SceneManager.ChangeSceneImmediate('Title');
end;

procedure TMarioGame.OnUpdate(ADelta: Single);
var
   R: TResEntry;
begin
   SceneManager.Update(ADelta);
   if IsKeyPressed(KEY_TAB) And (Length(FResolutions) > 1) then
   begin
      FResIndex := (FResIndex + 1) Mod Length(FResolutions);
      R := FResolutions[FResIndex];
      SetWindowResolution(R.W, R.H);
   end;
end;

procedure TMarioGame.OnRender;
begin
   SceneManager.Render;
end;

procedure TMarioGame.OnShutdown;
begin
   SceneManager.UnregisterScene('GameOver');
   SceneManager.UnregisterScene('Underwater');   { ← NEW }
   SceneManager.UnregisterScene('Gameplay');
   SceneManager.UnregisterScene('Title');
   FGameOverScene.Free;
   FUnderwaterScene.Free;   { ← NEW }
   FGameplayScene.Free;
   FTitleScene.Free;
   UnloadAssets;
end;

end.
