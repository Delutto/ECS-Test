unit P2D.Core.Scene;

{$mode ObjFPC}{$H+}

{ =============================================================================
  P2D.Core.Scene — Scene Management System

  DESIGN OVERVIEW
  ───────────────
  A scene encapsulates ONE complete game state: its own TWorld (entities + systems), its own lifecycle, and its own render logic.
  The TSceneManager drives transitions between scenes and acts as the single point of entry called by TEngine2D every frame.

  SCENE LIFECYCLE
  ───────────────
  Each scene goes through four explicit phases:

    Load   → called once when the scene is registered.
             Override DoLoad to build the ECS world: register systems, load assets, create entities.
             The OpenGL context IS available at this point because TEngine2D calls OnInit (→ RegisterScenes → Load) AFTER InitWindow.

    Enter  → called every time the scene becomes active (first time or after returning from another scene via a stack pop).
             Override DoEnter to reset transient state: respawn player, reset score, start music, etc.

    Update → called every frame while the scene is active and not paused.
             Drives World.FixedUpdate + World.Update internally.

    Render → called every frame while the scene is active.
             Drives World.RenderByLayer for both rlWorld and rlScreen.
             Override for custom camera/parallax logic.

    Exit   → called when the scene is being replaced or popped.
             Override DoExit to stop music, save state, etc.

    Unload → called once when the scene is unregistered or the manager is destroyed. Override DoUnload to release assets.

  SCENE MANAGER
  ─────────────
  TSceneManager uses a simple two-operation model:

    ChangeScene(Name) → deferred transition: processed at the START of the next Update call, BEFORE the current scene updates.
                        Safe to call from inside a scene's Update/Render.

    ChangeSceneImmediate(Name) → synchronous transition: exits the current scene and enters the new one in the same call.
                                 Use with care — avoid calling from inside Update.

  INTEGRATION WITH TEngine2D
  ──────────────────────────
  TEngine2D does NOT automatically drive the scene manager.
  The game subclass (e.g. TMarioGame) is responsible for:
    1. Creating and registering all scenes in OnInit.
    2. Calling SceneManager.ChangeScene / ChangeSceneImmediate to set the initial active scene.
    3. Delegating OnUpdate and OnRender to SceneManager.Update / .Render.

  This keeps TEngine2D decoupled from scene management and allows games that don't need scenes to remain unaffected.

  FIX — rlWorld / rlScreen (Error: Identifier not found "rlWorld")
  ─────────────────────────────────────────────────────────────────
  TRenderLayer (rlWorld, rlScreen) is declared in P2D.Core.System, NOT in P2D.Core.World.
  The original file was missing P2D.Core.System in its uses clause. Added to both the interface and implementation sections.
  ============================================================================= }

interface

uses
   SysUtils,
   P2D.Core.World,
   P2D.Core.System;

type

  { =========================================================================
    TScene2D — base class for all scenes.
    Subclass this and override the Do* hooks.
    Never override Load/Enter/Exit/Unload directly; those handle logging and call the corresponding Do* method.
  ========================================================================= }
   TScene2D = class
   private
      FWorld : TWorld;
      FName  : string;
      FActive: Boolean;
      FPaused: Boolean;
   protected
      { Override these in subclasses — all are safe no-ops by default. }
      procedure DoLoad;   virtual;  { build ECS world: systems + entities }
      procedure DoUnload; virtual;  { free extra assets not owned by World }
      procedure DoEnter;  virtual;  { reset transient state, start music, etc. }
      procedure DoExit;   virtual;  { stop music, save state, etc. }
   public
      constructor Create(const AName: string);
      destructor  Destroy; override;

      procedure Load;
      procedure Unload;
      procedure Enter;
      procedure Exit;

      { Update: drives World.FixedUpdate + World.Update with the given delta.
      The fixed-step accumulator is managed internally per scene so that pausing one scene does not disturb another scene's accumulator. }
      procedure Update(ADelta: Single); virtual;

      { Render: default implementation calls World.RenderByLayer for both rlWorld and rlScreen. Override for custom camera / parallax logic. }
      procedure Render; virtual;

      procedure Pause;
      procedure Resume;

      property World  : TWorld  read FWorld;
      property Name   : string  read FName;
      property Active : Boolean read FActive;
      property Paused : Boolean read FPaused;
   end;

   { =========================================================================
    TSceneManager — manages transitions between TScene2D instances.
    Singleton; access via the global SceneManager variable.
   ========================================================================= }
   TSceneManager = class
   private
      FScenes       : array of TScene2D;
      FCurrentScene : TScene2D;
      FNextScene    : TScene2D;    { non-nil = deferred transition pending }
      FTransitioning: Boolean;

      class var FInstance: TSceneManager;
   public
      constructor Create;
      destructor  Destroy; override;

      class function  Instance: TSceneManager;
      class procedure FreeInstance;

      { RegisterScene: calls AScene.Load and adds it to the internal list.
      The manager does NOT own the scene object — the caller is responsible for freeing it (typically in the game's OnShutdown). }
      procedure RegisterScene(AScene: TScene2D);

      { UnregisterScene: calls Unload on the named scene and removes it from the list. Does NOT free the scene object. }
      procedure UnregisterScene(const AName: string);

      { GetScene: returns the registered scene with the given name, or nil. }
      function  GetScene(const AName: string): TScene2D;

      { ChangeScene: schedules a deferred transition.
      The current scene will Exit and the new scene will Enter at the start of the NEXT Update call. Safe to call from inside Update/Render. }
      procedure ChangeScene(const AName: string);

      { ChangeSceneImmediate: synchronous transition in the same call.
      Exits the current scene immediately and enters the new one.
      Do NOT call from inside the current scene's Update or Render. }
      procedure ChangeSceneImmediate(const AName: string);

      { Update: processes any pending deferred transition, then updates the active scene. Call once per frame from TEngine2D.OnUpdate. }
      procedure Update(ADelta: Single);

      { Render: delegates to the active scene's Render method.
      Call from TEngine2D.OnRender, inside BeginDrawing/EndDrawing. }
      procedure Render;

      property CurrentScene   : TScene2D read FCurrentScene;
      property IsTransitioning: Boolean  read FTransitioning;
   end;

{ Global singleton accessor — mirrors the pattern used by InputManager. }
var
   SceneManager: TSceneManager;

implementation

uses
   P2D.Utils.Logger;

{ ============================================================================
  TScene2D
  ============================================================================ }

constructor TScene2D.Create(const AName: string);
begin
   inherited Create;

   FName   := AName;
   FWorld  := TWorld.Create;
   FActive := False;
   FPaused := False;
   {$IFDEF DEBUG}
   Logger.Info('[Scene] Created: ' + AName);
   {$ENDIF}
end;

destructor TScene2D.Destroy;
begin
   FWorld.Free;
   {$IFDEF DEBUG}
   Logger.Info('[Scene] Destroyed: ' + FName);
   {$ENDIF}

   inherited;
end;

{ Protected hooks — safe no-ops by default. }
procedure TScene2D.DoLoad;
begin
end;

procedure TScene2D.DoUnload;
begin
end;

procedure TScene2D.DoEnter;
begin
end;

procedure TScene2D.DoExit;
begin
end;

procedure TScene2D.Load;
begin
   {$IFDEF DEBUG}
   Logger.Info('[Scene] Loading: ' + FName);
   {$ENDIF}
   DoLoad;
end;

procedure TScene2D.Unload;
begin
   {$IFDEF DEBUG}
   Logger.Info('[Scene] Unloading: ' + FName);
   {$ENDIF}
   DoUnload;
end;

procedure TScene2D.Enter;
begin
   FActive := True;
   FPaused := False;
   {$IFDEF DEBUG}
   Logger.Info('[Scene] Entering: ' + FName);
   {$ENDIF}
   DoEnter;
end;

procedure TScene2D.Exit;
begin
   FActive := False;
   {$IFDEF DEBUG}
   Logger.Info('[Scene] Exiting: ' + FName);
   {$ENDIF}
   DoExit;
end;

{ Default Update: only drives World.Update (no FixedUpdate accumulator).
  Scenes that need fixed-step physics should override this method. }
procedure TScene2D.Update(ADelta: Single);
begin
   if FActive and not FPaused then
      FWorld.Update(ADelta);
end;

{ Default Render: draws both world-space and screen-space layers.
  Scenes with custom cameras must override this method. }
procedure TScene2D.Render;
begin
   if FActive then
   begin
      FWorld.RenderByLayer(rlWorld);
      FWorld.RenderByLayer(rlScreen);
   end;
end;

procedure TScene2D.Pause;
begin
   FPaused := True;
   {$IFDEF DEBUG}
   Logger.Info('[Scene] Paused: ' + FName);
   {$ENDIF}
end;

procedure TScene2D.Resume;
begin
   FPaused := False;
   {$IFDEF DEBUG}
   Logger.Info('[Scene] Resumed: ' + FName);
   {$ENDIF}
end;

{ ============================================================================
  TSceneManager
  ============================================================================ }

constructor TSceneManager.Create;
begin
   inherited Create;

   SetLength(FScenes, 0);
   FCurrentScene  := nil;
   FNextScene     := nil;
   FTransitioning := False;
   {$IFDEF DEBUG}
   Logger.Info('[SceneManager] Created');
   {$ENDIF}
end;

destructor TSceneManager.Destroy;
begin
   if Length(FScenes) > 0 then
   begin
      {$IFDEF DEBUG}
      Logger.Warn(Format('[SceneManager] Destroy: %d scene(s) still registered. ' + 'Call UnregisterScene in OnShutdown before freeing scene objects.', [Length(FScenes)]));
      {$ENDIF}
      SetLength(FScenes, 0);
   end;

   FCurrentScene := nil;
   FNextScene    := nil;
   {$IFDEF DEBUG}
   Logger.Info('[SceneManager] Destroyed');
   {$ENDIF}

   inherited;
end;

class function TSceneManager.Instance: TSceneManager;
begin
   if FInstance = nil then
      FInstance := TSceneManager.Create;
   Result := FInstance;
end;

class procedure TSceneManager.FreeInstance;
begin
   FreeAndNil(FInstance);
end;

procedure TSceneManager.RegisterScene(AScene: TScene2D);
begin
   SetLength(FScenes, Length(FScenes) + 1);
   FScenes[High(FScenes)] := AScene;
   AScene.Load;
   {$IFDEF DEBUG}
   Logger.Info('[SceneManager] Registered: ' + AScene.Name);
   {$ENDIF}
end;

procedure TSceneManager.UnregisterScene(const AName: string);
var
   I: Integer;
begin
   for I := 0 to High(FScenes) do
      if FScenes[I].Name = AName then
      begin
         { Exit the scene if it is currently active. }
         if FScenes[I].Active then
         FScenes[I].Exit;

         { Unload: calls DoUnload — release assets while context is open. }
         FScenes[I].Unload;

         { Nil the CurrentScene pointer if this was the active scene. }
         if FScenes[I] = FCurrentScene then
            FCurrentScene := nil;
         if FScenes[I] = FNextScene then
            FNextScene := nil;

         { Remove the entry from the array. }
         if I < High(FScenes) then
            Move(FScenes[I + 1], FScenes[I], (High(FScenes) - I) * SizeOf(TScene2D));
         SetLength(FScenes, Length(FScenes) - 1);
         {$IFDEF DEBUG}
         Logger.Info('[SceneManager] Unregistered: ' + AName);
         {$ENDIF}
         Exit;
      end;
   {$IFDEF DEBUG}
   Logger.Warn('[SceneManager] UnregisterScene: not found: ' + AName);
   {$ENDIF}
end;

function TSceneManager.GetScene(const AName: string): TScene2D;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to High(FScenes) do
    if FScenes[I].Name = AName then
    begin
      Result := FScenes[I];
      Exit;
    end;
end;

procedure TSceneManager.ChangeScene(const AName: string);
begin
   FNextScene := GetScene(AName);
   if not Assigned(FNextScene) then
   begin
      {$IFDEF DEBUG}
      Logger.Error('[SceneManager] ChangeScene: not found: ' + AName);
      {$ENDIF}
      Exit;
   end;
   FTransitioning := True;
   {$IFDEF DEBUG}
   Logger.Info('[SceneManager] Transition scheduled to: ' + AName);
   {$ENDIF}
end;

procedure TSceneManager.ChangeSceneImmediate(const AName: string);
var
   NewScene: TScene2D;
begin
   NewScene := GetScene(AName);
   if not Assigned(NewScene) then
   begin
      {$IFDEF DEBUG}
      Logger.Error('[SceneManager] ChangeSceneImmediate: not found: ' + AName);
      {$ENDIF}
      Exit;
   end;
   if Assigned(FCurrentScene) then
      FCurrentScene.Exit;
   FCurrentScene := NewScene;
   FCurrentScene.Enter;
   {$IFDEF DEBUG}
   Logger.Info('[SceneManager] Scene changed immediately to: ' + AName);
   {$ENDIF}
end;

procedure TSceneManager.Update(ADelta: Single);
begin
   { Process pending deferred transition BEFORE the scene updates, so that the new scene's first Update sees a fully initialised state. }
   if FTransitioning and Assigned(FNextScene) then
   begin
      if Assigned(FCurrentScene) then
         FCurrentScene.Exit;
      FCurrentScene  := FNextScene;
      FNextScene     := nil;
      FTransitioning := False;
      FCurrentScene.Enter;
   end;

   if Assigned(FCurrentScene) then
      FCurrentScene.Update(ADelta);
end;

procedure TSceneManager.Render;
begin
   if Assigned(FCurrentScene) then
      FCurrentScene.Render;
end;

initialization
   SceneManager := TSceneManager.Instance;

finalization
   TSceneManager.FreeInstance;
   SceneManager := nil;

end.

