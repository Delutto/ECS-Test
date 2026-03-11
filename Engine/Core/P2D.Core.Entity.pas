unit P2D.Core.Entity;

{$mode objfpc}{$H+}

{ =============================================================================
  P2D.Core.Entity — Component storage rewrite: TFPGMap → TComponentArray
    TComponentArray = array[0..MAX_COMPONENT_TYPES-1] of TComponent2D
         • FComponents is a fixed-size inline array; no heap allocation.
         • Slot index = ComponentRegistry ID (0..63), assigned once.
         • GetComponent    → registry lookup* + O(1) array index.
         • HasComponent    → O(1) — single bitset membership test on FSignature.
         • RemoveComponent → registry lookup* + O(1) array nil + signature bit.
         • AddComponent    → registry lookup* + O(1) array write + signature bit.
         • GetComponentByID → TRUE O(1) — direct array index, no lookup at all.

    * Registry lookup: binary search on TFPGMap with at most 64 entries
      (max 6 comparisons). This cost is paid once per call and can be
      eliminated entirely by caching the ComponentID at system Init time
      and calling GetComponentByID in hot loops.

  MEMORY TRADE-OFF:
    Each TEntity now owns a 512-byte inline array (64 × 8 bytes on 64-bit).
    A typical entity with 6-8 components previously used ~160 bytes for the
    TFPGMap (object header + dynamic entries). The array is larger per entity,
    but eliminates heap fragmentation and is contiguous → cache-friendly.
    For typical 2D game entity counts (< 500), the total overhead is < 256 KB.
  ============================================================================= }

interface

uses
   SysUtils, fgl,
   P2D.Core.Types,
   P2D.Core.Component,
   P2D.Core.ComponentRegistry;

type
   { -------------------------------------------------------------------------
     TComponentArray — O(1) indexed component storage.
     Slot [N] holds the component instance whose ComponentRegistry ID = N.
     Unused slots are nil. The array is value-embedded in TEntity (no heap).
   ------------------------------------------------------------------------- }
   TComponentArray = array[0..MAX_COMPONENT_TYPES - 1] of TComponent2D;

   { -------------------------------------------------------------------------
     TEntity - Entidade base do ECS
   ------------------------------------------------------------------------- }

   { TEntity }

   TEntity = class
   private
      FID             : TEntityID;
      FName           : string;
      FAlive          : Boolean;
      FComponents     : TComponentArray; // O(1) indexed by ComponentRegistry ID
      FPooled         : Boolean;
      FTag            : string;
      FSignature      : TComponentSignature;
      FComponentCount : Integer;         // number of non-nil slots (O(1) count)

      {$IFDEF DEBUG}
      FComponentAddCount   : Integer;
      FComponentRemoveCount: Integer;
      {$ENDIF}

   public
      constructor Create(AID: TEntityID; const AName: string = '');
      destructor  Destroy; override;

      { Standard component API — same external signatures as before. }
      function  AddComponent(AComp: TComponent2D): TComponent2D;
      function  GetComponent(AClass: TComponent2DClass): TComponent2D;

      { Hot-path variant: caller supplies the ComponentID directly.
        Obtained once via ComponentRegistry.GetComponentID at system Init.
        Skips the registry lookup entirely — a single array dereference.
        Use this inside per-frame loops that process the same component types. }
      function  GetComponentByID(ACompID: Integer): TComponent2D; inline;

      { O(1) — single bitset membership check on FSignature. }
      function  HasComponent(AClass: TComponent2DClass): Boolean;

      procedure RemoveComponent(AClass: TComponent2DClass);

      { Component Signature }
      function GetSignature: TComponentSignature;

      { Pool Management }
      procedure ResetForPool; virtual;
      procedure ActivateFromPool; virtual;

      {$IFDEF DEBUG}
      procedure PrintComponentStats;
      {$ENDIF}

      property ID             : TEntityID read FID;
      property Name           : string    read FName           write FName;
      property Alive          : Boolean   read FAlive          write FAlive;
      property Pooled         : Boolean   read FPooled         write FPooled;
      property Tag            : string    read FTag            write FTag;
      property ComponentCount : Integer   read FComponentCount;
   end;

   { -------------------------------------------------------------------------
     Entity Lists and Maps — unchanged
   ------------------------------------------------------------------------- }
   TEntityList = specialize TFPGObjectList<TEntity>;
   TEntityMap  = specialize TFPGMap<TEntityID, TEntity>;

   { -------------------------------------------------------------------------
     TEntityPool - Pool interno de entidades por tag — unchanged
   ------------------------------------------------------------------------- }
   TEntityPool = record
      Tag      : string;
      Entities : TEntityList;
      MaxSize  : Integer;
      HitCount : Int64;
      MissCount: Int64;
   end;

   TEntityPoolArray = array of TEntityPool;

   { -------------------------------------------------------------------------
     TEntityManager - Gerencia entidades ativas E pooled — unchanged
   ------------------------------------------------------------------------- }
   TEntityManager = class
   private
      FEntities : TEntityList;
      FEntityMap: TEntityMap;
      FNextID   : TEntityID;

      FPools          : TEntityPoolArray;
      FPoolingEnabled : Boolean;
      FDefaultPoolSize: Integer;
      FMaxPoolSize    : Integer;

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

      function  CreateEntity(const AName: string = ''): TEntity;
      function  CreatePooledEntity(const ATag: string; const AName: string = ''): TEntity;
      procedure DestroyEntity(AID: TEntityID);
      function  GetEntity(AID: TEntityID): TEntity;
      function  GetAll: TEntityList;
      procedure PurgeDestroyed;

      procedure ConfigurePool(const ATag: string; AInitialSize, AMaxSize: Integer);
      procedure ClearPool(const ATag: string);
      procedure ClearAllPools;
      procedure PreallocatePool(const ATag: string; ACount: Integer);

      {$IFDEF DEBUG}
      procedure PrintStats;
      procedure PrintPoolStats;
      function  GetPoolUtilization(const ATag: string): Single;
      {$ENDIF}

      property PoolingEnabled : Boolean read FPoolingEnabled  write FPoolingEnabled;
      property DefaultPoolSize: Integer read FDefaultPoolSize write FDefaultPoolSize;
      property MaxPoolSize    : Integer read FMaxPoolSize     write FMaxPoolSize;
   end;

implementation

uses
   P2D.Utils.Logger;

{ ============================================================================
  TEntity
  ============================================================================ }

constructor TEntity.Create(AID: TEntityID; const AName: string);
begin
   inherited Create;

   FID             := AID;
   FName           := AName;
   FAlive          := True;
   FPooled         := False;
   FTag            := '';
   FSignature      := [];
   FComponentCount := 0;

   { Zero-fill the entire array in a single call.
     FillChar sets all 512 bytes (64 pointers) to 0 = nil.
     This replaces TComponentMap.Create + Sorted := True. }
   FillChar(FComponents, SizeOf(FComponents), 0);

   {$IFDEF DEBUG}
   FComponentAddCount    := 0;
   FComponentRemoveCount := 0;
   Logger.Debug(Format('[Entity %d] Created: "%s"', [FID, FName]));
   {$ENDIF}
end;

destructor TEntity.Destroy;
var
   I           : Integer;
   Comp        : TComponent2D;
   CompClassName: string;
begin
   {$IFDEF DEBUG}
   Logger.Debug(Format('[Entity %d] Destroying "%s" with %d components',
      [FID, FName, FComponentCount]));
   {$ENDIF}

   { Iterate the full array; only non-nil slots hold live components.
     No need for a reverse loop — array slots are independent. }
   for I := 0 to MAX_COMPONENT_TYPES - 1 do
   begin
      Comp := FComponents[I];
      if not Assigned(Comp) then
         Continue;

      {$IFDEF DEBUG}
      CompClassName := Comp.ClassName;
      {$ENDIF}

      try
         FComponents[I] := nil;  // clear slot before Free (safe against re-entry)
         Comp.Free;
         {$IFDEF DEBUG}
         Logger.Debug(Format('[Entity %d] Component freed: %s', [FID, CompClassName]));
         {$ENDIF}
      except
         on E: Exception do
            Logger.Error(Format('[Entity %d] Error freeing component %s: %s',
               [FID, CompClassName, E.Message]));
      end;
   end;

   { No FComponents.Free — the array is value-embedded in TEntity. }

   {$IFDEF DEBUG}
   Logger.Debug(Format('[Entity %d] Destroyed successfully', [FID]));
   {$ENDIF}

   inherited;
end;

{ -----------------------------------------------------------------------------
  AddComponent
  OLD: O(log m) IndexOf (duplicate check) + map insertion.
  NEW: registry lookup → O(1) array write + signature Include.
       Duplicate check is a simple Assigned() test on the slot.
  ----------------------------------------------------------------------------- }
function TEntity.AddComponent(AComp: TComponent2D): TComponent2D;
var
   CompID       : Integer;
   CompClassName: string;
begin
   if not Assigned(AComp) then
   begin
      Logger.Error(Format('[Entity %d] AddComponent: Component cannot be nil', [FID]));
      raise EArgumentNilException.Create('TEntity.AddComponent: AComp cannot be nil');
   end;

   AComp.OwnerEntity := FID;
   CompClassName     := AComp.ClassName;

   { Resolve the component's registry ID. Auto-register if not yet known. }
   CompID := ComponentRegistry.GetComponentID(TComponent2DClass(AComp.ClassType));
   if CompID < 0 then
      CompID := ComponentRegistry.Register(TComponent2DClass(AComp.ClassType));

   { Replace an existing component of the same type if the slot is occupied. }
   if Assigned(FComponents[CompID]) then
   begin
      {$IFDEF DEBUG}
      Logger.Warn(Format('[Entity %d] Replacing component %s', [FID, CompClassName]));
      {$ENDIF}
      try
         FComponents[CompID].Free;
         FComponents[CompID] := nil;
      except
         on E: Exception do
            Logger.Error(Format('[Entity %d] Error freeing old component %s: %s',
               [FID, CompClassName, E.Message]));
      end;
      { FComponentCount stays the same — same slot reused, not a new slot. }
   end
   else
   begin
      { New slot occupied → update the live-component counter. }
      Inc(FComponentCount);
      {$IFDEF DEBUG}
      Inc(FComponentAddCount);
      {$ENDIF}
   end;

   { O(1) write — direct array index. }
   FComponents[CompID] := AComp;

   { Update the bitset signature — O(1) set Include. }
   Include(FSignature, CompID);

   Result := AComp;
end;

{ -----------------------------------------------------------------------------
  GetComponent
  OLD: O(log m) IndexOf on the per-entity TFPGMap.
  NEW: registry lookup (≤ 6 comparisons on 64 entries) + O(1) array index.
       For the fastest possible access, use GetComponentByID with a cached ID.
  ----------------------------------------------------------------------------- }
function TEntity.GetComponent(AClass: TComponent2DClass): TComponent2D;
var
   CompID: Integer;
begin
   Result := nil;

   if not Assigned(AClass) then
      Exit;

   CompID := ComponentRegistry.GetComponentID(AClass);
   if CompID < 0 then
      Exit;                    // component type not registered → cannot exist

   Result := FComponents[CompID];  // O(1) array dereference
end;

{ -----------------------------------------------------------------------------
  GetComponentByID — TRUE O(1), no registry lookup.
  Call pattern in a hot system:
    In Init:   FSpriteID    := ComponentRegistry.GetComponentID(TSpriteComponent);
               FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
    In Update: Spr := TSpriteComponent(E.GetComponentByID(FSpriteID));
               Tr  := TTransformComponent(E.GetComponentByID(FTransformID));
  ----------------------------------------------------------------------------- }
function TEntity.GetComponentByID(ACompID: Integer): TComponent2D;
begin
   if (ACompID < 0) or (ACompID >= MAX_COMPONENT_TYPES) then
   begin
      Result := nil;
      Exit;
   end;
   Result := FComponents[ACompID];  // single array dereference
end;

{ -----------------------------------------------------------------------------
  HasComponent
  OLD: O(log m) IndexOf on the per-entity TFPGMap.
  NEW: O(1) — single bitset membership test (CompID in FSignature).
       No array access, no registry lookup needed for the common True case.
       FSignature is maintained in sync with the array by AddComponent /
       RemoveComponent, so it is always authoritative.
  ----------------------------------------------------------------------------- }
function TEntity.HasComponent(AClass: TComponent2DClass): Boolean;
var
   CompID: Integer;
begin
   if not Assigned(AClass) then
   begin
      Result := False;
      Exit;
   end;

   CompID := ComponentRegistry.GetComponentID(AClass);
   if CompID < 0 then
   begin
      Result := False;   // not registered → cannot be on this entity
      Exit;
   end;

   { O(1) — set membership is a single bitwise AND + compare. }
   Result := CompID in FSignature;
end;

{ -----------------------------------------------------------------------------
  RemoveComponent
  OLD: O(log m) IndexOf + O(m) TFPGList.Delete (shifts remaining entries).
  NEW: registry lookup + O(1) array nil + O(1) signature Exclude.
  ----------------------------------------------------------------------------- }
procedure TEntity.RemoveComponent(AClass: TComponent2DClass);
var
   CompID       : Integer;
   Comp         : TComponent2D;
   CompClassName: string;
begin
   if not Assigned(AClass) then
      Exit;

   CompID := ComponentRegistry.GetComponentID(AClass);
   if CompID < 0 then
      Exit;

   Comp := FComponents[CompID];
   if not Assigned(Comp) then
      Exit;  // slot is already empty

   CompClassName := Comp.ClassName;

   {$IFDEF DEBUG}
   Inc(FComponentRemoveCount);
   {$ENDIF}

   try
      FComponents[CompID] := nil;      // clear slot first (safe against re-entry)
      Comp.Free;
      Exclude(FSignature, CompID);     // O(1) bitset Exclude
      Dec(FComponentCount);
   except
      on E: Exception do
      begin
         Logger.Error(Format('[Entity %d] Error removing component %s: %s',
            [FID, CompClassName, E.Message]));
         raise;
      end;
   end;
end;

function TEntity.GetSignature: TComponentSignature;
begin
   Result := FSignature;
end;

{ -----------------------------------------------------------------------------
  ResetForPool
  OLD: iterates TFPGMap count, frees data, calls FComponents.Clear.
  NEW: iterates the fixed array, nils each occupied slot.
       FillChar is NOT used here because we must call .Free on each component.
  ----------------------------------------------------------------------------- }
procedure TEntity.ResetForPool;
var
   I: Integer;
begin
   {$IFDEF DEBUG}
   Logger.Debug(Format('[Entity %d] Reset for pool (Tag: %s)', [FID, FTag]));
   {$ENDIF}

   for I := 0 to MAX_COMPONENT_TYPES - 1 do
   begin
      if Assigned(FComponents[I]) then
      begin
         FComponents[I].Free;
         FComponents[I] := nil;
      end;
   end;

   FSignature      := [];
   FComponentCount := 0;
   FAlive          := False;
   FPooled         := True;
   FName           := '';

   {$IFDEF DEBUG}
   FComponentAddCount    := 0;
   FComponentRemoveCount := 0;
   {$ENDIF}
end;

procedure TEntity.ActivateFromPool;
begin
   FAlive  := True;
   FPooled := False;

   {$IFDEF DEBUG}
   Logger.Debug(Format('[Entity %d] Activated from pool (Tag: %s)', [FID, FTag]));
   {$ENDIF}
end;

{$IFDEF DEBUG}
procedure TEntity.PrintComponentStats;
var
   I   : Integer;
   Comp: TComponent2D;
begin
   Logger.Info(Format('=== Entity %d Stats ===', [FID]));
   Logger.Info(Format('Name: %s',           [FName]));
   Logger.Info(Format('Tag: %s',            [FTag]));
   Logger.Info(Format('Alive: %s',          [BoolToStr(FAlive, True)]));
   Logger.Info(Format('Pooled: %s',         [BoolToStr(FPooled, True)]));
   Logger.Info(Format('Components: %d',     [FComponentCount]));
   Logger.Info(Format('Total Added: %d',    [FComponentAddCount]));
   Logger.Info(Format('Total Removed: %d',  [FComponentRemoveCount]));

   if FComponentCount > 0 then
   begin
      Logger.Info('Component List (by Registry ID):');
      for I := 0 to MAX_COMPONENT_TYPES - 1 do
      begin
         Comp := FComponents[I];
         if Assigned(Comp) then
            Logger.Info(Format('  ID[%02d] %s (Enabled: %s)',
               [I, Comp.ClassName, BoolToStr(Comp.Enabled, True)]));
      end;
   end;

   Logger.Info('========================');
end;
{$ENDIF}

{ ============================================================================
  TEntityManager — implementation unchanged from original
  ============================================================================ }

constructor TEntityManager.Create;
begin
   inherited Create;

   FEntities        := TEntityList.Create(True);
   FEntityMap       := TEntityMap.Create;
   FEntityMap.Sorted := True;
   FNextID          := 1;

   SetLength(FPools, 0);
   FPoolingEnabled  := True;
   FDefaultPoolSize := 50;
   FMaxPoolSize     := 500;

   {$IFDEF DEBUG}
   FTotalCreated   := 0;
   FTotalDestroyed := 0;
   FTotalPooled    := 0;
   FTotalReused    := 0;
   Logger.Info('[EntityManager] Created with pooling enabled');
   {$ENDIF}
end;

destructor TEntityManager.Destroy;
begin
   {$IFDEF DEBUG}
   Logger.Info(Format('[EntityManager] Destroying with %d active entities',
      [FEntities.Count]));
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
      if FPools[I].Tag = ATag then
      begin
         Result := I;
         Exit;
      end;
end;

function TEntityManager.GetOrCreatePool(const ATag: string): Integer;
var
   PoolIndex: Integer;
begin
   PoolIndex := FindPool(ATag);
   if PoolIndex < 0 then
   begin
      PoolIndex := Length(FPools);
      SetLength(FPools, PoolIndex + 1);
      FPools[PoolIndex].Tag      := ATag;
      FPools[PoolIndex].Entities := TEntityList.Create(True);
      FPools[PoolIndex].MaxSize  := FMaxPoolSize;
      FPools[PoolIndex].HitCount := 0;
      FPools[PoolIndex].MissCount:= 0;
      {$IFDEF DEBUG}
      Logger.Info(Format('[EntityManager] Created pool for tag "%s"', [ATag]));
      {$ENDIF}
   end;
   Result := PoolIndex;
end;

function TEntityManager.AcquireFromPool(const ATag: string): TEntity;
var
   PoolIndex: Integer;
   Pool     : ^TEntityPool;
   E        : TEntity;
   I        : Integer;
begin
   Result := nil;
   if not FPoolingEnabled then Exit;

   PoolIndex := FindPool(ATag);
   if PoolIndex < 0 then Exit;

   Pool := @FPools[PoolIndex];

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
         Logger.Debug(Format('[EntityManager] Entity reused from pool "%s" (ID: %d)',
            [ATag, Result.ID]));
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
   if not Assigned(AEntity) or (AEntity.Tag = '') then Exit;

   PoolIndex := FindPool(AEntity.Tag);
   if PoolIndex < 0 then Exit;

   AEntity.ResetForPool;

   {$IFDEF DEBUG}
   Inc(FTotalPooled);
   Logger.Debug(Format('[EntityManager] Entity returned to pool "%s" (ID: %d)',
      [AEntity.Tag, AEntity.ID]));
   {$ENDIF}
end;

function TEntityManager.CreateEntity(const AName: string): TEntity;
begin
   Result := TEntity.Create(FNextID, AName);
   FEntities.Add(Result);
   FEntityMap[FNextID] := Result;
   {$IFDEF DEBUG}
   Inc(FTotalCreated);
   Logger.Debug(Format('[EntityManager] Entity created: ID=%d, Name="%s"',
      [FNextID, AName]));
   {$ENDIF}
   Inc(FNextID);
end;

function TEntityManager.CreatePooledEntity(const ATag: string;
   const AName: string): TEntity;
var
   PoolIndex: Integer;
   Pool     : ^TEntityPool;
begin
   Result := AcquireFromPool(ATag);
   if Assigned(Result) then
   begin
      Result.Name := AName;
      Exit;
   end;

   Result      := CreateEntity(AName);
   Result.Tag  := ATag;

   PoolIndex := GetOrCreatePool(ATag);
   Pool      := @FPools[PoolIndex];

   if Pool^.Entities.Count < Pool^.MaxSize then
   begin
      Pool^.Entities.Add(Result);
      {$IFDEF DEBUG}
      Logger.Debug(Format('[EntityManager] Entity added to pool "%s" (Pool size: %d)',
         [ATag, Pool^.Entities.Count]));
      {$ENDIF}
   end
   else
   begin
      {$IFDEF DEBUG}
      Logger.Warn(Format('[EntityManager] Pool "%s" is full (%d entities)',
         [ATag, Pool^.MaxSize]));
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
      Logger.Debug(Format('[EntityManager] Marking entity for destruction: ID=%d, Tag="%s"',
         [AID, E.Tag]));
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
   I         : Integer;
   AID       : TEntityID;
   Idx       : Integer;
   E         : TEntity;
   EntityName: string;
   EntityTag : string;
   ShouldPool: Boolean;
begin
   for I := FEntities.Count - 1 downto 0 do
   begin
      E := FEntities[I];
      if not E.Alive then
      begin
         AID        := E.ID;
         EntityName := E.Name;
         EntityTag  := E.Tag;
         ShouldPool := (EntityTag <> '') and FPoolingEnabled;

         {$IFDEF DEBUG}
         Logger.Debug(Format(
            '[EntityManager] Purging entity: ID=%d, Name="%s", Tag="%s", Pool=%s',
            [AID, EntityName, EntityTag, BoolToStr(ShouldPool, True)]));
         {$ENDIF}

         Idx := FEntityMap.IndexOf(AID);
         if Idx >= 0 then
            FEntityMap.Delete(Idx);

         if ShouldPool then
            ReturnToPool(E)
         else
         begin
            try
               FEntities.Delete(I);
               {$IFDEF DEBUG}
               Inc(FTotalDestroyed);
               {$ENDIF}
            except
               on Ex: Exception do
                  Logger.Error(Format('[EntityManager] Error purging entity %d: %s',
                     [AID, Ex.Message]));
            end;
         end;
      end;
   end;
end;

procedure TEntityManager.ConfigurePool(const ATag: string;
   AInitialSize, AMaxSize: Integer);
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
   I        : Integer;
   E        : TEntity;
   PoolIndex: Integer;
begin
   PoolIndex := GetOrCreatePool(ATag);
   for I := 1 to ACount do
   begin
      if FPools[PoolIndex].Entities.Count >= FPools[PoolIndex].MaxSize then
         Break;
      E      := CreateEntity(Format('%s_Pool_%d', [ATag, I]));
      E.Tag  := ATag;
      E.ResetForPool;
      FPools[PoolIndex].Entities.Add(E);
   end;
   {$IFDEF DEBUG}
   Logger.Info(Format('[EntityManager] Pool "%s" preallocated with %d entities',
      [ATag, FPools[PoolIndex].Entities.Count]));
   {$ENDIF}
end;

procedure TEntityManager.ClearPool(const ATag: string);
var
   PoolIndex: Integer;
   I        : Integer;
begin
   PoolIndex := FindPool(ATag);
   if PoolIndex < 0 then Exit;
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
      FPools[I].Entities.Free;
   SetLength(FPools, 0);
   {$IFDEF DEBUG}
   Logger.Info('[EntityManager] All pools cleared');
   {$ENDIF}
end;

{$IFDEF DEBUG}
procedure TEntityManager.PrintStats;
begin
   Logger.Info('=== EntityManager Stats ===');
   Logger.Info(Format('Active Entities:  %d', [FEntities.Count]));
   Logger.Info(Format('Total Created:    %d', [FTotalCreated]));
   Logger.Info(Format('Total Destroyed:  %d', [FTotalDestroyed]));
   Logger.Info(Format('Total Pooled:     %d', [FTotalPooled]));
   Logger.Info(Format('Total Reused:     %d', [FTotalReused]));
   Logger.Info(Format('Next ID:          %d', [FNextID]));
   Logger.Info(Format('Pooling Enabled:  %s', [BoolToStr(FPoolingEnabled, True)]));
   Logger.Info('===========================');
end;

procedure TEntityManager.PrintPoolStats;
var
   I, J        : Integer;
   Pool        : ^TEntityPool;
   ActiveCount : Integer;
   PooledCount : Integer;
   HitRate     : Single;
   TotalAccess : Int64;
begin
   if Length(FPools) = 0 then
   begin
      Logger.Info('No entity pools configured');
      Exit;
   end;

   Logger.Info('=== Entity Pool Stats ===');
   for I := 0 to High(FPools) do
   begin
      Pool        := @FPools[I];
      ActiveCount := 0;
      PooledCount := 0;
      for J := 0 to Pool^.Entities.Count - 1 do
         if Pool^.Entities[J].Pooled then Inc(PooledCount)
         else Inc(ActiveCount);

      TotalAccess := Pool^.HitCount + Pool^.MissCount;
      if TotalAccess > 0 then
         HitRate := (Pool^.HitCount / TotalAccess) * 100.0
      else
         HitRate := 0.0;

      Logger.Info(Format('Pool: "%s"', [Pool^.Tag]));
      Logger.Info(Format('  Total Size: %d / %d', [Pool^.Entities.Count, Pool^.MaxSize]));
      Logger.Info(Format('  Active: %d', [ActiveCount]));
      Logger.Info(Format('  Pooled: %d', [PooledCount]));
      Logger.Info(Format('  Hit Rate: %.1f%% (%d hits, %d misses)',
         [HitRate, Pool^.HitCount, Pool^.MissCount]));
      Logger.Info('');
   end;
   Logger.Info('=========================');
end;

function TEntityManager.GetPoolUtilization(const ATag: string): Single;
var
   PoolIndex   : Integer;
   ActiveCount : Integer;
   I           : Integer;
begin
   Result    := 0.0;
   PoolIndex := FindPool(ATag);
   if PoolIndex < 0 then Exit;

   ActiveCount := 0;
   for I := 0 to FPools[PoolIndex].Entities.Count - 1 do
      if not FPools[PoolIndex].Entities[I].Pooled then
         Inc(ActiveCount);

   if FPools[PoolIndex].Entities.Count > 0 then
      Result := (ActiveCount / FPools[PoolIndex].Entities.Count) * 100.0;
end;
{$ENDIF}

end.
