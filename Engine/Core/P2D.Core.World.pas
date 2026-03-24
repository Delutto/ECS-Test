unit P2D.Core.World;

{$mode objfpc}
{$H+}

interface

uses
   SysUtils,
   fgl,
   P2D.Core.Component,
   P2D.Core.ComponentRegistry,
   P2D.Core.Event,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.System;

type
   TSystemList = specialize TFPGObjectList<TSystem2D>;

   { TWorld }

   TWorld = class(TWorldBase)
   private
      FEntities: TEntityManager;
      FSystems: TSystemList;
      FEventBus: TEventBus;
      FShutdownCalled: Boolean;
      FStructureDirty: Boolean;

      procedure SortSystems;
      procedure InvalidateAllSystemCaches;
      procedure MarkStructureDirty; inline;
   protected
      function GetEntities: TEntityManager; override;
      function GetEventBus: TEventBus; override;
   public
      constructor Create;
      destructor Destroy; override;

      { --- Entidades --------------------------------------------------------- }
      function CreateEntity(const AName: String = ''): TEntity; override;

      { Criação com pooling }
      function CreatePooledEntity(const ATag: String; const AName: String = ''): TEntity;

      procedure DestroyEntity(AID: TEntityID); override;
      procedure DestroyAllEntities; override;
      function GetEntity(AID: TEntityID): TEntity; override;

      { Pool Management }
      procedure ConfigureEntityPool(const ATag: String; AInitialSize, AMaxSize: Integer);
      procedure PreallocateEntityPool(const ATag: String; ACount: Integer);
      procedure ClearEntityPool(const ATag: String);

      { --- Sistemas ---------------------------------------------------------- }
      function AddSystem(ASystem: TSystem2D): TSystem2D;
      function GetSystem(AClass: TSystem2DClass): TSystem2D;

      { --- Loop principal ---------------------------------------------------- }
      procedure Init;
      procedure FixedUpdate(AFixedDelta: Single); override;
      function GetEntitySignature(AEntity: TEntity): TComponentSignature; override;
      procedure Update(ADelta: Single);
      procedure Render;
      procedure RenderByLayer(ALayer: TRenderLayer); override;

      { Shutdown FINAL — chamado uma única vez ao encerrar o programa.
        Protegido por FShutdownCalled para evitar dupla execução.
        NÃO use para reinício de nível; use ShutdownSystems para isso. }
      procedure Shutdown;

      { Shutdown PARCIAL para reinício de nível / restart de jogo.
        Diferente de Shutdown():
          - Chama S.Shutdown em todos os sistemas (cancela subscrições,
            libera referências a entidades, reseta estado interno).
          - Limpa a fila de eventos do EventBus.
          - Invalida todos os caches de queries dos sistemas.
          - Reseta FShutdownCalled para False, permitindo que Init()
            seja chamado novamente sem bloqueio.
        Uso correto em DoRestart:
          1. ShutdownSystems   — reseta sistemas
          2. Destruir entidades
          3. LoadLevel         — recria entidades
          4. Init              — reinicializa sistemas com as novas entidades }
      procedure ShutdownSystems;

      // Call this ONCE after bulk creation
      procedure FlushStructureChanges;

      { Debug }
      {$IFDEF DEBUG}
      procedure PrintEntityPoolStats;
      {$ENDIF}

      property Entities: TEntityManager read FEntities;
      property Systems: TSystemList read FSystems;
      property EventBus: TEventBus read FEventBus;
   end;

function SystemCompare(const A, B: TSystem2D): Integer;

implementation

uses
   P2D.Utils.Logger;

function SystemCompare(const A, B: TSystem2D): Integer;
begin
   if A.Priority < B.Priority then
   begin
      Result := -1
   end
   else
   if A.Priority > B.Priority then
   begin
      Result := 1
   end
   else
   begin
      Result := 0
   end;
end;

constructor TWorld.Create;
begin
   inherited Create;

   FEntities := TEntityManager.Create;
   FSystems := TSystemList.Create(True);
   FEventBus := TEventBus.Create;
   FShutdownCalled := False;

   Logger.Info('[World] Created with entity pooling support');
end;

destructor TWorld.Destroy;
begin
   Shutdown;
   FSystems.Free;
   FEntities.Free;
   FEventBus.Free;

   inherited;
end;

function TWorld.GetEntities: TEntityManager;
begin
   Result := FEntities;
end;

function TWorld.GetEventBus: TEventBus;
begin
   Result := FEventBus;
end;

procedure TWorld.SortSystems;
begin
   FSystems.Sort(@SystemCompare);
end;

procedure TWorld.InvalidateAllSystemCaches;
var
   S: TSystem2D;
begin
   for S In FSystems do
   begin
      S.InvalidateCache
   end;
end;

procedure TWorld.MarkStructureDirty;
begin
   FStructureDirty := True;
end;

function TWorld.CreateEntity(const AName: String): TEntity;
begin
   Result := FEntities.CreateEntity(AName);
   MarkStructureDirty;
   //InvalidateAllSystemCaches;
end;

function TWorld.CreatePooledEntity(const ATag: String; const AName: String): TEntity;
begin
   Result := FEntities.CreatePooledEntity(ATag, AName);
   MarkStructureDirty;
   //InvalidateAllSystemCaches;

   {$IFDEF DEBUG}
   Logger.Debug(Format('[World] Pooled entity created: Tag="%s", Name="%s"', [ATag, AName]));
   {$ENDIF}
end;

procedure TWorld.DestroyEntity(AID: TEntityID);
begin
   FEntities.DestroyEntity(AID);
   MarkStructureDirty;
   //InvalidateAllSystemCaches;
end;

procedure TWorld.DestroyAllEntities;
var
   E: TEntity;
begin
   for E In Entities.GetAll do
   begin
      DestroyEntity(E.ID)
   end;

   Entities.PurgeDestroyed;
end;

function TWorld.GetEntity(AID: TEntityID): TEntity;
begin
   Result := FEntities.GetEntity(AID);
end;

procedure TWorld.ConfigureEntityPool(const ATag: String; AInitialSize, AMaxSize: Integer);
begin
   FEntities.ConfigurePool(ATag, AInitialSize, AMaxSize);
end;

procedure TWorld.PreallocateEntityPool(const ATag: String; ACount: Integer);
begin
   FEntities.PreallocatePool(ATag, ACount);
end;

procedure TWorld.ClearEntityPool(const ATag: String);
begin
   FEntities.ClearPool(ATag);
end;

function TWorld.AddSystem(ASystem: TSystem2D): TSystem2D;
var
   S: TSystem2D;
begin
   for S In FSystems do
   begin
      if S = ASystem then
      begin
         raise Exception.CreateFmt('TWorld.AddSystem: Sistema "%s" já registrado.', [ASystem.ClassName])
      end
   end;
   FSystems.Add(ASystem);
   SortSystems;
   Result := ASystem;
end;

function TWorld.GetSystem(AClass: TSystem2DClass): TSystem2D;
var
   S: TSystem2D;
begin
   Result := nil;
   for S In FSystems do
   begin
      if S.ClassType = AClass then
      begin
         Result := S;
         Exit;
      end
   end;
end;

procedure TWorld.Init;
var
   S: TSystem2D;
begin
   SortSystems;
   for S In FSystems do
   begin
      if S.Enabled then
      begin
         S.Init
      end
   end;
   //ComponentRegistry.Lock;
end;

procedure TWorld.FixedUpdate(AFixedDelta: Single);
var
   S: TSystem2D;
begin
   for S In FSystems do
   begin
      if S.Enabled then
      begin
         S.FixedUpdate(AFixedDelta)
      end
   end;
end;

function TWorld.GetEntitySignature(AEntity: TEntity): TComponentSignature;
begin
   if Not Assigned(AEntity) then
   begin
      Result := [];
      Exit;
   end;
   Result := AEntity.GetSignature;
end;

procedure TWorld.Update(ADelta: Single);
var
   S: TSystem2D;
begin
   FlushStructureChanges;
   for S In FSystems do
   begin
      if S.Enabled then
      begin
         S.Update(ADelta)
      end
   end;

   FEntities.PurgeDestroyed;
   FEventBus.Dispatch;
end;

procedure TWorld.Render;
var
   S: TSystem2D;
begin
   for S In FSystems do
   begin
      if S.Enabled then
      begin
         S.Render
      end
   end;
end;

procedure TWorld.RenderByLayer(ALayer: TRenderLayer);
var
   S: TSystem2D;
begin
   for S In FSystems do
   begin
      if S.Enabled And (S.RenderLayer = ALayer) then
      begin
         S.Render
      end
   end;
end;

{ Shutdown FINAL — usado apenas no encerramento do programa. }
procedure TWorld.Shutdown;
var
   S: TSystem2D;
begin
   if FShutdownCalled then
   begin
      Exit
   end;

   FShutdownCalled := True;
   FEventBus.Clear;

   for S In FSystems do
   begin
      if S.Enabled then
      begin
         S.Shutdown
      end
   end;
end;

{ ShutdownSystems — Shutdown parcial para reinício de nível/jogo.
  ─────────────────────────────────────────────────────────────────────────────
  Por que este método existe em vez de reusar Shutdown()?

  Shutdown() possui a guarda FShutdownCalled que garante execução única.
  Isso é correto para o encerramento final do programa, mas impede que o
  World seja reinicializado durante o jogo (DoRestart, troca de cena, etc.).

  ShutdownSystems() executa a mesma sequência de limpeza MAS:
    1. Não verifica nem seta FShutdownCalled antes de rodar.
    2. Reseta FShutdownCalled := False ao final, deixando o World pronto
       para receber um novo Init() sem que o Shutdown() final seja impedido.

  Fluxo de uso correto para reinício de nível:
    ShutdownSystems  →  destruir entidades  →  LoadLevel  →  Init
  ───────────────────────────────────────────────────────────────────────────── }
procedure TWorld.ShutdownSystems;
var
   S: TSystem2D;
begin
   { 1. Chama Shutdown em cada sistema na ordem inversa de prioridade.
        Cada sistema cancela suas subscrições no EventBus, libera quaisquer referências diretas a entidades (ex: FCamEntity, FTarget em
        TCameraSystem) e reseta flags de estado interno. }
   for S In FSystems do
   begin
      if S.Enabled then
      begin
         S.Shutdown
      end
   end;

   { 2. Descarta todos os eventos acumulados na fila de leitura e de escrita.
        Eventos publicados durante o Shutdown dos sistemas (ex: TAudioStopMusic publicado por TMarioAudioSystem.Shutdown) não devem ser processados
        com entidades que estão prestes a ser destruídas. }
   FEventBus.Clear;

   { 3. Invalida os caches de queries de todos os sistemas.
        As entidades atuais serão destruídas e novas serão criadas em seguida.
        Forçar FCacheDirty := True garante que cada sistema reconstrua sua lista de entidades correspondentes ao chamar GetMatchingEntities() dentro do próximo Init(). }
   InvalidateAllSystemCaches;

   { 4. Reseta a guarda de shutdown único.
        Sem este reset, o método Init() subsequente funcionaria, mas o Shutdown() final (chamado por TEngine2D.Run ao encerrar o programa)
        encontraria FShutdownCalled = True e sairia sem fazer nada — vazando subscrições de eventos e estado de sistemas. }
   FShutdownCalled := False;

   {$IFDEF DEBUG}
   Logger.Info('[World] ShutdownSystems concluído — pronto para re-Init.');
   {$ENDIF}
end;

procedure TWorld.FlushStructureChanges;
begin
   if FStructureDirty then
   begin
      InvalidateAllSystemCaches;
      FStructureDirty := False;
   end;
end;

{$IFDEF DEBUG}
procedure TWorld.PrintEntityPoolStats;
begin
   FEntities.PrintPoolStats;
end;
{$ENDIF}

end.
