unit P2D.Core.Scene;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, P2D.Core.World;

type
  { TP2DScene }
  TP2DScene = class
  private
    FWorld: TP2DWorld;
    FName: string;
    FActive: Boolean;
    FPaused: Boolean;
  protected
    procedure DoLoad; virtual;
    procedure DoUnload; virtual;
    procedure DoEnter; virtual;
    procedure DoExit; virtual;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;

    procedure Load;
    procedure Unload;
    procedure Enter;
    procedure Exit;

    procedure Update(DeltaTime: Double); virtual;
    procedure Render; virtual;
    procedure Pause;
    procedure Resume;

    property World: TP2DWorld read FWorld;
    property Name: string read FName;
    property Active: Boolean read FActive;
    property Paused: Boolean read FPaused;
  end;

  { TP2DSceneManager }
  TP2DSceneManager = class
  private
    FScenes: array of TP2DScene;
    FCurrentScene: TP2DScene;
    FNextScene: TP2DScene;
    FTransitioning: Boolean;
    class var FInstance: TP2DSceneManager;
  public
    constructor Create;
    destructor Destroy; override;
    class function Instance: TP2DSceneManager;
    class procedure FreeInstance;

    procedure RegisterScene(AScene: TP2DScene);
    procedure UnregisterScene(const ASceneName: string);
    function GetScene(const ASceneName: string): TP2DScene;

    procedure ChangeScene(const ASceneName: string);
    procedure ChangeSceneImmediate(const ASceneName: string);

    procedure Update(DeltaTime: Double);
    procedure Render;

    property CurrentScene: TP2DScene read FCurrentScene;
    property IsTransitioning: Boolean read FTransitioning;
  end;

implementation

uses
  P2D.Utils.Logger;

{ TP2DScene }

constructor TP2DScene.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
  FWorld := TP2DWorld.Create;
  FActive := False;
  FPaused := False;
  TP2DLogger.Info('Scene created: ' + AName);
end;

destructor TP2DScene.Destroy;
begin
  if FActive then
    Exit;
  FWorld.Free;
  TP2DLogger.Info('Scene destroyed: ' + FName);
  inherited;
end;

procedure TP2DScene.DoLoad;
begin
  // Override in child classes
end;

procedure TP2DScene.DoUnload;
begin
  // Override in child classes
end;

procedure TP2DScene.DoEnter;
begin
  // Override in child classes
end;

procedure TP2DScene.DoExit;
begin
  // Override in child classes
end;

procedure TP2DScene.Load;
begin
  TP2DLogger.Info('Loading scene: ' + FName);
  DoLoad;
end;

procedure TP2DScene.Unload;
begin
  TP2DLogger.Info('Unloading scene: ' + FName);
  DoUnload;
  FWorld.Clear;
end;

procedure TP2DScene.Enter;
begin
  FActive := True;
  FPaused := False;
  TP2DLogger.Info('Entering scene: ' + FName);
  DoEnter;
end;

procedure TP2DScene.Exit;
begin
  FActive := False;
  TP2DLogger.Info('Exiting scene: ' + FName);
  DoExit;
end;

procedure TP2DScene.Update(DeltaTime: Double);
begin
  if FActive and not FPaused then
    FWorld.Update(DeltaTime);
end;

procedure TP2DScene.Render;
begin
  if FActive then
    FWorld.Render;
end;

procedure TP2DScene.Pause;
begin
  FPaused := True;
  TP2DLogger.Info('Scene paused: ' + FName);
end;

procedure TP2DScene.Resume;
begin
  FPaused := False;
  TP2DLogger.Info('Scene resumed: ' + FName);
end;

{ TP2DSceneManager }

constructor TP2DSceneManager.Create;
begin
  inherited Create;
  SetLength(FScenes, 0);
  FCurrentScene := nil;
  FNextScene := nil;
  FTransitioning := False;
  TP2DLogger.Info('SceneManager initialized');
end;

destructor TP2DSceneManager.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(FScenes) do
  begin
    if FScenes[i].Active then
      FScenes[i].Exit;
    FScenes[i].Unload;
    FScenes[i].Free;
  end;
  SetLength(FScenes, 0);
  TP2DLogger.Info('SceneManager destroyed');
  inherited;
end;

class function TP2DSceneManager.Instance: TP2DSceneManager;
begin
  if FInstance = nil then
    FInstance := TP2DSceneManager.Create;
  Result := FInstance;
end;

class procedure TP2DSceneManager.FreeInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TP2DSceneManager.RegisterScene(AScene: TP2DScene);
begin
  SetLength(FScenes, Length(FScenes) + 1);
  FScenes[High(FScenes)] := AScene;
  AScene.Load;
  TP2DLogger.Info('Scene registered: ' + AScene.Name);
end;

procedure TP2DSceneManager.UnregisterScene(const ASceneName: string);
var
  i: Integer;
begin
  for i := 0 to High(FScenes) do
  begin
    if FScenes[i].Name = ASceneName then
    begin
      if FScenes[i] = FCurrentScene then
        FCurrentScene := nil;
      FScenes[i].Unload;
      FScenes[i].Free;
      // Remove do array
      if i < High(FScenes) then
        Move(FScenes[i + 1], FScenes[i], (High(FScenes) - i) * SizeOf(TP2DScene));
      SetLength(FScenes, Length(FScenes) - 1);
      TP2DLogger.Info('Scene unregistered: ' + ASceneName);
      Exit;
    end;
  end;
end;

function TP2DSceneManager.GetScene(const ASceneName: string): TP2DScene;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to High(FScenes) do
  begin
    if FScenes[i].Name = ASceneName then
    begin
      Result := FScenes[i];
      Exit;
    end;
  end;
end;

procedure TP2DSceneManager.ChangeScene(const ASceneName: string);
begin
  FNextScene := GetScene(ASceneName);
  if FNextScene = nil then
  begin
    TP2DLogger.Error('Scene not found: ' + ASceneName);
    Exit;
  end;
  FTransitioning := True;
  TP2DLogger.Info('Scene transition scheduled: ' + ASceneName);
end;

procedure TP2DSceneManager.ChangeSceneImmediate(const ASceneName: string);
var
  NewScene: TP2DScene;
begin
  NewScene := GetScene(ASceneName);
  if NewScene = nil then
  begin
    TP2DLogger.Error('Scene not found: ' + ASceneName);
    Exit;
  end;

  if Assigned(FCurrentScene) then
    FCurrentScene.Exit;

  FCurrentScene := NewScene;
  FCurrentScene.Enter;
  TP2DLogger.Info('Scene changed immediately: ' + ASceneName);
end;

procedure TP2DSceneManager.Update(DeltaTime: Double);
begin
  // Process scene transition
  if FTransitioning and Assigned(FNextScene) then
  begin
    if Assigned(FCurrentScene) then
      FCurrentScene.Exit;
    FCurrentScene := FNextScene;
    FCurrentScene.Enter;
    FNextScene := nil;
    FTransitioning := False;
  end;

  // Update current scene
  if Assigned(FCurrentScene) then
    FCurrentScene.Update(DeltaTime);
end;

procedure TP2DSceneManager.Render;
begin
  if Assigned(FCurrentScene) then
    FCurrentScene.Render;
end;

initialization

finalization
  TP2DSceneManager.FreeInstance;

end.
