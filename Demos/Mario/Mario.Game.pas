unit Mario.Game;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, raylib,
  P2D.Core.Engine, P2D.Core.World, P2D.Core.System, P2D.Systems.Physics, P2D.Systems.Collision,
  P2D.Systems.Animation, P2D.Systems.Render, P2D.Systems.Camera, P2D.Systems.TileMap, P2D.Components.Tags,
  Mario.ProceduralArt, Mario.Level, Mario.Systems.Input, Mario.Systems.Player, Mario.Systems.Enemy, Mario.Systems.HUD;

const
   SCREEN_W  = 800;
   SCREEN_H  = 480;
   FIXED_DT  = 1.0 / 60.0; // passo físico fixo (60 Hz)
   MAX_DELTA = 0.25;       // teto de delta — evita "spiral of death"

type
   TMarioGame = class
   private
      FEngine : TEngine2D;
      FCamSys : TCameraSystem;
      procedure RegisterSystems;
      procedure OnRestart;
   public
      constructor Create;
      destructor  Destroy; override;
      procedure Run;
   end;

implementation

uses
   P2D.Core.Entity,
   P2D.Core.Types;

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
var
   W: TWorld;
begin
   W := FEngine.World;

   // rlWorld (padrão)
   W.AddSystem(TPlayerInputSystem.Create(W));             //   1 — Update Input
   W.AddSystem(TEnemySystem.Create(W));                   //   3 — Update Enemy
   W.AddSystem(TAnimationSystem.Create(W));               //   5 — Update Anim
   W.AddSystem(TPlayerAnimSystem.Create(W));              //   7 — Update PlayerAnim
   W.AddSystem(TPhysicsSystem.Create(W));                 //  10 — FixedUpdate Physics
   W.AddSystem(TCollisionSystem.Create(W));               //  20 — FixedUpdate Collision
   W.AddSystem(TTileMapSystem.Create(W));                 //  30 — Render TileMap
   W.AddSystem(TRenderSystem.Create(W));                  // 100 — Render Sprites

   FCamSys := TCameraSystem.Create(W, SCREEN_W, SCREEN_H);
   W.AddSystem(FCamSys);                                  //  15 — Update Camera

   // rlScreen
   // Render: HUD(200) — coordenadas de tela, fora de BeginMode2D
   W.AddSystem(THUDSystem.Create(W, SCREEN_W, SCREEN_H)); // 200 — Render HUD
end;

procedure TMarioGame.OnRestart;
var
   IDs: array of TEntityID;
   I  : Integer;
begin
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
   Delta, Accumulator: Single;
begin
   InitWindow(SCREEN_W, SCREEN_H, 'Pascal2D - Super Mario World Demo');
   SetTargetFPS(60);
   InitAudioDevice;

   GenerateAssets; // requer contexto OpenGL — deve vir após InitWindow
   LoadLevel(FEngine.World);
   FEngine.World.Init;
   FCamSys.Init;

   Accumulator := 0.0;

   while not WindowShouldClose do
   begin
      // Clamp: evita passos físicos excessivos após lag spikes
      Delta       := Min(GetFrameTime, MAX_DELTA);
      Accumulator := Accumulator + Delta;

      if IsKeyPressed(KEY_R) then
         OnRestart;

    { Passos físicos fixos
      TPhysicsSystem e TCollisionSystem executam aqui, com delta constante.
      Pode rodar 0, 1 ou mais vezes por frame dependendo do tempo decorrido.}
      while Accumulator >= FIXED_DT do
      begin
         FEngine.World.FixedUpdate(FIXED_DT);
         Accumulator := Accumulator - FIXED_DT;
      end;

    { Lógica variável (1× por frame)
      Input, animação, câmera — tolerantes a delta variável.
      PurgeDestroyed é chamado internamente ao final de Update.}
      FEngine.World.Update(Delta);

      // Render
      BeginDrawing;
         ClearBackground(ColorCreate(92, 148, 252, 255));

         // Parallax background (antes da câmera — sem transformação)
         DrawTextureEx(TexBackground, Vector2Create(-FCamSys.GetRaylibCamera.Target.X * 0.3 +  SCREEN_W / 2 - 256, 0), 0, 2, WHITE);

         // World-space: TileMap(30) + Sprites(100)
         FCamSys.BeginCameraMode;
            FEngine.World.RenderByLayer(rlWorld);
         FCamSys.EndCameraMode;

         // Screen-space: HUD(200)
         // Chamado FORA de BeginMode2D — coordenadas de tela absolutas.
         FEngine.World.RenderByLayer(rlScreen);

         DrawFPS(SCREEN_W - 80, SCREEN_H - 20);
      EndDrawing;
   end;

   FEngine.World.Shutdown;
   UnloadAssets;
   CloseAudioDevice;
   CloseWindow;
end;

end.

