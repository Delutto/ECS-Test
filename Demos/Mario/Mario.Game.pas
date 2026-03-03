unit Mario.Game;

{$mode objfpc}{$H+}

interface

uses
	SysUtils, Math, raylib,
	P2D.Core.Engine,
	P2D.Core.World,
	P2D.Core.System,
	P2D.Systems.Physics,
	P2D.Systems.Collision,
	P2D.Systems.Animation,
	P2D.Systems.Render,
	P2D.Systems.Camera,
	P2D.Systems.TileMap,
	P2D.Components.Tags,
	Mario.ProceduralArt,
	Mario.Level,
	Mario.Systems.Input,
	Mario.Systems.Player,
	Mario.Systems.Enemy,
	Mario.Systems.HUD;

type
   { -------------------------------------------------------------------------
   TMarioGame — Demo Super Mario World.

   Herda de TEngine2D e sobrescreve os quatro hooks do ciclo de vida:
      OnInit     → gera assets procedurais, registra sistemas, carrega level
      OnUpdate   → verifica restart (KEY_R)
      OnRender   → parallax + world-space (câmera) + screen-space (HUD)
      OnShutdown → descarrega assets
   -------------------------------------------------------------------------}
   TMarioGame = class(TEngine2D)
   private
      FCamSys: TCameraSystem;

      procedure RegisterSystems;
      procedure DoRestart;
   protected
      procedure OnInit; override;
      procedure OnUpdate(ADelta: Single); override;
      procedure OnRender; override;
      procedure OnShutdown; override;
   public
      constructor Create;
   end;

implementation

uses
   P2D.Core.Entity,
   P2D.Core.Types;

{ TMarioGame }

constructor TMarioGame.Create;
begin
   { Delega dimensões, título e FPS ao TEngine2D. }
   inherited Create(800, 480, 'Pascal2D - Super Mario World Demo', 60);
end;

{ Registra todos os sistemas no World.
  Chamado em OnInit, antes de FWorld.Init, para que os sistemas estejam prontos quando TWorld.Init invocar S.Init em cada um. }
procedure TMarioGame.RegisterSystems;
var
   W: TWorld;
begin
   W := World;

   { rlWorld (padrão) — Update e FixedUpdate }
   W.AddSystem(TPlayerInputSystem.Create(W));          //   1 — Input do jogador
   W.AddSystem(TEnemySystem.Create(W));                //   3 — IA dos inimigos
   W.AddSystem(TAnimationSystem.Create(W));            //   5 — Avança frames de animação
   W.AddSystem(TPlayerAnimSystem.Create(W));           //   7 — Seleciona animação do player
   W.AddSystem(TPhysicsSystem.Create(W));              //  10 — Integração física (FixedUpdate)
   W.AddSystem(TCollisionSystem.Create(W));            //  20 — Detecção e resolução (FixedUpdate)

   { rlWorld — Render }
   W.AddSystem(TTileMapSystem.Create(W));              //  30 — Desenha tiles
   W.AddSystem(TRenderSystem.Create(W));               // 100 — Desenha sprites

   { Câmera — Update (priority 15, entre física e render) }
   FCamSys := TCameraSystem.Create(W, ScreenW, ScreenH);
   W.AddSystem(FCamSys);

   { rlScreen — Render fora de BeginMode2D }
   W.AddSystem(THUDSystem.Create(W, ScreenW, ScreenH));// 200 — HUD
end;

{ OnInit: chamado por TEngine2D.Run após InitWindow e InitAudioDevice.
  O contexto OpenGL já está ativo, então GenerateAssets pode ser chamado. }
procedure TMarioGame.OnInit;
begin
   { 1. Gera todas as texturas proceduralmente (requer OpenGL ativo). }
   GenerateAssets;

   { 2. Registra sistemas no World (sem entidades ainda — caches vazios). }
   RegisterSystems;

   { 3. Cria entidades do level (Player, Goombas, Moedas, TileMap, Câmera).
       Após LoadLevel, TWorld.Init (chamado por TEngine2D.Run logo depois) invocará TCameraSystem.Init, que localizará câmera e player. }
   LoadLevel(World);
end;

{ DoRestart: destrói todas as entidades, recarrega o level e re-vincula a câmera.
  Os sistemas NÃO são recriados — apenas as entidades são substituídas. }
procedure TMarioGame.DoRestart;
var
   IDs: array of TEntityID;
   I  : Integer;
begin
   { Coleta IDs antes de destruir para evitar modificar a lista durante iteração. }
   SetLength(IDs, World.Entities.GetAll.Count);
   for I := 0 to World.Entities.GetAll.Count - 1 do
      IDs[I] := World.Entities.GetAll[I].ID;

   { Marca todas as entidades como mortas e remove imediatamente. }
   for I := 0 to High(IDs) do
      World.DestroyEntity(IDs[I]);
   World.Entities.PurgeDestroyed;

   { Recria entidades do level. }
   LoadLevel(World);

   { Re-vincula câmera e player no CameraSystem, pois as entidades antigas foram destruídas e novas foram criadas com novos IDs. }
   FCamSys.Init;
end;

{ OnUpdate: chamado 1× por frame após FWorld.Update. }
procedure TMarioGame.OnUpdate(ADelta: Single);
begin
   if IsKeyPressed(KEY_R) then
      DoRestart;
end;

{ OnRender: chamado entre BeginDrawing/EndDrawing por TEngine2D.Run. }
procedure TMarioGame.OnRender;
begin
   { Fundo do céu (cor base). }
   ClearBackground(ColorCreate(92, 148, 252, 255));

   { Parallax background — sem transformação de câmera.
     Desloca 30% da posição da câmera para criar profundidade. }
   DrawTextureEx(TexBackground,
                 Vector2Create(-FCamSys.GetRaylibCamera.Target.X * 0.3 + ScreenW / 2 - 256, 0),
                 0,    // Rotação
                 2,    // Escala
                 WHITE);

   { World-space: TileMap (priority 30) e Sprites (priority 100).
     Renderizados dentro do espaço da câmera 2D. }
   FCamSys.BeginCameraMode;
   World.RenderByLayer(rlWorld);
   FCamSys.EndCameraMode;

   { Screen-space: HUD (priority 200).
     Renderizado fora de BeginMode2D — coordenadas de tela absolutas. }
   World.RenderByLayer(rlScreen);

   DrawFPS(ScreenW - 80, ScreenH - 20);
end;

{ OnShutdown: chamado por TEngine2D.Run após FWorld.Shutdown e antes de CloseWindow. }
procedure TMarioGame.OnShutdown;
begin
   UnloadAssets;
end;

end.
