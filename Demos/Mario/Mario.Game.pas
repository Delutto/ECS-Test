unit Mario.Game;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, raylib,
  P2D.Core.Engine, P2D.Core.World, P2D.Core.System,
  P2D.Systems.Physics, P2D.Systems.Collision,
  P2D.Systems.Animation, P2D.Systems.Render,
  P2D.Systems.Camera, P2D.Systems.TileMap,
  P2D.Components.Tags,
  Mario.ProceduralArt, Mario.Level,
  Mario.Systems.Input, Mario.Systems.Player,
  Mario.Systems.Enemy, Mario.Systems.HUD;

const
  SCREEN_W = 800;
  SCREEN_H = 480;

type
  TMarioGame = class
  private
    FEngine  : TEngine2D;
    FCamSys  : TCameraSystem;
    procedure RegisterSystems;
    procedure OnRestart;
  public
    constructor Create;
    destructor  Destroy; override;
    procedure Run;
  end;

implementation

// ---------------------------------------------------------------------------
constructor TMarioGame.Create;
begin
  inherited Create;
  FEngine := TEngine2D.Create(SCREEN_W, SCREEN_H, 'Pascal2D - Super Mario World Demo', 60);
  RegisterSystems;
end;

destructor TMarioGame.Destroy;
begin
  UnloadAssets;
  FEngine.Free;
  inherited;
end;

procedure TMarioGame.RegisterSystems;
var W: TWorld;
begin
  W := FEngine.World;

  // Register all systems (priority drives execution order)
  W.AddSystem(TPlayerInputSystem.Create(W));      // 1
  W.AddSystem(TEnemySystem.Create(W));             // 3
  W.AddSystem(TAnimationSystem.Create(W));         // 5
  W.AddSystem(TPlayerAnimSystem.Create(W));        // 7
  W.AddSystem(TPhysicsSystem.Create(W));           // 10
  W.AddSystem(TCollisionSystem.Create(W));         // 20
  W.AddSystem(TTileMapSystem.Create(W));           // 30  (render)
  W.AddSystem(TRenderSystem.Create(W));            // 100 (render)
  W.AddSystem(THUDSystem.Create(W, SCREEN_W, SCREEN_H)); // 200

  FCamSys := TCameraSystem.Create(W, SCREEN_W, SCREEN_H);
  W.AddSystem(FCamSys);
end;

procedure TMarioGame.OnRestart;
var
  E : P2D.Core.Entity.TEntity;
  IDs: array of P2D.Core.Types.TEntityID;
  I : Integer;
begin
  // Collect all entity IDs
  SetLength(IDs, FEngine.World.Entities.GetAll.Count);
  for I := 0 to FEngine.World.Entities.GetAll.Count - 1 do
    IDs[I] := FEngine.World.Entities.GetAll[I].ID;
  for I := 0 to High(IDs) do
    FEngine.World.DestroyEntity(IDs[I]);
  FEngine.World.Entities.PurgeDestroyed;

  LoadLevel(FEngine.World);
  FCamSys.Init;
end;

procedure TMarioGame.Run;
var
  Delta: Single;
begin
  InitWindow(SCREEN_W, SCREEN_H, 'Pascal2D - Super Mario World Demo');
  SetTargetFPS(60);
  InitAudioDevice;

  // Generate procedural assets (must be after InitWindow / OpenGL context)
  GenerateAssets;

  // Load first level entities
  LoadLevel(FEngine.World);

  // Init systems
  FEngine.World.Init;
  FCamSys.Init;

  // Main loop
  while not WindowShouldClose do
  begin
    Delta := GetFrameTime;

    // Handle restart
    if IsKeyPressed(KEY_R) then OnRestart;

    FEngine.World.Update(Delta);

    BeginDrawing;
      ClearBackground(RayColor(92, 148, 252, 255));

      // Draw scrolling background
      DrawTextureEx(TexBackground,
        Vector2(-FCamSys.GetRaylibCamera.Target.X * 0.3 +
                SCREEN_W / 2 - 256, 0),
        0, 2, WHITE);

      FCamSys.BeginCameraMode;
        // TileMap rendered inside camera mode (TTileMapSystem.Render)
        // Sprites rendered inside camera mode (TRenderSystem.Render)
        FEngine.World.Render;   // calls all system Render() methods
      FCamSys.EndCameraMode;

      // HUD is drawn OUTSIDE camera (screen-space)
      // THUDSystem.Render is called by World.Render but uses screen coords

      DrawFPS(SCREEN_W - 80, SCREEN_H - 20);
    EndDrawing;
  end;

  FEngine.World.Shutdown;
  UnloadAssets;
  CloseAudioDevice;
  CloseWindow;
end;

end.