unit P2D.Core.World;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, fgl, P2D.Core.Types, P2D.Core.Component, P2D.Core.Entity, P2D.Core.System;

type
   TSystemList = specialize TFPGObjectList<TSystem2D>;

  {---------------------------------------------------------------------------
   TWorld — implementação concreta de TWorldBase
   Estende TWorldBase (definida em P2D.Core.System) com a orquestração completa do ECS: lista de sistemas, loop de update/render e purga de entidades destruídas.
   A herança de TWorldBase é o que quebra a dependência circular: P2D.Core.System não precisa mais de P2D.Core.World na interface.
   ---------------------------------------------------------------------------}
   TWorld = class(TWorldBase)
   private
      FEntities      : TEntityManager;
      FSystems       : TSystemList;
      FShutdownCalled: Boolean;

      procedure SortSystems;
      procedure InvalidateAllSystemCaches;

   protected
      { Implementação dos métodos abstratos de TWorldBase. }
      function GetEntities: TEntityManager; override;
   public
      constructor Create;
      destructor  Destroy; override;

      { --- Entidades --------------------------------------------------------- }
      function  CreateEntity(const AName: string = ''): TEntity; override;
      procedure DestroyEntity(AID: TEntityID); override;
      function  GetEntity(AID: TEntityID): TEntity; override;

      { --- Sistemas ---------------------------------------------------------- }
      function  AddSystem(ASystem: TSystem2D): TSystem2D;
      function  GetSystem(AClass: TSystem2DClass): TSystem2D;

      { --- Loop principal ---------------------------------------------------- }
      procedure Init;
     {-------------------------------------------------------------------------
      Executa todos os sistemas habilitados em passo de tempo fixo.
      Chamado múltiplas vezes por frame pelo acumulador em TEngine2D.Run.
      NÃO chama PurgeDestroyed — isso é responsabilidade de Update, pois FixedUpdate pode rodar mais de uma vez antes do próximo render.
      -------------------------------------------------------------------------}
      procedure FixedUpdate(AFixedDelta: Single); override;
      procedure Update(ADelta: Single);
    { Renderiza TODOS os sistemas habilitados (sem distinção de camada).
      Usado por TEngine2D.Run quando não há separação de câmera. }
      procedure Render;
    { Renderiza apenas os sistemas com RenderLayer = ALayer.
      Chamado pelo loop do demo para separar world-space de screen-space:
         RenderByLayer(rlWorld)  → dentro de BeginMode2D/EndMode2D
         RenderByLayer(rlScreen) → fora de BeginMode2D/EndMode2D }
      procedure RenderByLayer(ALayer: TRenderLayer); override;
      procedure Shutdown;

      property Entities: TEntityManager read FEntities;
      property Systems : TSystemList    read FSystems;
   end;

function SystemCompare(const A, B: TSystem2D): Integer;

implementation

function SystemCompare(const A, B: TSystem2D): Integer;
begin
   if A.Priority < B.Priority then
      Result := -1
   else
      if A.Priority > B.Priority then
         Result := 1
      else
         Result := 0;
end;

constructor TWorld.Create;
begin
  inherited Create;

  FEntities       := TEntityManager.Create;
  FSystems        := TSystemList.Create(True);
  FShutdownCalled := False;
end;

destructor TWorld.Destroy;
begin
  Shutdown;
  FSystems.Free;
  FEntities.Free;

  inherited;
end;

function TWorld.GetEntities: TEntityManager;
begin
  Result := FEntities;
end;

procedure TWorld.SortSystems;
begin
  FSystems.Sort(@SystemCompare);
end;

procedure TWorld.InvalidateAllSystemCaches;
var
  S: TSystem2D;
begin
  for S in FSystems do
    S.InvalidateCache;
end;

function TWorld.CreateEntity(const AName: string): TEntity;
begin
  Result := FEntities.CreateEntity(AName);
  InvalidateAllSystemCaches;
end;

procedure TWorld.DestroyEntity(AID: TEntityID);
begin
  FEntities.DestroyEntity(AID);
  InvalidateAllSystemCaches;
end;

function TWorld.GetEntity(AID: TEntityID): TEntity;
begin
  Result := FEntities.GetEntity(AID);
end;

function TWorld.AddSystem(ASystem: TSystem2D): TSystem2D;
var
  S: TSystem2D;
begin
  for S in FSystems do
    if S = ASystem then
      raise Exception.CreateFmt(
        'TWorld.AddSystem: Sistema "%s" já registrado.', [ASystem.ClassName]);
  FSystems.Add(ASystem);
  SortSystems;
  Result := ASystem;
end;

function TWorld.GetSystem(AClass: TSystem2DClass): TSystem2D;
var
  S: TSystem2D;
begin
  Result := nil;
  for S in FSystems do
    if S.ClassType = AClass then
    begin
      Result := S;
      Exit;
    end;
end;

procedure TWorld.Init;
var
  S: TSystem2D;
begin
  SortSystems;
  for S in FSystems do
    if S.Enabled then S.Init;
end;

procedure TWorld.FixedUpdate(AFixedDelta: Single);
var
  S: TSystem2D;
begin
  { Itera por prioridade (já ordenado por SortSystems/Init).
    Apenas sistemas com FixedUpdate sobrescrito são afetados — os demais executam a implementação vazia herdada de TSystem2D. }
  for S in FSystems do
    if S.Enabled then S.FixedUpdate(AFixedDelta);

  { IMPORTANTE: PurgeDestroyed NÃO é chamado aqui. FixedUpdate pode ser executado várias vezes por frame. Remover entidades durante o passo fixo enquanto o
    acumulador ainda tem passos restantes causaria acesso a entidades já liberadas. A purga acontece em Update, uma única vez por frame, após todos os passos fixos. }
end;

procedure TWorld.Update(ADelta: Single);
var
   S: TSystem2D;
begin
   for S in FSystems do
      if S.Enabled then
         S.Update(ADelta);

 { Purga entidades marcadas como destruídas (Alive = False).
   Executado uma vez por frame, após todos os passos fixos e após Update. }
   FEntities.PurgeDestroyed;
end;

procedure TWorld.Render;
var
  S: TSystem2D;
begin
  {Renderiza todos os sistemas sem distinção de camada.
   Mantido para compatibilidade com TEngine2D.Run. }
   for S in FSystems do
      if S.Enabled then
         S.Render;
end;

procedure TWorld.RenderByLayer(ALayer: TRenderLayer);
var
   S: TSystem2D;
begin
 { Itera todos os sistemas em ordem de prioridade (já ordenados) e chama Render apenas nos que pertencem à camada solicitada. }
   for S in FSystems do
      if S.Enabled and (S.RenderLayer = ALayer) then
         S.Render;
end;

procedure TWorld.Shutdown;
var
   S: TSystem2D;
begin
   if FShutdownCalled then
      Exit;
   FShutdownCalled := True;
   for S in FSystems do
      if S.Enabled then
         S.Shutdown;
end;

end.
