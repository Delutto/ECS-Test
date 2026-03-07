unit P2D.Core.Entity;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, fgl,
   P2D.Core.Types,
   P2D.Core.Component,
   P2D.Core.ComponentRegistry;

type
   { -------------------------------------------------------------------------
   Component storage per entity: maps component-class to component instance
   -------------------------------------------------------------------------}
   TComponentMap = specialize TFPGMap<Pointer, TComponent2D>;

   { -------------------------------------------------------------------------
   TEntity - Entidade base do ECS
   -------------------------------------------------------------------------}

   { TEntity }

   TEntity = class
   private
      FID        : TEntityID;
      FName      : string;
      FAlive     : Boolean;
      FComponents: TComponentMap;
      FPooled    : Boolean;  // Indica se está no pool
      FTag       : String;   // Tag para identificação (ex: "Projectile", "Enemy")
      FSignature : TComponentSignature;

      {$IFDEF DEBUG}
      FComponentAddCount   : Integer;
      FComponentRemoveCount: Integer;
      {$ENDIF}

   public
      constructor Create(AID: TEntityID; const AName: string = '');
      destructor  Destroy; override;

      function  AddComponent(AComp: TComponent2D): TComponent2D;
      function  GetComponent(AClass: TComponent2DClass): TComponent2D;
      function  HasComponent(AClass: TComponent2DClass): Boolean;
      procedure RemoveComponent(AClass: TComponent2DClass);

      { Component Signature - para queries O(1) }
      function GetSignature: TComponentSignature;

      { Pool Management }
      procedure ResetForPool; virtual;
      procedure ActivateFromPool; virtual;

      {$IFDEF DEBUG}
      procedure PrintComponentStats;
      {$ENDIF}

      property ID     : TEntityID read FID;
      property Name   : string    read FName  write FName;
      property Alive  : Boolean   read FAlive write FAlive;
      property Pooled : Boolean   read FPooled write FPooled;
      property Tag    : string    read FTag write FTag;
   end;

   { -------------------------------------------------------------------------
   Entity Lists and Maps
   -------------------------------------------------------------------------}
   TEntityList = specialize TFPGObjectList<TEntity>;
   TEntityMap = specialize TFPGMap<TEntityID, TEntity>;

   { -------------------------------------------------------------------------
   TEntityPool - Pool interno de entidades por tag
   -------------------------------------------------------------------------}
   TEntityPool = record
      Tag: string;
      Entities: TEntityList;
      MaxSize: Integer;
      HitCount: Int64;
      MissCount: Int64;
   end;

   TEntityPoolArray = array of TEntityPool;

   { -------------------------------------------------------------------------
   TEntityManager - Gerencia entidades ativas E pooled
   -------------------------------------------------------------------------}
   TEntityManager = class
   private
      FEntities : TEntityList;  // Entidades ativas
      FEntityMap: TEntityMap;   // Mapa para lookup rápido
      FNextID   : TEntityID;

      { Entity Pooling }
      FPools: TEntityPoolArray;
      FPoolingEnabled: Boolean;
      FDefaultPoolSize: Integer;
      FMaxPoolSize: Integer;

      {$IFDEF DEBUG}
      FTotalCreated  : Integer;
      FTotalDestroyed: Integer;
      FTotalPooled   : Integer;
      FTotalReused   : Integer;
      {$ENDIF}

      function FindPool(const ATag: string): Integer;
      function GetOrCreatePool(const ATag: string): Integer;
      function AcquireFromPool(const ATag: string): TEntity;
      procedure ReturnToPool(AEntity: TEntity);

   public
      constructor Create;
      destructor  Destroy; override;

      { Criação normal de entidades }
      function  CreateEntity(const AName: string = ''): TEntity;

      { Criação com pooling - usa tag para identificar o pool }
      function  CreatePooledEntity(const ATag: string; const AName: string = ''): TEntity;

      { Destruição de entidades }
      procedure DestroyEntity(AID: TEntityID);

      { Lookup }
      function  GetEntity(AID: TEntityID): TEntity;
      function  GetAll: TEntityList;

      { Lifecycle }
      procedure PurgeDestroyed;

      { Pool Management }
      procedure ConfigurePool(const ATag: string; AInitialSize, AMaxSize: Integer);
      procedure ClearPool(const ATag: string);
      procedure ClearAllPools;
      procedure PreallocatePool(const ATag: string; ACount: Integer);

      { Statistics }
      {$IFDEF DEBUG}
      procedure PrintStats;
      procedure PrintPoolStats;
      function GetPoolUtilization(const ATag: string): Single;
      {$ENDIF}

      property PoolingEnabled: Boolean read FPoolingEnabled write FPoolingEnabled;
      property DefaultPoolSize: Integer read FDefaultPoolSize write FDefaultPoolSize;
      property MaxPoolSize: Integer read FMaxPoolSize write FMaxPoolSize;
   end;

implementation

uses
   P2D.Utils.Logger;

{ TEntity }

constructor TEntity.Create(AID: TEntityID; const AName: string);
begin
   inherited Create;

   FID         := AID;
   FName       := AName;
   FAlive      := True;
   FPooled     := False;
   FTag        := '';
   FSignature  := [];
   FComponents := TComponentMap.Create;
   FComponents.Sorted := True;

   {$IFDEF DEBUG}
   FComponentAddCount := 0;
   FComponentRemoveCount := 0;
   Logger.Debug(Format('[Entity %d] Created: "%s"', [FID, FName]));
   {$ENDIF}
end;

destructor TEntity.Destroy;
var
   I: Integer;
   Comp: TComponent2D;
   AClassName: string;
begin
   {$IFDEF DEBUG}
   Logger.Debug(Format('[Entity %d] Destroying "%s" with %d components', [FID, FName, FComponents.Count]));
   {$ENDIF}

   for I := FComponents.Count - 1 downto 0 do
   begin
      Comp := FComponents.Data[I];

      if Assigned(Comp) then
      begin
         {$IFDEF DEBUG}
         AClassName := Comp.AClassName;
         {$ENDIF}

         try
            FreeAndNil(Comp);
            {$IFDEF DEBUG}
            Logger.Debug(Format('[Entity %d] Component freed: %s', [FID, AClassName]));
            {$ENDIF}
         except
            on E: Exception do
            begin
               Logger.Error(Format('[Entity %d] Error freeing component %s: %s', [FID, AClassName, E.Message]));
            end;
         end;
      end;
   end;

   FComponents.Free;

   {$IFDEF DEBUG}
   Logger.Debug(Format('[Entity %d] Destroyed successfully', [FID]));
   {$ENDIF}

   inherited;
end;

function TEntity.AddComponent(AComp: TComponent2D): TComponent2D;
var
   Idx: Integer;
   OldComp: TComponent2D;
   CompClassName: String;
   ComponentID: Integer;
begin
   if not Assigned(AComp) then
   begin
      Logger.Error(Format('[Entity %d] AddComponent: Component cannot be nil', [FID]));
      raise EArgumentNilException.Create('TEntity.AddComponent: AComp cannot be nil');
   end;

   CompClassName := AComp.ClassName;
   AComp.OwnerEntity := FID;

   Idx := FComponents.IndexOf(Pointer(AComp.ClassType));

   if Idx >= 0 then
   begin
      OldComp := FComponents.Data[Idx];

      {$IFDEF DEBUG}
      Logger.Warn(Format('[Entity %d] Replacing component %s', [FID, CompClassName]));
      {$ENDIF}

      if Assigned(OldComp) then
      begin
         try
            FComponents.Data[Idx] := nil;
            FreeAndNil(OldComp);
         except
            on E: Exception do
               Logger.Error(Format('[Entity %d] Error freeing old component %s: %s', [FID, CompClassName, E.Message]));
         end;
      end;
   end
   else
   begin
      {$IFDEF DEBUG}
      Inc(FComponentAddCount);
      {$ENDIF}
   end;

   FComponents[Pointer(AComp.ClassType)] := AComp;

   ComponentID := ComponentRegistry.GetComponentID(TComponent2DClass(AComp.ClassType));
   if ComponentID >= 0 then
      Include(FSignature, ComponentID)
   else
   begin
      // Componente não registrado - registrar automaticamente
      ComponentID := ComponentRegistry.Register(TComponent2DClass(AComp.ClassType));
      Include(FSignature, ComponentID);
   end;

   Result := AComp;
end;

function TEntity.GetComponent(AClass: TComponent2DClass): TComponent2D;
var
   Idx: Integer;
begin
   Result := nil;

   if not Assigned(AClass) then
      Exit;

   Idx := FComponents.IndexOf(Pointer(AClass));
   if Idx >= 0 then
      Result := FComponents.Data[Idx];
end;

function TEntity.HasComponent(AClass: TComponent2DClass): Boolean;
begin
   if not Assigned(AClass) then
   begin
      Result := False;
      Exit;
   end;

   Result := FComponents.IndexOf(Pointer(AClass)) >= 0;
end;

procedure TEntity.RemoveComponent(AClass: TComponent2DClass);
var
   Idx: Integer;
   Comp: TComponent2D;
   CompClassName: string;
   ComponentID: Integer;
begin
   if not Assigned(AClass) then
      Exit;

   Idx := FComponents.IndexOf(Pointer(AClass));

   if Idx >= 0 then
   begin
      Comp := FComponents.Data[Idx];

      if Assigned(Comp) then
      begin
         CompClassName := Comp.ClassName;

         {$IFDEF DEBUG}
         Inc(FComponentRemoveCount);
         {$ENDIF}

         try
            FComponents.Delete(Idx);
            FreeAndNil(Comp);

            ComponentID := ComponentRegistry.GetComponentID(AClass);
            if ComponentID >= 0 then
               Exclude(FSignature, ComponentID);

         except
            on E: Exception do
            begin
               Logger.Error(Format('[Entity %d] Error removing component %s: %s', [FID, CompClassName, E.Message]));
               raise;
            end;
         end;
      end
      else
         FComponents.Delete(Idx);
   end;
end;

function TEntity.GetSignature: TComponentSignature;
begin
   Result := FSignature;
end;

procedure TEntity.ResetForPool;
var
   I: Integer;
begin
   {$IFDEF DEBUG}
   Logger.Debug(Format('[Entity %d] Reset for pool (Tag: %s)', [FID, FTag]));
   {$ENDIF}

   // Remove todos os componentes mas mantém a entidade viva
   for I := FComponents.Count - 1 downto 0 do
   begin
      if Assigned(FComponents.Data[I]) then
         FComponents.Data[I].Free;
   end;
   FComponents.Clear;

   FSignature := [];  // ← ADICIONAR (resetar signature)

   FAlive := False;
   FPooled := True;
   FName := '';

   {$IFDEF DEBUG}
   FComponentAddCount := 0;
   FComponentRemoveCount := 0;
   {$ENDIF}
end;

procedure TEntity.ActivateFromPool;
begin
   FAlive := True;
   FPooled := False;

   {$IFDEF DEBUG}
   Logger.Debug(Format('[Entity %d] Activated from pool (Tag: %s)', [FID, FTag]));
   {$ENDIF}
end;

{$IFDEF DEBUG}
procedure TEntity.PrintComponentStats;
var
   I: Integer;
begin
   Logger.Info(Format('=== Entity %d Stats ===', [FID]));
   Logger.Info(Format('Name: %s', [FName]));
   Logger.Info(Format('Tag: %s', [FTag]));
   Logger.Info(Format('Alive: %s', [BoolToStr(FAlive, True)]));
   Logger.Info(Format('Pooled: %s', [BoolToStr(FPooled, True)]));
   Logger.Info(Format('Components: %d', [FComponents.Count]));
   Logger.Info(Format('Total Added: %d', [FComponentAddCount]));
   Logger.Info(Format('Total Removed: %d', [FComponentRemoveCount]));

   if FComponents.Count > 0 then
   begin
      Logger.Info('Component List:');
      for I := 0 to FComponents.Count - 1 do
      begin
         if Assigned(FComponents.Data[I]) then
            Logger.Info(Format('  [%d] %s (Enabled: %s)', [I, FComponents.Data[I].ClassName, BoolToStr(FComponents.Data[I].Enabled, True)]))
         else
            Logger.Warn(Format('  [%d] <NULL COMPONENT>', [I]));
      end;
   end;

   Logger.Info('========================');
end;
{$ENDIF}

{ TEntityManager }

constructor TEntityManager.Create;
begin
   inherited Create;

   FEntities := TEntityList.Create(True);
   FEntityMap := TEntityMap.Create;
   FEntityMap.Sorted := True;
   FNextID := 1;

   SetLength(FPools, 0);
   FPoolingEnabled := True;
   FDefaultPoolSize := 50;
   FMaxPoolSize := 500;

   {$IFDEF DEBUG}
   FTotalCreated := 0;
   FTotalDestroyed := 0;
   FTotalPooled := 0;
   FTotalReused := 0;
   Logger.Info('[EntityManager] Created with pooling enabled');
   {$ENDIF}
end;

destructor TEntityManager.Destroy;
begin
   {$IFDEF DEBUG}
   Logger.Info(Format('[EntityManager] Destroying with %d active entities', [FEntities.Count]));
   PrintStats;
   PrintPoolStats;
   {$ENDIF}

   ClearAllPools;
   FEntities.Free;
   FEntityMap.Free;

   {$IFDEF DEBUG}
   Logger.Info('[EntityManager] Destroyed');
   {$ENDIF}

   inherited;
end;

function TEntityManager.FindPool(const ATag: string): Integer;
var
   I: Integer;
begin
   Result := -1;
   for I := 0 to High(FPools) do
   begin
      if FPools[I].Tag = ATag then
      begin
         Result := I;
         Exit;
      end;
   end;
end;

function TEntityManager.GetOrCreatePool(const ATag: string): Integer;
var
   PoolIndex: Integer;
begin
   PoolIndex := FindPool(ATag);

   if PoolIndex < 0 then
   begin
      // Cria novo pool
      PoolIndex := Length(FPools);
      SetLength(FPools, PoolIndex + 1);

      FPools[PoolIndex].Tag := ATag;
      FPools[PoolIndex].Entities := TEntityList.Create(True);
      FPools[PoolIndex].MaxSize := FMaxPoolSize;
      FPools[PoolIndex].HitCount := 0;
      FPools[PoolIndex].MissCount := 0;

      {$IFDEF DEBUG}
      Logger.Info(Format('[EntityManager] Created pool for tag "%s"', [ATag]));
      {$ENDIF}
   end;

   Result := PoolIndex;
end;

function TEntityManager.AcquireFromPool(const ATag: string): TEntity;
var
   PoolIndex: Integer;
   Pool: ^TEntityPool;
   E: TEntity;
   I: Integer;
begin
   Result := nil;

   if not FPoolingEnabled then
      Exit;

   PoolIndex := FindPool(ATag);
   if PoolIndex < 0 then
      Exit;

   Pool := @FPools[PoolIndex];

   // Procura entidade disponível no pool
   for I := 0 to Pool^.Entities.Count - 1 do
   begin
      E := Pool^.Entities[I];
      if E.Pooled then
      begin
         Result := E;
         Result.ActivateFromPool;
         Inc(Pool^.HitCount);

         {$IFDEF DEBUG}
         Inc(FTotalReused);
         Logger.Debug(Format('[EntityManager] Entity reused from pool "%s" (ID: %d)', [ATag, Result.ID]));
         {$ENDIF}

         Exit;
      end;
   end;

   Inc(Pool^.MissCount);
end;

procedure TEntityManager.ReturnToPool(AEntity: TEntity);
var
   PoolIndex: Integer;
begin
   if not Assigned(AEntity) or (AEntity.Tag = '') then
      Exit;

   PoolIndex := FindPool(AEntity.Tag);
   if PoolIndex < 0 then
      Exit;

   AEntity.ResetForPool;

   {$IFDEF DEBUG}
   Inc(FTotalPooled);
   Logger.Debug(Format('[EntityManager] Entity returned to pool "%s" (ID: %d)', [AEntity.Tag, AEntity.ID]));
   {$ENDIF}
end;

function TEntityManager.CreateEntity(const AName: string): TEntity;
begin
   Result := TEntity.Create(FNextID, AName);
   FEntities.Add(Result);
   FEntityMap[FNextID] := Result;

   {$IFDEF DEBUG}
   Inc(FTotalCreated);
   Logger.Debug(Format('[EntityManager] Entity created: ID=%d, Name="%s"', [FNextID, AName]));
   {$ENDIF}

   Inc(FNextID);
end;

function TEntityManager.CreatePooledEntity(const ATag: string; const AName: string): TEntity;
var
   PoolIndex: Integer;
   Pool: ^TEntityPool;
begin
   // Tenta adquirir do pool primeiro
   Result := AcquireFromPool(ATag);

   if Assigned(Result) then
   begin
      Result.Name := AName;
      Exit;
   end;

   // Pool miss - cria nova entidade
   Result := CreateEntity(AName);
   Result.Tag := ATag;

   // Adiciona ao pool se não excedeu o limite
   PoolIndex := GetOrCreatePool(ATag);
   Pool := @FPools[PoolIndex];

   if Pool^.Entities.Count < Pool^.MaxSize then
   begin
      Pool^.Entities.Add(Result);
      {$IFDEF DEBUG}
      Logger.Debug(Format('[EntityManager] Entity added to pool "%s" (Pool size: %d)', [ATag, Pool^.Entities.Count]));
      {$ENDIF}
   end
   else
   begin
      {$IFDEF DEBUG}
      Logger.Warn(Format('[EntityManager] Pool "%s" is full (%d entities)', [ATag, Pool^.MaxSize]));
      {$ENDIF}
   end;
end;

procedure TEntityManager.DestroyEntity(AID: TEntityID);
var
   E: TEntity;
begin
   E := GetEntity(AID);
   if Assigned(E) then
   begin
      {$IFDEF DEBUG}
      Logger.Debug(Format('[EntityManager] Marking entity for destruction: ID=%d, Tag="%s"', [AID, E.Tag]));
      {$ENDIF}

      E.Alive := False;
   end;
end;

function TEntityManager.GetEntity(AID: TEntityID): TEntity;
var
   Idx: Integer;
begin
   Result := nil;
   Idx := FEntityMap.IndexOf(AID);
   if Idx >= 0 then
      Result := FEntityMap.Data[Idx];
end;

function TEntityManager.GetAll: TEntityList;
begin
   Result := FEntities;
end;

procedure TEntityManager.PurgeDestroyed;
var
   I: Integer;
   AID: TEntityID;
   Idx: Integer;
   E: TEntity;
   EntityName, EntityTag: string;
   ShouldPool: Boolean;
begin
   for I := FEntities.Count - 1 downto 0 do
   begin
      E := FEntities[I];

      if not E.Alive then
      begin
         AID := E.ID;
         EntityName := E.Name;
         EntityTag := E.Tag;
         ShouldPool := (EntityTag <> '') and FPoolingEnabled;

         {$IFDEF DEBUG}
         Logger.Debug(Format('[EntityManager] Purging entity: ID=%d, Name="%s", Tag="%s", Pool=%s', [AID, EntityName, EntityTag, BoolToStr(ShouldPool, True)]));
         {$ENDIF}

         // Remove do mapa
         Idx := FEntityMap.IndexOf(AID);
         if Idx >= 0 then
            FEntityMap.Delete(Idx);

         // Se tem tag, retorna ao pool ao invés de destruir
         if ShouldPool then
         begin
            ReturnToPool(E);
            // Não remove da lista de entidades - mantém no pool
         end
         else
         begin
            // Sem tag ou pooling desabilitado - destrói normalmente
            try
               FEntities.Delete(I);

               {$IFDEF DEBUG}
               Inc(FTotalDestroyed);
               {$ENDIF}
            except
               on Ex: Exception do
                  Logger.Error(Format('[EntityManager] Error purging entity %d: %s', [AID, Ex.Message]));
            end;
         end;
      end;
   end;
end;

procedure TEntityManager.ConfigurePool(const ATag: string; AInitialSize, AMaxSize: Integer);
var
   PoolIndex: Integer;
begin
   PoolIndex := GetOrCreatePool(ATag);
   FPools[PoolIndex].MaxSize := AMaxSize;

   if AInitialSize > 0 then
      PreallocatePool(ATag, AInitialSize);

   {$IFDEF DEBUG}
   Logger.Info(Format('[EntityManager] Pool "%s" configured (Max: %d)', [ATag, AMaxSize]));
   {$ENDIF}
end;

procedure TEntityManager.PreallocatePool(const ATag: string; ACount: Integer);
var
   I: Integer;
   E: TEntity;
   PoolIndex: Integer;
begin
   PoolIndex := GetOrCreatePool(ATag);

   for I := 1 to ACount do
   begin
      if FPools[PoolIndex].Entities.Count >= FPools[PoolIndex].MaxSize then
         Break;

      E := CreateEntity(Format('%s_Pool_%d', [ATag, I]));
      E.Tag := ATag;
      E.ResetForPool;
      FPools[PoolIndex].Entities.Add(E);
   end;

   {$IFDEF DEBUG}
   Logger.Info(Format('[EntityManager] Pool "%s" preallocated with %d entities', [ATag, FPools[PoolIndex].Entities.Count]));
   {$ENDIF}
end;

procedure TEntityManager.ClearPool(const ATag: string);
var
   PoolIndex: Integer;
   I: Integer;
begin
   PoolIndex := FindPool(ATag);
   if PoolIndex < 0 then
      Exit;

   for I := FPools[PoolIndex].Entities.Count - 1 downto 0 do
      FPools[PoolIndex].Entities.Delete(I);

   {$IFDEF DEBUG}
   Logger.Info(Format('[EntityManager] Pool "%s" cleared', [ATag]));
   {$ENDIF}
end;

procedure TEntityManager.ClearAllPools;
var
   I: Integer;
begin
   for I := 0 to High(FPools) do
   begin
      FPools[I].Entities.Free;
   end;

   SetLength(FPools, 0);

   {$IFDEF DEBUG}
   Logger.Info('[EntityManager] All pools cleared');
   {$ENDIF}
end;

{$IFDEF DEBUG}
procedure TEntityManager.PrintStats;
begin
   Logger.Info('=== EntityManager Stats ===');
   Logger.Info(Format('Active Entities: %d', [FEntities.Count]));
   Logger.Info(Format('Total Created: %d', [FTotalCreated]));
   Logger.Info(Format('Total Destroyed: %d', [FTotalDestroyed]));
   Logger.Info(Format('Total Pooled: %d', [FTotalPooled]));
   Logger.Info(Format('Total Reused: %d', [FTotalReused]));
   Logger.Info(Format('Next ID: %d', [FNextID]));
   Logger.Info(Format('Pooling Enabled: %s', [BoolToStr(FPoolingEnabled, True)]));
   Logger.Info('===========================');
end;

procedure TEntityManager.PrintPoolStats;
var
   I, J: Integer;
   Pool: ^TEntityPool;
   ActiveCount, PooledCount: Integer;
   HitRate: Single;
   TotalAccess: Int64;
begin
   if Length(FPools) = 0 then
   begin
      Logger.Info('No entity pools configured');
      Exit;
   end;

   Logger.Info('=== Entity Pool Stats ===');

   for I := 0 to High(FPools) do
   begin
      Pool := @FPools[I];
      ActiveCount := 0;
      PooledCount := 0;

      for J := 0 to Pool^.Entities.Count - 1 do
      begin
         if Pool^.Entities[J].Pooled then
            Inc(PooledCount)
         else
            Inc(ActiveCount);
      end;

      TotalAccess := Pool^.HitCount + Pool^.MissCount;
      if TotalAccess > 0 then
         HitRate := (Pool^.HitCount / TotalAccess) * 100.0
      else
         HitRate := 0.0;

      Logger.Info(Format('Pool: "%s"', [Pool^.Tag]));
      Logger.Info(Format('  Total Size: %d / %d', [Pool^.Entities.Count, Pool^.MaxSize]));
      Logger.Info(Format('  Active: %d', [ActiveCount]));
      Logger.Info(Format('  Pooled: %d', [PooledCount]));
      Logger.Info(Format('  Hit Rate: %.1f%% (%d hits, %d misses)', [HitRate, Pool^.HitCount, Pool^.MissCount]));
      Logger.Info('');
   end;

   Logger.Info('=========================');
end;

function TEntityManager.GetPoolUtilization(const ATag: string): Single;
var
   PoolIndex: Integer;
   ActiveCount, I: Integer;
begin
   Result := 0.0;
   PoolIndex := FindPool(ATag);

   if PoolIndex < 0 then
      Exit;

   ActiveCount := 0;
   for I := 0 to FPools[PoolIndex].Entities.Count - 1 do
   begin
      if not FPools[PoolIndex].Entities[I].Pooled then
         Inc(ActiveCount);
   end;

   if FPools[PoolIndex].Entities.Count > 0 then
      Result := (ActiveCount / FPools[PoolIndex].Entities.Count) * 100.0;
end;
{$ENDIF}

end.
