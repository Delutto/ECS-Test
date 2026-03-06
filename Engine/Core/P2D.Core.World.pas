unit P2D.Core.World;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, fgl,
   P2D.Core.Event, P2D.Core.Types, P2D.Core.Component, P2D.Core.Entity, P2D.Core.System;

type
   TSystemList = specialize TFPGObjectList<TSystem2D>;

   TWorld = class(TWorldBase)
   private
      FEntities      : TEntityManager;
      FSystems       : TSystemList;
      FEventBus      : TEventBus;
      FShutdownCalled: Boolean;

      procedure SortSystems;
      procedure InvalidateAllSystemCaches;

   protected
      function GetEntities: TEntityManager; override;
      function GetEventBus: TEventBus; override;

   public
      constructor Create;
      destructor  Destroy; override;

      { --- Entidades --------------------------------------------------------- }
      function  CreateEntity(const AName: string = ''): TEntity; override;

      { Nova API: Criação com pooling }
      function  CreatePooledEntity(const ATag: string; const AName: string = ''): TEntity;

      procedure DestroyEntity(AID: TEntityID); override;
      function  GetEntity(AID: TEntityID): TEntity; override;

      { Pool Management }
      procedure ConfigureEntityPool(const ATag: string; AInitialSize, AMaxSize: Integer);
      procedure PreallocateEntityPool(const ATag: string; ACount: Integer);
      procedure ClearEntityPool(const ATag: string);

      { --- Sistemas ---------------------------------------------------------- }
      function  AddSystem(ASystem: TSystem2D): TSystem2D;
      function  GetSystem(AClass: TSystem2DClass): TSystem2D;

      { --- Loop principal ---------------------------------------------------- }
      procedure Init;
      procedure FixedUpdate(AFixedDelta: Single); override;
      procedure Update(ADelta: Single);
      procedure Render;
      procedure RenderByLayer(ALayer: TRenderLayer); override;
      procedure Shutdown;

      { Debug }
      {$IFDEF DEBUG}
      procedure PrintEntityPoolStats;
      {$ENDIF}

      property Entities: TEntityManager read FEntities;
      property Systems : TSystemList    read FSystems;
      property EventBus: TEventBus      read FEventBus;
   end;

function SystemCompare(const A, B: TSystem2D): Integer;

implementation

uses
   P2D.Utils.Logger;

function SystemCompare(const A, B: TSystem2D): Integer;
begin
   if A.Priority < B.Priority then
      Result := -1
   else if A.Priority > B.Priority then
      Result := 1
   else
      Result := 0;
end;

constructor TWorld.Create;
begin
   inherited Create;

   FEntities       := TEntityManager.Create;
   FSystems        := TSystemList.Create(True);
   FEventBus       := TEventBus.Create;
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
   for S in FSystems do
       S.InvalidateCache;
end;

function TWorld.CreateEntity(const AName: string): TEntity;
begin
   Result := FEntities.CreateEntity(AName);
   InvalidateAllSystemCaches;
end;

function TWorld.CreatePooledEntity(const ATag: string; const AName: string): TEntity;
begin
   Result := FEntities.CreatePooledEntity(ATag, AName);
   InvalidateAllSystemCaches;

   {$IFDEF DEBUG}
   Logger.Debug(Format('[World] Pooled entity created: Tag="%s", Name="%s"', [ATag, AName]));
   {$ENDIF}
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

procedure TWorld.ConfigureEntityPool(const ATag: string; AInitialSize, AMaxSize: Integer);
begin
   FEntities.ConfigurePool(ATag, AInitialSize, AMaxSize);
end;

procedure TWorld.PreallocateEntityPool(const ATag: string; ACount: Integer);
begin
   FEntities.PreallocatePool(ATag, ACount);
end;

procedure TWorld.ClearEntityPool(const ATag: string);
begin
   FEntities.ClearPool(ATag);
end;

function TWorld.AddSystem(ASystem: TSystem2D): TSystem2D;
var
   S: TSystem2D;
begin
   for S in FSystems do
      if S = ASystem then
         raise Exception.CreateFmt('TWorld.AddSystem: Sistema "%s" já registrado.', [ASystem.ClassName]);
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
      if S.Enabled then
         S.Init;
end;

procedure TWorld.FixedUpdate(AFixedDelta: Single);
var
   S: TSystem2D;
begin
   for S in FSystems do
      if S.Enabled then
         S.FixedUpdate(AFixedDelta);
end;

procedure TWorld.Update(ADelta: Single);
var
   S: TSystem2D;
begin
   for S in FSystems do
      if S.Enabled then
         S.Update(ADelta);

   FEntities.PurgeDestroyed;
   FEventBus.Dispatch;
end;

procedure TWorld.Render;
var
  S: TSystem2D;
begin
   for S in FSystems do
      if S.Enabled then
         S.Render;
end;

procedure TWorld.RenderByLayer(ALayer: TRenderLayer);
var
   S: TSystem2D;
begin
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
   FEventBus.Clear;

   for S in FSystems do
      if S.Enabled then
         S.Shutdown;
end;

{$IFDEF DEBUG}
procedure TWorld.PrintEntityPoolStats;
begin
   FEntities.PrintPoolStats;
end;
{$ENDIF}

end.
