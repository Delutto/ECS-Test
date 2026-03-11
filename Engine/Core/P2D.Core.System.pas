unit P2D.Core.System;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, fgl,
   P2D.Core.Event,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.Component,
   P2D.Core.ComponentRegistry;

type
   {---------------------------------------------------------------------------
   TRenderLayer
   ---------------------------------------------------------------------------
   Define em qual espaço de coordenadas o sistema renderiza.

   rlWorld  — coordenadas do mundo, afetadas pela câmera (BeginMode2D).
              Usado por: TTileMapSystem, TRenderSystem.

   rlScreen — coordenadas de tela fixas, independentes da câmera.
              Usado por: THUDSystem e qualquer overlay 2D.

   O loop do demo chama RenderByLayer(rlWorld) dentro de BeginMode2D e
   RenderByLayer(rlScreen) fora dele, garantindo que cada sistema
   desenhe no espaço correto.
   ---------------------------------------------------------------------------}
   TRenderLayer = (rlWorld, rlScreen);

   {---------------------------------------------------------------------------
   Component Signature - Otimização de Queries
   ---------------------------------------------------------------------------
   Cada tipo de componente recebe um ID único (0-63).
   A assinatura de uma entidade é um conjunto de bits indicando quais
   componentes ela possui. Comparação O(1) ao invés de O(n).
   ---------------------------------------------------------------------------}
   TComponentSignature = set of 0..63;

   {---------------------------------------------------------------------------
   Cache Statistics
   ---------------------------------------------------------------------------}
   TCacheStats = record
      HitCount: Int64;
      MissCount: Int64;
      RefreshCount: Int64;
      LastRefreshTime: Double;
      AverageRefreshTime: Double;
      EntityCount: Integer;
   end;

   {---------------------------------------------------------------------------
   TWorldBase — interface mínima que TSystem2D precisa do World.
   TWorld (em P2D.Core.World) herda desta classe e implementa tudo.
   ---------------------------------------------------------------------------}
   TWorldBase = class
   protected
      { Getter abstrato exposto via propriedade Entities. }
      function GetEntities: TEntityManager; virtual; abstract;
      function GetEventBus: TEventBus; virtual; abstract;
   public
      { Cria uma nova entidade no mundo. }
      function  CreateEntity(const AName: string = ''): TEntity; virtual; abstract;

      { Marca a entidade para destruição ao final do frame. }
      procedure DestroyEntity(AID: TEntityID); virtual; abstract;

      { Busca uma entidade pelo ID. Retorna nil se não encontrada. }
      function  GetEntity(AID: TEntityID): TEntity; virtual; abstract;

      { Renderiza apenas os sistemas cuja RenderLayer = ALayer. }
      procedure RenderByLayer(ALayer: TRenderLayer); virtual; abstract;

      { Executa sistemas de passo fixo (física, colisão). }
      procedure FixedUpdate(AFixedDelta: Single); virtual; abstract;

      { Obtém a assinatura de componentes de uma entidade }
      function GetEntitySignature(AEntity: TEntity): TComponentSignature; virtual; abstract;

      { Acesso ao gerenciador de entidades (GetAll, PurgeDestroyed, etc.). }
      property Entities: TEntityManager read GetEntities;
      property EventBus: TEventBus read GetEventBus;
  end;

  {---------------------------------------------------------------------------
   TComponentClassList
   Lista não-proprietária de metaclasses de componentes.
   Define a "assinatura" (quais componentes) de um sistema.
   ---------------------------------------------------------------------------}
   TComponentClassList = specialize TFPGList<TComponent2DClass>;

  {---------------------------------------------------------------------------
   TEntityRefList
   Lista não-proprietária de referências a TEntity.
   Resultado de query — entidades pertencem ao TEntityManager.
   ---------------------------------------------------------------------------}
   TEntityRefList = specialize TFPGList<TEntity>;

  {---------------------------------------------------------------------------
   TSystem2D — classe base para todos os sistemas ECS
   ---------------------------------------------------------------------------}

   { TSystem2D }

   TSystem2D = class
   private
      FWorld          : TWorldBase;
      FPriority       : TSystemPriority;
      FEnabled        : Boolean;
      FName           : String;
      FRenderLayer    : TRenderLayer;
      FRequiredClasses: TComponentClassList;
      FMatchCache     : TEntityRefList;
      FCacheDirty     : Boolean;

      { Otimizações de Query }
      FRequiredSignature: TComponentSignature;
      FSignatureDirty   : Boolean;
      FCacheStats       : TCacheStats;
      FLastCacheSize    : Integer;
   protected
      { Registra um tipo de componente como obrigatório para este sistema. Chamado na implementação de Init pelas subclasses. Idempotente: duplicatas são ignoradas silenciosamente. }
      procedure RequireComponent(AClass: TComponent2DClass);
      { Reconstrói FMatchCache com as entidades que satisfazem FRequiredClasses. Chamado automaticamente por GetMatchingEntities quando FCacheDirty=True. }
      procedure RefreshCache;
      procedure UpdateRequiredSignature;
      procedure RecordCacheHit; inline;
      procedure RecordCacheMiss; inline;
   public
      constructor Create(AWorld: TWorldBase); virtual;
      destructor  Destroy; override;

      procedure Init; virtual;
      procedure Update(ADelta: Single); virtual; abstract;
      procedure FixedUpdate(AFixedDelta: Single); virtual;
      procedure Render; virtual;
      procedure Shutdown; virtual;

      { Retorna entidades vivas que possuem TODOS os componentes requeridos. Cache O(1) na maioria dos frames; O(n·m) após invalidação estrutural. }
      function GetMatchingEntities: TEntityRefList;
      { Verifica pontualmente se AEntity satisfaz os requisitos do sistema. }
      function EntityMatches(AEntity: TEntity): Boolean;
      function EntityMatchesFast(AEntity: TEntity): Boolean;
      { Invalida o cache. Chamado pelo TWorld após mudanças estruturais(CreateEntity, DestroyEntity, AddComponent, RemoveComponent). }
      procedure InvalidateCache;

      { Debug & Stats }
      function GetCacheStats: TCacheStats;
      procedure ResetCacheStats;
      procedure PrintCacheStats;

      property World: TWorldBase read FWorld;
      property Priority: TSystemPriority read FPriority write FPriority;
      property Enabled: Boolean read FEnabled write FEnabled;
      property Name: string read FName write FName;
      { Camada de render deste sistema.
      Padrão: rlWorld — a grande maioria dos sistemas opera no espaço do mundo.
      Sistemas de UI/overlay devem sobrescrever para rlScreen. }
      property RenderLayer: TRenderLayer read FRenderLayer write FRenderLayer;
   end;

   TSystem2DClass = class of TSystem2D;

implementation

uses
   P2D.Utils.Logger, DateUtils;

constructor TSystem2D.Create(AWorld: TWorldBase);
begin
   inherited Create;

   FWorld           := AWorld;
   FPriority        := 0;
   FEnabled         := True;
   FName            := '';
   FRenderLayer     := rlWorld;
   FRequiredClasses := TComponentClassList.Create;
   FMatchCache      := TEntityRefList.Create;
   FCacheDirty      := True;
   FSignatureDirty  := True;
   FRequiredSignature := [];
   FLastCacheSize   := 0;

   // Inicializa estatísticas
   FillChar(FCacheStats, SizeOf(FCacheStats), 0);
end;

destructor TSystem2D.Destroy;
begin
   {$IFDEF DEBUG}
   PrintCacheStats;
   {$ENDIF}

   FMatchCache.Free;      { não-proprietário: libera apenas a lista }
   FRequiredClasses.Free; { não-proprietário: metaclasses pertencem ao compilador }

   inherited;
end;

// -----------------------------------------------------------------------------
procedure TSystem2D.RequireComponent(AClass: TComponent2DClass);
begin
   if AClass = nil then
      raise EArgumentNilException.Create('TSystem2D.RequireComponent: AClass não pode ser nil.');
   if FRequiredClasses.IndexOf(AClass) >= 0 then
      Exit; { idempotente }
   FRequiredClasses.Add(AClass);
   FSignatureDirty := True;
   InvalidateCache;

   {$IFDEF DEBUG}
   Logger.Debug(Format('[System %s] Component required: %s (Total: %d)', [Self.ClassName, AClass.ClassName, FRequiredClasses.Count]));
   {$ENDIF}
end;

// -----------------------------------------------------------------------------
procedure TSystem2D.InvalidateCache;
begin
   FCacheDirty := True;

   {$IFDEF DEBUG}
   Logger.Debug(Format('[System %s] Cache invalidated', [Self.ClassName]));
   {$ENDIF}
end;

function TSystem2D.GetCacheStats: TCacheStats;
begin
   Result := FCacheStats;
end;

procedure TSystem2D.ResetCacheStats;
begin
   FillChar(FCacheStats, SizeOf(FCacheStats), 0);
   FCacheStats.EntityCount := FMatchCache.Count;

   {$IFDEF DEBUG}
   Logger.Info(Format('[System %s] Cache stats reset', [Self.ClassName]));
   {$ENDIF}
end;

procedure TSystem2D.PrintCacheStats;
var
   HitRate: Double;
   TotalAccess: Int64;
begin
   TotalAccess := FCacheStats.HitCount + FCacheStats.MissCount;

   if TotalAccess > 0 then
      HitRate := (FCacheStats.HitCount / TotalAccess) * 100.0
   else
      HitRate := 0.0;

   Logger.Info(Format('=== Cache Stats: %s ===', [Self.ClassName]));
   Logger.Info(Format('  Cached Entities: %d', [FCacheStats.EntityCount]));
   Logger.Info(Format('  Cache Hits: %d', [FCacheStats.HitCount]));
   Logger.Info(Format('  Cache Misses: %d', [FCacheStats.MissCount]));
   Logger.Info(Format('  Hit Rate: %.2f%%', [HitRate]));
   Logger.Info(Format('  Refresh Count: %d', [FCacheStats.RefreshCount]));
   Logger.Info(Format('  Last Refresh: %.2fms', [FCacheStats.LastRefreshTime]));
   Logger.Info(Format('  Avg Refresh: %.2fms', [FCacheStats.AverageRefreshTime]));
   Logger.Info(Format('  Required Components: %d', [FRequiredClasses.Count]));
   Logger.Info('===========================');
end;

// -----------------------------------------------------------------------------
function TSystem2D.EntityMatches(AEntity: TEntity): Boolean;
var
  RequiredClass: TComponent2DClass;
begin
  if not Assigned(AEntity) or not AEntity.Alive then
  begin
    Result := False;
    Exit;
  end;

  { Sistema sem requisitos recebe TODAS as entidades vivas (ex.: câmera, HUD). }
  if FRequiredClasses.Count = 0 then
  begin
    Result := True;
    Exit;
  end;

  Result := True;
  for RequiredClass in FRequiredClasses do
    if not AEntity.HasComponent(RequiredClass) then
    begin
      Result := False;
      Exit; { curto-circuito }
    end;
end;

function TSystem2D.EntityMatchesFast(AEntity: TEntity): Boolean;
var
   EntitySig: TComponentSignature;
begin
   if not Assigned(AEntity) or not AEntity.Alive then
   begin
      Result := False;
      Exit;
   end;

   { Sistema sem requisitos recebe TODAS as entidades vivas }
   if FRequiredClasses.Count = 0 then
   begin
      Result := True;
      Exit;
   end;

   { Atualizar signature se necessário }
   UpdateRequiredSignature;

   { Obter signature da entidade }
   EntitySig := AEntity.GetSignature;

   { Verificar se entidade tem TODOS os componentes requeridos }
   Result := TComponentRegistry.SignatureMatches(EntitySig, FRequiredSignature);
end;

// -----------------------------------------------------------------------------
procedure TSystem2D.RefreshCache;
var
   E: TEntity;
   StartTime: TDateTime;
   ElapsedMs: Double;
   OldCount, NewCount: Integer;
begin
   {$IFDEF DEBUG}
   StartTime := Now;
   {$ENDIF}

   OldCount := FMatchCache.Count;

   FMatchCache.Clear;

   // Atualiza assinatura se necessário
   UpdateRequiredSignature;

   // Popula cache
   for E in FWorld.Entities.GetAll do
   begin
      if EntityMatchesFast(E) then
         FMatchCache.Add(E);
   end;

   NewCount := FMatchCache.Count;
   FCacheDirty := False;

   // Atualiza estatísticas
   {$IFDEF DEBUG}
   Inc(FCacheStats.RefreshCount);
   ElapsedMs := MilliSecondsBetween(Now, StartTime);
   FCacheStats.LastRefreshTime := ElapsedMs;
   FCacheStats.EntityCount := NewCount;

   // Calcula média móvel do tempo de refresh
   if FCacheStats.RefreshCount = 1 then
      FCacheStats.AverageRefreshTime := ElapsedMs
   else
      FCacheStats.AverageRefreshTime :=
         (FCacheStats.AverageRefreshTime * 0.9) + (ElapsedMs * 0.1);

   if OldCount <> NewCount then
      Logger.Debug(Format('[System %s] Cache refreshed: %d -> %d entities (%.2fms)', [Self.ClassName, OldCount, NewCount, ElapsedMs]));
   {$ENDIF}
end;

procedure TSystem2D.UpdateRequiredSignature;
var
   ComponentClass: TComponent2DClass;
   ComponentID: Integer;
begin
   if not FSignatureDirty then
      Exit;

   // ═══════════════════════════════════════════════════════════════
   // Criar signature a partir das classes requeridas
   // ═══════════════════════════════════════════════════════════════
   FRequiredSignature := [];

   for ComponentClass in FRequiredClasses do
   begin
      ComponentID := ComponentRegistry.GetComponentID(ComponentClass);
      if ComponentID >= 0 then
         Include(FRequiredSignature, ComponentID)
      else
      begin
         ComponentID := ComponentRegistry.Register(ComponentClass);
         Include(FRequiredSignature, ComponentID);
      end;
   end;

   FSignatureDirty := False;

   {$IFDEF DEBUG}
   Logger.Debug(Format('[System %s] Required signature updated (%d components)',
      [Self.ClassName, FRequiredClasses.Count]));
   {$ENDIF}
end;

procedure TSystem2D.RecordCacheHit;
begin
   Inc(FCacheStats.HitCount);
end;

procedure TSystem2D.RecordCacheMiss;
begin
   Inc(FCacheStats.MissCount);
end;

// -----------------------------------------------------------------------------
function TSystem2D.GetMatchingEntities: TEntityRefList;
begin
   if FCacheDirty then
   begin
      RecordCacheMiss;
      RefreshCache;
   end
   else
      RecordCacheHit;

   Result := FMatchCache;
end;

procedure TSystem2D.Init;
begin
   { Subclasses chamam RequireComponent() aqui. }
end;

procedure TSystem2D.FixedUpdate(AFixedDelta: Single);
begin
   { Implementação padrão vazia. Sistemas de física e colisão sobrescrevem este método. }
end;

procedure TSystem2D.Render;
begin

end;

procedure TSystem2D.Shutdown;
begin

end;

end.
