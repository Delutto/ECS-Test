unit Mario.Game;

{$mode ObjFPC}{$H+}

interface

uses
   SysUtils, raylib,
   P2D.Core.Engine,
   P2D.Core.World,
   P2D.Core.System,
   P2D.Systems.Audio,
   P2D.Systems.Physics,
   P2D.Systems.Collision,
   P2D.Systems.Animation,
   P2D.Systems.Particles,
   P2D.Systems.Render,
   P2D.Systems.Camera,
   P2D.Systems.TileMap,
   P2D.Components.Tags,
   Mario.ProceduralArt,
   Mario.Level,
   Mario.Systems.Input,
   Mario.Systems.Player,
   Mario.Systems.Enemy,
   Mario.Systems.HUD,
   Mario.Systems.GameRules,
   Mario.Systems.Audio,
   Mario.InputSetup;

type
   TMarioGame = class(TEngine2D)
   private
      FCamSys: TCameraSystem;
      procedure RegisterSystems;
      procedure DoRestart;
   protected
      procedure OnInit;                  override;
      procedure OnUpdate(ADelta: Single); override;
      procedure OnRender;                override;
      procedure OnShutdown;              override;
   public
      constructor Create;
   end;

implementation

uses
   P2D.Core.Entity,
   P2D.Core.Types,
   P2D.Core.ResourceManager;

constructor TMarioGame.Create;
begin
   inherited Create(800, 480, 'Pascal2D - Super Mario World Demo', 60);
end;

procedure TMarioGame.RegisterSystems;
var
   W: TWorld;
begin
   W := World;

   { ── Sistemas de gameplay (Update) ──────────────────────────────────────── }
   W.AddSystem(TPlayerInputSystem.Create(W));    // prioridade 1
   W.AddSystem(TEnemySystem.Create(W));          // prioridade 3
   W.AddSystem(TAnimationSystem.Create(W));      // prioridade 5
   W.AddSystem(TPlayerAnimSystem.Create(W));     // prioridade 8

   { ── Sistemas de física (FixedUpdate) ───────────────────────────────────── }
   W.AddSystem(TPlayerPhysicsSystem.Create(W));  // prioridade 7
   W.AddSystem(TPhysicsSystem.Create(W));        // prioridade 10
   W.AddSystem(TCollisionSystem.Create(W));      // prioridade 20

   { ── Regras de jogo (eventos de overlap) ────────────────────────────────── }
   W.AddSystem(TGameRulesSystem.Create(W));      // prioridade 25

   { ── Áudio (reage a eventos de gameplay) ────────────────────────────────── }
   W.AddSystem(TMarioAudioSystem.Create(W));     // prioridade 50

   { ── Render: tilemap → sprites → câmera → HUD ───────────────────────────── }
   W.AddSystem(TTileMapSystem.Create(W));        // prioridade 30
   W.AddSystem(TRenderSystem.Create(W));         // prioridade 100

   FCamSys := TCameraSystem.Create(W, ScreenW, ScreenH);
   W.AddSystem(FCamSys);                         // prioridade 15

   W.AddSystem(THUDSystem.Create(W, ScreenW, ScreenH)); // prioridade 200
end;

procedure TMarioGame.OnInit;
begin
   SetupPlayerInput;  // registra bindings no InputManager
   GenerateAssets;    // texturas procedurais (requer contexto OpenGL ativo)
   RegisterSystems;   // registra sistemas no World
   LoadLevel(World);  // cria entidades (inclui CreateMusicPlayer)
end;

procedure TMarioGame.OnUpdate(ADelta: Single);
begin
   if IsKeyPressed(KEY_R) then
      DoRestart;
end;

procedure TMarioGame.OnRender;
var
   Cam: TCamera2D;
begin
   ClearBackground(ColorCreate(92, 148, 252, 255));

   { Parallax background }
   Cam := FCamSys.GetRaylibCamera;
   DrawTextureEx(TexBackground,
      Vector2Create(-Cam.Target.X * 0.3 + ScreenW / 2 - 256, 0),
      0, 2, WHITE);

   { Renderização em espaço de câmera }
   FCamSys.BeginCameraMode;
      World.RenderByLayer(rlWorld);
   FCamSys.EndCameraMode;

   { HUD em espaço de tela }
   World.RenderByLayer(rlScreen);

   DrawFPS(ScreenW - 80, ScreenH - 20);
end;

procedure TMarioGame.OnShutdown;
begin
   UnloadAssets;
   { O TResourceManager2D é liberado automaticamente na finalization da unit }
end;

{ DoRestart — Reinicializa completamente o estado do jogo.
  ─────────────────────────────────────────────────────────────────────────────
  Sequência correta de 5 etapas:

    1. Parar música   — chamada direta, antes do EventBus ser limpo.
    2. ShutdownSystems — reseta TODOS os sistemas (cancela subscrições,
                         libera referências a entidades, limpa EventBus,
                         invalida caches, reseta FShutdownCalled).
    3. Destruir entidades — marca e purga todas as entidades existentes.
    4. LoadLevel       — recria todas as entidades do nível.
    5. World.Init      — reinicializa TODOS os sistemas com as novas entidades.
                         TCameraSystem.Init localiza a nova câmera e o novo
                         player. TMarioAudioSystem.Init resubscreve eventos
                         e inicia a música com AutoPlay=True. Nenhum sistema
                         precisa ser tratado individualmente.
  ───────────────────────────────────────────────────────────────────────────── }
procedure TMarioGame.DoRestart;
var
   AudioSys : TAudioSystem;
   IDs      : array of TEntityID;
   I        : Integer;
begin
   { ── 1. Para a música DIRETAMENTE, antes de qualquer outra operação. ────────
      Não publicamos um evento porque o EventBus será limpo dentro de
      ShutdownSystems() — qualquer evento publicado aqui seria descartado
      antes de chegar ao handler do TAudioSystem. }
   AudioSys := TAudioSystem(World.GetSystem(TMarioAudioSystem));
   if Assigned(AudioSys) then
      AudioSys.StopAllMusic;

   { ── 2. Shutdown ordenado de TODOS os sistemas. ──────────────────────────────
      World.ShutdownSystems() executa, para cada sistema habilitado:
        • S.Shutdown() — cancela subscrições no EventBus (TGameRulesSystem,
          TMarioAudioSystem, TAudioSystem), libera referências diretas a
          entidades (ex: FCamEntity/FTarget em TCameraSystem), reseta flags.
      Depois limpa o EventBus, invalida todos os caches e reseta
      FShutdownCalled para que World.Init() possa ser chamado a seguir. }
   World.ShutdownSystems;

   { ── 3. Marca e purga todas as entidades existentes. ─────────────────────────
      DestroyEntity() marca cada entidade como Alive=False e invalida os
      caches dos sistemas. PurgeDestroyed() remove-as da lista de entidades
      ativas, liberando memória. }
   SetLength(IDs, World.Entities.GetAll.Count);
   for I := 0 to World.Entities.GetAll.Count - 1 do
      IDs[I] := World.Entities.GetAll[I].ID;

   for I := 0 to High(IDs) do
      World.DestroyEntity(IDs[I]);

   World.Entities.PurgeDestroyed;

   { ── 4. Recria todas as entidades do nível. ───────────────────────────────────
      LoadLevel cria: TileMap, Player, Goombas, Coins, Camera, MusicPlayer.
      Cada CreateEntity() chama InvalidateAllSystemCaches() internamente,
      garantindo que os caches estejam sujos antes do próximo Init(). }
   LoadLevel(World);

   { ── 5. Reinicializa TODOS os sistemas com as novas entidades. ────────────────
      World.Init() ordena os sistemas por prioridade e chama S.Init() em cada
      um. Não há mais necessidade de tratar qualquer sistema individualmente:

        • TCameraSystem.Init   → localiza a nova entidade Camera e o novo
                                 Player por component scan, atualiza FCamEntity
                                 e FTarget com os IDs corretos.
        • TGameRulesSystem.Init → resubscreve TEntityOverlapEvent no EventBus.
        • TMarioAudioSystem.Init → resubscreve todos os eventos de gameplay e
                                   inicia a música (AutoPlay=True na nova
                                   entidade MusicPlayer criada em LoadLevel).
        • Todos os demais sistemas → reconstruirão seus caches na primeira
                                     chamada a GetMatchingEntities(). }
   World.Init;
end;

end.

