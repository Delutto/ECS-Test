unit P2D.Core.World;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, fgl,
  P2D.Core.Types, P2D.Core.Component, P2D.Core.Entity, P2D.Core.System;

type
  TSystemList = specialize TFPGObjectList<TSystem2D>;

  // -------------------------------------------------------------------------
  // The ECS World – heart of the engine
  // -------------------------------------------------------------------------
  TWorld = class
  private
    FEntities: TEntityManager;
    FSystems : TSystemList;
    FShutdownCalled: Boolean; // flag de controle
    procedure SortSystems;
  public
    constructor Create;
    destructor  Destroy; override;

    // Entity helpers
    function  CreateEntity(const AName: string = ''): TEntity;
    procedure DestroyEntity(AID: TEntityID);
    function  GetEntity(AID: TEntityID): TEntity;

    // System helpers
    function  AddSystem(ASystem: TSystem2D): TSystem2D;
    function  GetSystem(AClass: TSystem2DClass): TSystem2D;

    // Main loop
    procedure Init;
    procedure Update(ADelta: Single);
    procedure Render;
    procedure Shutdown;

    // Accessors
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

// ---------------------------------------------------------------------------
constructor TWorld.Create;
begin
  inherited Create;
  FEntities := TEntityManager.Create;
  FSystems  := TSystemList.Create(True);
end;

destructor TWorld.Destroy;
begin
  Shutdown;
  FSystems.Free;
  FEntities.Free;
  inherited;
end;

procedure TWorld.SortSystems;
begin
  FSystems.Sort(@SystemCompare);
end;

function TWorld.CreateEntity(const AName: string): TEntity;
begin
  Result := FEntities.CreateEntity(AName);
end;

procedure TWorld.DestroyEntity(AID: TEntityID);
begin
  FEntities.DestroyEntity(AID);
end;

function TWorld.GetEntity(AID: TEntityID): TEntity;
begin
  Result := FEntities.GetEntity(AID);
end;

function TWorld.AddSystem(ASystem: TSystem2D): TSystem2D;
var
  S: TSystem2D;
begin
  // Verifica duplicata por instância
  for S in FSystems do
    if S = ASystem then
      raise Exception.CreateFmt('TWorld.AddSystem: Sistema "%s" já registrado.', [ASystem.ClassName]);
  FSystems.Add(ASystem);
  SortSystems;
  Result := ASystem;

function TWorld.GetSystem(AClass: TSystem2DClass): TSystem2D;
var S: TSystem2D;
begin
  Result := nil;
  for S in FSystems do
    if S.ClassType = AClass then begin Result := S; Exit; end;
end;

procedure TWorld.Init;
var
  S: TSystem2D;
begin
  for S in FSystems do
    if S.Enabled then S.Init;
end;

procedure TWorld.Update(ADelta: Single);
var
  S: TSystem2D;
begin
  for S in FSystems do
    if S.Enabled then S.Update(ADelta);
  FEntities.PurgeDestroyed;
end;

procedure TWorld.Render;
var
  S: TSystem2D;
begin
  for S in FSystems do
    if S.Enabled then S.Render;
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
