unit P2D.Core.System;
{ ===========================================================================
  Pascal2D Engine — P2D.Core.System
  ---------------------------------------------------------------------------
  Classe base para todos os sistemas ECS.

  DESIGN 2 — Mecanismo de filtragem de entidades por componente
  -------------------------------------------------------------
  Cada sistema declara quais tipos de componentes são necessários chamando
  RequireComponent() dentro da sua implementação de Init.  A partir daí,
  GetMatchingEntities() devolve apenas as entidades que possuem TODOS esses
  componentes, eliminando a necessidade de iteração e verificação manual
  espalhada por cada sistema concreto.

  Estratégia de cache com invalidação explícita
  ---------------------------------------------
  O resultado da filtragem é armazenado em FMatchCache (TEntityRefList),
  uma lista não-proprietária de referências a TEntity.  O cache é marcado
  como "sujo" (FCacheDirty = True) nas seguintes situações:
    • Chamada a RequireComponent() (assinatura do sistema mudou);
    • Chamada a InvalidateCache() pelo TWorld (entidade criada, destruída
      ou componente adicionado/removido).
  Apenas quando o cache está sujo é que RefreshCache() é executado, o que
  torna o custo de GetMatchingEntities() O(1) na grande maioria dos frames.

  Contrato com TWorld
  -------------------
  TWorld.CreateEntity e TWorld.DestroyEntity devem chamar
  InvalidateCacheForAllSystems após qualquer mudança estrutural.
  Ver P2D.Core.World para a implementação correspondente.
  =========================================================================== }

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fgl,
  P2D.Core.Types,
  P2D.Core.Component,
  P2D.Core.Entity;

type
  { Forward — implementação vive em P2D.Core.World para evitar dependência
    circular na interface. A unit P2D.Core.World é incluída na seção
    implementation desta unit. }
  TWorld = class;

  // ---------------------------------------------------------------------------
  // TComponentClassList
  // Lista de metaclasses de componentes que define a "assinatura" de um sistema.
  // Usa TFPGList (não-proprietário) pois as metaclasses pertencem ao compilador.
  // ---------------------------------------------------------------------------
  TComponentClassList = specialize TFPGList<TComponent2DClass>;

  // ---------------------------------------------------------------------------
  // TEntityRefList
  // Lista não-proprietária de referências a TEntity.
  // Usada como resultado de query — a vida útil das entidades é gerenciada
  // exclusivamente pelo TEntityManager; esta lista apenas referencia.
  // ---------------------------------------------------------------------------
  TEntityRefList = specialize TFPGList<TEntity>;

  // ---------------------------------------------------------------------------
  // TSystem2D — classe base para todos os sistemas ECS
  // ---------------------------------------------------------------------------
  TSystem2D = class
  private
    FWorld          : TWorld;
    FPriority       : TSystemPriority;
    FEnabled        : Boolean;
    FName           : string;

    { Lista de metaclasses de componentes requeridos por este sistema.
      Populada por chamadas a RequireComponent() em Init. }
    FRequiredClasses: TComponentClassList;

    { Cache do último resultado de filtragem.
      Não-proprietário: contém referências às entidades gerenciadas pelo World. }
    FMatchCache     : TEntityRefList;

    { Quando True, RefreshCache() é executado na próxima chamada a
      GetMatchingEntities(). }
    FCacheDirty     : Boolean;

  protected
    { ---------------------------------------------------------------------------
      RequireComponent(AClass)
      Registra AClass como componente obrigatório para este sistema.
      Deve ser chamado na implementação de Init pelas subclasses.

      Comportamento:
        • Ignora duplicatas (idempotente).
        • Invalida o cache automaticamente ao adicionar um novo requisito.
      --------------------------------------------------------------------------- }
    procedure RequireComponent(AClass: TComponent2DClass);

    { ---------------------------------------------------------------------------
      RefreshCache
      Reconstrói FMatchCache iterando todas as entidades do World e mantendo
      apenas aquelas cujo conjunto de componentes satisfaz FRequiredClasses.
      Chamado automaticamente por GetMatchingEntities quando FCacheDirty = True.
      --------------------------------------------------------------------------- }
    procedure RefreshCache;

  public
    constructor Create(AWorld: TWorld); virtual;
    destructor  Destroy; override;

    { Ciclo de vida — sobrescrever nas subclasses conforme necessário. }
    procedure Init;               virtual;
    procedure Update(ADelta: Single); virtual; abstract;
    procedure Render;             virtual;
    procedure Shutdown;           virtual;

    { ---------------------------------------------------------------------------
      GetMatchingEntities: TEntityRefList
      Ponto central do mecanismo de filtragem.

      Retorna a lista (cacheada) de entidades que:
        (a) Estão vivas (Entity.Alive = True);
        (b) Possuem TODOS os componentes declarados via RequireComponent.

      Custo:
        • O(1)  — quando o cache está válido (caso comum, frames normais).
        • O(n·m)— quando o cache está sujo (n = entidades, m = requisitos),
                  o que ocorre apenas após mudanças estruturais no World.

      ATENÇÃO: não armazene a referência retornada além do frame corrente.
      O ponteiro interno pode ser invalidado após a próxima chamada a
      InvalidateCache + RefreshCache.
      --------------------------------------------------------------------------- }
    function GetMatchingEntities: TEntityRefList;

    { ---------------------------------------------------------------------------
      EntityMatches(AEntity): Boolean
      Verifica pontualmente se AEntity satisfaz todos os requisitos do sistema.
      Útil para validações ad-hoc sem consultar o cache completo.
      --------------------------------------------------------------------------- }
    function EntityMatches(AEntity: TEntity): Boolean;

    { ---------------------------------------------------------------------------
      InvalidateCache
      Marca o cache como desatualizado. Na próxima chamada a
      GetMatchingEntities, RefreshCache() será executado.

      Chamado pelo TWorld sempre que a composição de entidades mudar:
        • CreateEntity   → nova entidade disponível;
        • DestroyEntity  → entidade pode estar no cache;
        • AddComponent   → entidade pode agora satisfazer mais sistemas;
        • RemoveComponent→ entidade pode deixar de satisfazer este sistema.
      --------------------------------------------------------------------------- }
    procedure InvalidateCache;

    property World    : TWorld          read FWorld;
    property Priority : TSystemPriority read FPriority write FPriority;
    property Enabled  : Boolean         read FEnabled  write FEnabled;
    property Name     : string          read FName     write FName;
  end;

  TSystem2DClass = class of TSystem2D;

implementation

{ P2D.Core.World é incluído aqui para resolver a dependência circular:
    P2D.Core.System (interface) declara TWorld como forward.
    P2D.Core.World  (interface) usa TSystem2D via P2D.Core.System.
  A inclusão na seção implementation quebra o ciclo sem expor a dependência
  na interface pública desta unit. }
uses
  P2D.Core.World;

// =============================================================================
// TSystem2D
// =============================================================================

constructor TSystem2D.Create(AWorld: TWorld);
begin
  inherited Create;
  FWorld           := AWorld;
  FPriority        := 0;
  FEnabled         := True;
  FName            := '';
  FRequiredClasses := TComponentClassList.Create;
  FMatchCache      := TEntityRefList.Create;
  FCacheDirty      := True; { força RefreshCache na primeira chamada }
end;

destructor TSystem2D.Destroy;
begin
  { FMatchCache não é proprietário das entidades — apenas libera a lista. }
  FMatchCache.Free;
  { FRequiredClasses não é proprietário das metaclasses — apenas libera a lista. }
  FRequiredClasses.Free;
  inherited;
end;

// -----------------------------------------------------------------------------
// RequireComponent
// -----------------------------------------------------------------------------
procedure TSystem2D.RequireComponent(AClass: TComponent2DClass);
begin
  if AClass = nil then
    raise EArgumentNilException.Create(
      'TSystem2D.RequireComponent: AClass não pode ser nil.');

  { Idempotente: ignora se já estiver registrado. }
  if FRequiredClasses.IndexOf(AClass) >= 0 then
    Exit;

  FRequiredClasses.Add(AClass);

  { A assinatura mudou: o cache anterior não é mais válido. }
  InvalidateCache;
end;

// -----------------------------------------------------------------------------
// InvalidateCache
// -----------------------------------------------------------------------------
procedure TSystem2D.InvalidateCache;
begin
  FCacheDirty := True;
end;

// -----------------------------------------------------------------------------
// EntityMatches
// -----------------------------------------------------------------------------
function TSystem2D.EntityMatches(AEntity: TEntity): Boolean;
var
  RequiredClass: TComponent2DClass;
begin
  { Entidades mortas nunca participam de nenhum sistema. }
  if not Assigned(AEntity) or not AEntity.Alive then
  begin
    Result := False;
    Exit;
  end;

  { Se o sistema não declarou nenhum requisito, ele recebe TODAS as entidades
    vivas — comportamento útil para sistemas globais (ex.: câmera, debug). }
  if FRequiredClasses.Count = 0 then
  begin
    Result := True;
    Exit;
  end;

  { Verifica cada componente requerido: basta um ausente para excluir a entidade. }
  Result := True;
  for RequiredClass in FRequiredClasses do
  begin
    if not AEntity.HasComponent(RequiredClass) then
    begin
      Result := False;
      Exit; { curto-circuito: falhou no primeiro componente ausente }
    end;
  end;
end;

// -----------------------------------------------------------------------------
// RefreshCache
// -----------------------------------------------------------------------------
procedure TSystem2D.RefreshCache;
var
  AllEntities: TEntityList;
  E          : TEntity;
begin
  FMatchCache.Clear;

  { Acessa a lista completa de entidades via World — requer P2D.Core.World
    na seção implementation. }
  AllEntities := FWorld.Entities.GetAll;

  for E in AllEntities do
    if EntityMatches(E) then
      FMatchCache.Add(E);

  FCacheDirty := False;
end;

// -----------------------------------------------------------------------------
// GetMatchingEntities
// -----------------------------------------------------------------------------
function TSystem2D.GetMatchingEntities: TEntityRefList;
begin
  { Reconstrução preguiçosa (lazy rebuild): só paga o custo O(n·m)
    quando o cache foi explicitamente invalidado. }
  if FCacheDirty then
    RefreshCache;

  Result := FMatchCache;
end;

// -----------------------------------------------------------------------------
// Ciclo de vida — implementações padrão (vazias, sobrescrevíveis)
// -----------------------------------------------------------------------------
procedure TSystem2D.Init;
begin
  { Subclasses chamam RequireComponent() aqui antes de qualquer lógica. }
end;

procedure TSystem2D.Render;
begin
  { Implementação padrão vazia. }
end;

procedure TSystem2D.Shutdown;
begin
  { Implementação padrão vazia. }
end;

end.

