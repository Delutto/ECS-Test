unit P2D.Core.System;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fgl,
  P2D.Core.Types,
  P2D.Core.Component,
  P2D.Core.Entity;

type
  TWorldBase = class
  protected
    { Getter abstrato exposto via propriedade Entities. }
    function GetEntities: TEntityManager; virtual; abstract;
  public
    { Cria uma nova entidade no mundo. }
    function  CreateEntity(const AName: string = ''): TEntity; virtual; abstract;

    { Marca a entidade para destruição ao final do frame. }
    procedure DestroyEntity(AID: TEntityID); virtual; abstract;

    { Busca uma entidade pelo ID. Retorna nil se não encontrada. }
    function  GetEntity(AID: TEntityID): TEntity; virtual; abstract;

    { Executa sistemas de passo fixo (física, colisão). }
    procedure FixedUpdate(AFixedDelta: Single); virtual; abstract;

    { Acesso ao gerenciador de entidades (GetAll, PurgeDestroyed, etc.). }
    property Entities: TEntityManager read GetEntities;
  end;

  // ---------------------------------------------------------------------------
  // TComponentClassList
  // Lista não-proprietária de metaclasses de componentes.
  // Define a "assinatura" (quais componentes) de um sistema.
  // ---------------------------------------------------------------------------
  TComponentClassList = specialize TFPGList<TComponent2DClass>;

  // ---------------------------------------------------------------------------
  // TEntityRefList
  // Lista não-proprietária de referências a TEntity.
  // Resultado de query — entidades pertencem ao TEntityManager.
  // ---------------------------------------------------------------------------
  TEntityRefList = specialize TFPGList<TEntity>;

  // ---------------------------------------------------------------------------
  // TSystem2D — classe base para todos os sistemas ECS
  // ---------------------------------------------------------------------------
  TSystem2D = class
  private
    FWorld          : TWorldBase;
    FPriority       : TSystemPriority;
    FEnabled        : Boolean;
    FName           : string;
    FRequiredClasses: TComponentClassList;
    FMatchCache     : TEntityRefList;
    FCacheDirty     : Boolean;

  protected
    { Registra um tipo de componente como obrigatório para este sistema. Chamado na implementação de Init pelas subclasses. Idempotente: duplicatas são ignoradas silenciosamente. }
    procedure RequireComponent(AClass: TComponent2DClass);

    { Reconstrói FMatchCache com as entidades que satisfazem FRequiredClasses. Chamado automaticamente por GetMatchingEntities quando FCacheDirty=True. }
    procedure RefreshCache;

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

    { Invalida o cache. Chamado pelo TWorld após mudanças estruturais(CreateEntity, DestroyEntity, AddComponent, RemoveComponent). }
    procedure InvalidateCache;

    property World    : TWorldBase      read FWorld;
    property Priority : TSystemPriority read FPriority write FPriority;
    property Enabled  : Boolean         read FEnabled  write FEnabled;
    property Name     : string          read FName     write FName;
  end;

  TSystem2DClass = class of TSystem2D;

implementation

constructor TSystem2D.Create(AWorld: TWorldBase);
begin
   inherited Create;

   FWorld           := AWorld;
   FPriority        := 0;
   FEnabled         := True;
   FName            := '';
   FRequiredClasses := TComponentClassList.Create;
   FMatchCache      := TEntityRefList.Create;
   FCacheDirty      := True;
end;

destructor TSystem2D.Destroy;
begin
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
   InvalidateCache;
end;

// -----------------------------------------------------------------------------
procedure TSystem2D.InvalidateCache;
begin
  FCacheDirty := True;
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

// -----------------------------------------------------------------------------
procedure TSystem2D.RefreshCache;
var
  AllEntities: TEntityList;
  E: TEntity;
begin
   FMatchCache.Clear;
   AllEntities := FWorld.Entities.GetAll; { via TWorldBase.Entities }
   for E in AllEntities do
      if EntityMatches(E) then
         FMatchCache.Add(E);
   FCacheDirty := False;
end;

// -----------------------------------------------------------------------------
function TSystem2D.GetMatchingEntities: TEntityRefList;
begin
   if FCacheDirty then
      RefreshCache;
   Result := FMatchCache;
end;

// -----------------------------------------------------------------------------
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
