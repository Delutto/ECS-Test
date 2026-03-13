unit P2D.Systems.SceneManager;

{$mode ObjFPC}{$H+}

{ =============================================================================
  P2D.Systems.SceneManager — TSceneManagerSystem

  PURPOSE
  ───────
  Wraps TSceneManager as a first-class ECS system so that scene transitions
  integrate naturally into the TWorld update/render loop managed by TEngine2D.

  Without this system the game class must manually call SceneManager.Update
  from OnUpdate and SceneManager.Render from OnRender. Those hook methods then
  exist solely to delegate to the manager, adding boilerplate to every game
  that uses scenes.

  With TSceneManagerSystem registered in TEngine2D's own TWorld, the engine
  loop drives scene management automatically:
    TWorld.Update  → TSceneManagerSystem.Update  → SceneManager.Update
    TWorld.Render  → TSceneManagerSystem.Render  → SceneManager.Render

  PRIORITY AND RENDER LAYER
  ─────────────────────────
  Priority = 0
    Scene transitions are processed at the very start of the update pass,
    before any other system runs. If a transition was scheduled at the end
    of the previous frame, the new scene is fully entered BEFORE physics,
    animation or input systems execute — preventing one frame of stale state.

  RenderLayer = rlScreen
    From the engine world's perspective, scene rendering is the outermost
    draw operation. Setting rlScreen ensures TWorld.RenderByLayer(rlScreen)
    calls this system last in the render pass.

  NO COMPONENT REQUIREMENTS
  ─────────────────────────
  This system never calls GetMatchingEntities. It delegates entirely to
  TSceneManager and does not inspect the entity graph.

  SCENE OWNERSHIP
  ───────────────
  TSceneManagerSystem owns the TScene2D objects added via AddScene
  (when AOwned=True, which is the default). When Shutdown is called it
  unregisters each scene (Exit + Unload via TSceneManager.UnregisterScene)
  and frees owned objects. TSceneManager holds only non-owning references.

  SHUTDOWN INTEGRATION
  ────────────────────
  TSceneManagerSystem.Shutdown is called by TWorld.Shutdown, which runs
  inside TEngine2D.Run BEFORE CloseAudioDevice and CloseWindow. This means
  scene lifecycle calls (DoExit, DoUnload) and asset releases happen while
  the raylib context is still fully open — the correct and safe window.
  TMarioGame.OnShutdown therefore only needs to release assets that live
  outside the scene graph (e.g. procedural textures).
  ============================================================================= }

interface

uses
   SysUtils,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Core.Scene;

type
  { Internal record: scene object + ownership flag. }
  TSceneEntry = record
    Scene: TScene2D;
    Owned: Boolean;
  end;

  TSceneManagerSystem = class(TSystem2D)
  private
    FSceneEntries: array of TSceneEntry;
    FSceneCount  : Integer;

  public
    constructor Create(AWorld: TWorldBase); override;
    destructor  Destroy; override;

    { AddScene: registers AScene with TSceneManager and stores a reference.
      If AOwned=True (default), Shutdown frees the scene object. }
    procedure AddScene(AScene: TScene2D; AOwned: Boolean = True);

    { SetInitialScene: synchronous transition to the named scene.
      Call after all scenes have been added. }
    procedure SetInitialScene(const AName: string);

    procedure Init;     override;
    procedure Update(ADelta: Single); override;
    procedure Render;   override;
    procedure Shutdown; override;
  end;

implementation

uses
   P2D.Utils.Logger;

constructor TSceneManagerSystem.Create(AWorld: TWorldBase);
begin
  inherited Create(AWorld);
  Priority     := 0;
  Name         := 'SceneManagerSystem';
  RenderLayer  := rlScreen;
  FSceneCount  := 0;
  SetLength(FSceneEntries, 0);
  Logger.Info('[SceneManagerSystem] Created');
end;

destructor TSceneManagerSystem.Destroy;
begin
  SetLength(FSceneEntries, 0);
  inherited;
end;

procedure TSceneManagerSystem.AddScene(AScene: TScene2D; AOwned: Boolean);
begin
  if not Assigned(AScene) then
  begin
    Logger.Warn('[SceneManagerSystem] AddScene: nil scene ignored');
    Exit;
  end;
  if FSceneCount >= Length(FSceneEntries) then
    SetLength(FSceneEntries, FSceneCount + 8);
  FSceneEntries[FSceneCount].Scene := AScene;
  FSceneEntries[FSceneCount].Owned := AOwned;
  Inc(FSceneCount);
  SceneManager.RegisterScene(AScene);
  Logger.Info('[SceneManagerSystem] Scene added: ' + AScene.Name);
end;

procedure TSceneManagerSystem.SetInitialScene(const AName: string);
begin
  SceneManager.ChangeSceneImmediate(AName);
end;

procedure TSceneManagerSystem.Init;
begin
  { No component requirements — this system drives the scene manager,
    not the entity graph. }
  Logger.Info('[SceneManagerSystem] Init');
end;

procedure TSceneManagerSystem.Update(ADelta: Single);
begin
  SceneManager.Update(ADelta);
end;

procedure TSceneManagerSystem.Render;
begin
  SceneManager.Render;
end;

procedure TSceneManagerSystem.Shutdown;
var
  I: Integer;
begin
  Logger.Info('[SceneManagerSystem] Shutdown — unregistering scenes');
  { Unregister in reverse order: most recently added first.
    UnregisterScene calls Exit (if active) + Unload, then removes the entry
    from TSceneManager. The raylib context is still open at this point. }
  for I := FSceneCount - 1 downto 0 do
  begin
    if Assigned(FSceneEntries[I].Scene) then
    begin
      SceneManager.UnregisterScene(FSceneEntries[I].Scene.Name);
      if FSceneEntries[I].Owned then
      begin
        FSceneEntries[I].Scene.Free;
        FSceneEntries[I].Scene := nil;
      end;
    end;
  end;
  FSceneCount := 0;
  SetLength(FSceneEntries, 0);
  Logger.Info('[SceneManagerSystem] Shutdown complete');
  inherited;
end;

end.
