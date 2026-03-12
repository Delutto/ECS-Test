unit P2D.Core.Entity;

{$mode objfpc}{$H+}

{ =============================================================================
  P2D.Core.Entity

  Optimization 3.1 — Component storage: TFPGMap → TComponentArray (O(1))
  Optimization 3.4 — Pool/Active list separation: FEntities is active-only

  ── 3.1 (component store) ──────────────────────────────────────────────────
  TComponentArray = array[0..MAX_COMPONENT_TYPES-1] of TComponent2D
    • Fixed-size inline array; no heap allocation per entity.
    • Slot index = ComponentRegistry ID (0..63).
    • GetComponent    → registry lookup + O(1) array index.
    • HasComponent    → O(1) bitset test on FSignature.
    • RemoveComponent → registry lookup + O(1) array nil + signature Exclude.
    • AddComponent    → registry lookup + O(1) array write + signature Include.
    • GetComponentByID → true O(1) — direct array index, zero registry cost.

  ── 3.4 (pool/active separation) ───────────────────────────────────────────
  OLD model:
    • Entities were in BOTH FEntities AND Pool^.Entities simultaneously.
    • PurgeDestroyed returned an entity to the pool but LEFT it in FEntities
      with Alive=False, Pooled=True.
    • GetAll returned alive + dead-pooled entities every frame.
    • Every system loop was forced to test "if not E.Alive then Continue"
      to skip those permanently-dead residents.
    • RefreshCache iterated every entry in FEntities including dead-pooled
      ones, paying EntityMatchesFast cost on entities that would always fail
      the Alive check.

  NEW model — two disjoint lists, single ownership:
    • FEntities (OwnsObjects=True)  — holds ONLY currently alive entities.
    • Pool^.Entities (OwnsObjects=True) — holds ONLY inactive/pooled entities.
    • An entity lives in exactly ONE list at any point in time.
    • Ownership transfers between lists via the OwnsObjects toggle pattern:
        disable OwnsObjects → Delete(I) → re-enable OwnsObjects → Add to other list.
      This avoids constructing a new object and avoids any double-free risk.
    • After PurgeDestroyed, FEntities contains zero dead-pooled residents.
    • GetAll returns only alive entities — RefreshCache and every system loop
      are free from unnecessary dead-entity iteration.
    • The "if not E.Alive then Continue" guard is still correct and kept for
      entities that were marked dead within the SAME frame update but have not
      yet been purged (the window between DestroyEntity and PurgeDestroyed).

  ── Ownership invariant ─────────────────────────────────────────────────────
    At any moment, every TEntity object is owned by exactly one list:
      Active state  → FEntities
      Pooled state  → FPools[i].Entities
    Pre-allocated entities (PreallocatePool) are created directly into the pool
    list and never enter FEntities until acquired.
    ClearAllPools frees all pooled entities via FPools[i].Entities.Free.
    FEntities.Free frees all active entities.
    No entity is freed twice.
  ============================================================================= }

interface

uses
   SysUtils, fgl,
   P2D.Core.Types,
   P2D.Core.Component,
   P2D.Core.ComponentRegistry;

type
   { -------------------------------------------------------------------------
     TComponentArray — O(1) indexed component storage (optimization 3.1).
     Slot [N] holds the component whose ComponentRegistry ID = N.
     Unused slots are nil. Value-embedded in TEntity (no separate heap alloc).
   ------------------------------------------------------------------------- }
   TComponentArray = array[0..MAX_COMPONENT_TYPES - 1] of TComponent2D;

   { TEntity }
   TEntity = class
   private
      FID            : TEntityID;
      FName          : string;
      FAlive         : Boolean;
      FComponents    : TComponentArray;
      FPooled        : Boolean;
      FTag           : string;
      FSignature     : TComponentSignature;
      FComponentCount: Integer;

      {$IFDEF DEBUG}
      FComponentAddCount   : Integer;
      FComponentRemoveCount: Integer;
      {$ENDIF}

   public
      constructor Create(AID: TEntityID; const AName: string = '');
      destructor  Destroy; override;

      function  AddComponent(AComp: TComponent2D): TComponent2D;
      function  GetComponent(AClass: TComponent2DClass): TComponent2D;

      { True O(1) hot-path: cache the ComponentID at system Init time and call
        this instead of GetComponent in per-frame loops. }
      function  GetComponentByID(ACompID: Integer): TComponent2D; inline;

      { O(1) bitset test — no array access needed. }
      function  HasComponent(AClass: TComponent2DClass): Boolean;
      procedure RemoveComponent(AClass: TComponent2DClass);
      function  GetSignature: TComponentSignature;

      { Pool lifecycle hooks — called by TEntityManager, not by game code. }
      procedure ResetForPool;    virtual;
      procedure ActivateFromPool; virtual;

      {$IFDEF DEBUG}
      procedure PrintComponentStats;
      {$ENDIF}

      property ID            : TEntityID read FID;
      property Name          : string    read FName            write FName;
      property Alive         : Boolean   read FAlive           write FAlive;
      property Pooled        : Boolean   read FPooled          write FPooled;
      property Tag           : string    read FTag             write FTag;
      property ComponentCount: Integer   read FComponentCount;
   end;

   TEntityList = specialize TFPGObjectList<TEntity>;
   TEntityMap  = specialize TFPGMap<TEntityID, TEntity>;

   TEntityPool = record
      Tag      : string;
      Entities : TEntityList; { OwnsObjects=True — owns pooled (inactive) entities }
      MaxSize  : Integer;
      HitCount : Int64;
      MissCount: Int64;
   end;

   TEntityPoolArray = array of TEntityPool;

   TEntityManager = class
   private
      { OwnsObjects=True — sole owner of active entities.
        After PurgeDestroyed this list contains ONLY Alive=True entities. }
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

      { AcquireFromPool — removes the entity from the pool list and adds it
        to FEntities + FEntityMap. Transfers ownership: pool → FEntities. }
      function AcquireFromPool(const ATag: string): TEntity;

      { ReturnToPool is no longer a separate method. The recycle logic is
        inlined in PurgeDestroyed to perform the ownership transfer atomically
        (remove from FEntities without freeing, add to pool list). }

   public
      constructor Create;
      destructor  Destroy; override;

      function  CreateEntity(const AName: string = ''): TEntity;
      function  CreatePooledEntity(const ATag: string; const AName: string = ''): TEntity;
      procedure DestroyEntity(AID: TEntityID);
      function  GetEntity(AID: TEntityID): TEntity;

      { GetAll returns ONLY alive entities after PurgeDestroyed has run.
        System loops that guard with "if not E.Alive then Continue" remain
        correct for the brief intra-frame window between DestroyEntity and
        PurgeDestroyed, but dead-pooled entities are no longer permanent
        residents of this list. }
      function  GetAll: TEntityList;

      { PurgeDestroyed — called by TWorld.Update after all systems have run.
        For each dead (Alive=False) entity:
          • Non-pooled : freed immediately (FEntities.Delete with OwnsObjects=True).
          • Pooled     : ownership transferred to the matching pool list.
                        Entity is reset (components freed, Pooled=True) and
                        removed from FEntities without being freed. }
      procedure PurgeDestroyed;

      procedure ConfigurePool(const ATag: string; AInitialSize, AMaxSize: Integer);
      procedure ClearPool(const ATag: string);
      procedure ClearAllPools;

      { PreallocatePool — creates entities and places them DIRECTLY into the
        pool list. They never enter FEntities or FEntityMap until acquired.
        This avoids the round-trip: create → add to FEntities → purge → recycle. }
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
   FID            := AID;
   FName          := AName;
   FAlive         := True;
   FPooled        := False;
   FTag           := '';
   FSignature     := [];
   FComponentCount:= 0;
   FillChar(FComponents, SizeOf(FComponents), 0);
   {$IFDEF DEBUG}
   FComponentAddCount    := 0;
   FComponentRemoveCount := 0;
   Logger.Debug(Format('[Entity %d] Created: "%s"', [FID, FName]));
   {$ENDIF}
end;

destructor TEntity.Destroy;
var
   I            : Integer;
   Comp         : TComponent2D;
   CompClassName: string;
begin
   {$IFDEF DEBUG}
   Logger.Debug(Format('[Entity %d] Destroying "%s" with %d components',
      [FID, FName, FComponentCount]));
   {$ENDIF}
   for I := 0 to MAX_COMPONENT_TYPES - 1 do
   begin
      Comp := FComponents[I];
      if not Assigned(Comp) then Continue;
      {$IFDEF DEBUG}
      CompClassName := Comp.ClassName;
      {$ENDIF}
      try
         FComponents[I] := nil;
         Comp.Free;
         {$IFDEF DEBUG}
         Logger.Debug(Format('[Entity %d] Component freed: %s', [FID, CompClassName]));
         {$ENDIF}
      except
         on E: Exception do
            Logger.Error(Format('[Entity %d] Error freeing component %s: %s', [FID, CompClassName, E.Message]));
      end;
   end;
   {$IFDEF DEBUG}
   Logger.Debug(Format('[Entity %d] Destroyed successfully', [FID]));
   {$ENDIF}
   inherited;
end;

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
   CompID := ComponentRegistry.GetComponentID(TComponent2DClass(AComp.ClassType));
   if CompID < 0 then
      CompID := ComponentRegistry.Register(TComponent2DClass(AComp.ClassType));
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
   end
   else
   begin
      Inc(FComponentCount);
      {$IFDEF DEBUG}
      Inc(FComponentAddCount);
      {$ENDIF}
   end;
   FComponents[CompID] := AComp;
   Include(FSignature, CompID);
   Result := AComp;
end;

function TEntity.GetComponent(AClass: TComponent2DClass): TComponent2D;
var
   CompID: Integer;
begin
   Result := nil;
   if not Assigned(AClass) then Exit;
   CompID := ComponentRegistry.GetComponentID(AClass);
   if CompID < 0 then Exit;
   Result := FComponents[CompID];
end;

function TEntity.GetComponentByID(ACompID: Integer): TComponent2D;
begin
   if (ACompID < 0) or (ACompID >= MAX_COMPONENT_TYPES) then
   begin
      Result := nil;
      Exit;
   end;
   Result := FComponents[ACompID];
end;

function TEntity.HasComponent(AClass: TComponent2DClass): Boolean;
var
   CompID: Integer;
begin
   if not Assigned(AClass) then begin Result := False; Exit; end;
   CompID := ComponentRegistry.GetComponentID(AClass);
   if CompID < 0 then begin Result := False; Exit; end;
   Result := CompID in FSignature;
end;

procedure TEntity.RemoveComponent(AClass: TComponent2DClass);
var
   CompID       : Integer;
   Comp         : TComponent2D;
   CompClassName: string;
begin
   if not Assigned(AClass) then Exit;
   CompID := ComponentRegistry.GetComponentID(AClass);
   if CompID < 0 then Exit;
   Comp := FComponents[CompID];
   if not Assigned(Comp) then Exit;
   CompClassName := Comp.ClassName;
   {$IFDEF DEBUG}
   Inc(FComponentRemoveCount);
   {$ENDIF}
   try
      FComponents[CompID] := nil;
      Comp.Free;
      Exclude(FSignature, CompID);
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

procedure TEntity.ResetForPool;
var
   I: Integer;
begin
   {$IFDEF DEBUG}
   Logger.Debug(Format('[Entity %d] Reset for pool (Tag: %s)', [FID, FTag]));
   {$ENDIF}
   for I := 0 to MAX_COMPONENT_TYPES - 1 do
      if Assigned(FComponents[I]) then
      begin
         FComponents[I].Free;
         FComponents[I] := nil;
      end;
   FSignature     := [];
   FComponentCount:= 0;
   FAlive         := False;
   FPooled        := True;
   FName          := '';
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
   Logger.Info(Format('=== Entity %d Stats ===',    [FID]));
   Logger.Info(Format('Name: %s',                   [FName]));
   Logger.Info(Format('Tag: %s',                    [FTag]));
   Logger.Info(Format('Alive: %s',                  [BoolToStr(FAlive, True)]));
   Logger.Info(Format('Pooled: %s',                 [BoolToStr(FPooled, True)]));
   Logger.Info(Format('Components: %d',             [FComponentCount]));
   Logger.Info(Format('Total Added: %d',            [FComponentAddCount]));
   Logger.Info(Format('Total Removed: %d',          [FComponentRemoveCount]));
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
  TEntityManager
  ============================================================================ }

constructor TEntityManager.Create;
begin
   inherited Create;
   FEntities         := TEntityList.Create(True);  { owns active entities }
   FEntityMap        := TEntityMap.Create;
   FEntityMap.Sorted := True;
   FNextID           := 1;
   SetLength(FPools, 0);
   FPoolingEnabled   := True;
   FDefaultPoolSize  := 50;
   FMaxPoolSize      := 500;
   {$IFDEF DEBUG}
   FTotalCreated   := 0;
   FTotalDestroyed := 0;
   FTotalPooled    := 0;
   FTotalReused    := 0;
   Logger.Info('[EntityManager] Created');
   {$ENDIF}
end;

destructor TEntityManager.Destroy;
begin
   {$IFDEF DEBUG}
   Logger.Info(Format('[EntityManager] Destroying — active entities: %d',
      [FEntities.Count]));
   PrintStats;
   PrintPoolStats;
   {$ENDIF}
   { ClearAllPools frees entities owned by pool lists.
     FEntities.Free frees entities owned by the active list.
     By the ownership invariant, no entity is freed twice. }
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
      PoolIndex                      := Length(FPools);
      SetLength(FPools, PoolIndex + 1);
      FPools[PoolIndex].Tag          := ATag;
      { OwnsObjects=True: this list owns the inactive entity objects.
        ClearAllPools / ClearPool frees them through this list. }
      FPools[PoolIndex].Entities     := TEntityList.Create(True);
      FPools[PoolIndex].MaxSize      := FMaxPoolSize;
      FPools[PoolIndex].HitCount     := 0;
      FPools[PoolIndex].MissCount    := 0;
      {$IFDEF DEBUG}
      Logger.Info(Format('[EntityManager] Pool created for tag "%s"', [ATag]));
      {$ENDIF}
   end;
   Result := PoolIndex;
end;

{ AcquireFromPool
  ─────────────────────────────────────────────────────────────────────────────
  Removes an entity from the pool list and registers it as active.

  Ownership transfer: Pool^.Entities → FEntities
    1. Temporarily disable Pool^.Entities.OwnsObjects so that Delete(LastIdx)
       removes the pointer without calling E.Free.
    2. Re-enable OwnsObjects immediately.
    3. Add the entity to FEntities (which now owns it) and to FEntityMap.

  Why take from the TAIL (Count-1)?
    TFPGList.Delete(I) shifts all entries after I left by one — O(n-I) copies.
    Deleting the last entry is O(1): no shift required. Since pool order is
    irrelevant (any free entity is equally valid), this is a free optimization.
  ───────────────────────────────────────────────────────────────────────────── }
function TEntityManager.AcquireFromPool(const ATag: string): TEntity;
var
   PoolIndex: Integer;
   Pool     : ^TEntityPool;
   LastIdx  : Integer;
begin
   Result := nil;
   if not FPoolingEnabled then Exit;

   PoolIndex := FindPool(ATag);
   if PoolIndex < 0 then Exit;

   Pool := @FPools[PoolIndex];

   if Pool^.Entities.Count = 0 then
   begin
      Inc(Pool^.MissCount);
      {$IFDEF DEBUG}
      Logger.Debug(Format('[EntityManager] Pool miss (empty): tag="%s"', [ATag]));
      {$ENDIF}
      Exit;
   end;

   { Take from the tail — O(1) removal, no list shifting. }
   LastIdx := Pool^.Entities.Count - 1;
   Result  := Pool^.Entities[LastIdx];

   { ── Ownership transfer: pool → FEntities ────────────────────────────────
     Disable OwnsObjects so Delete does not call Result.Free,
     then immediately re-enable it so future operations are safe. }
   Pool^.Entities.FreeObjects := False;
   Pool^.Entities.Delete(LastIdx);
   Pool^.Entities.FreeObjects := True;

   { Reactivate the entity and register it in the active structures. }
   Result.ActivateFromPool;
   FEntities.Add(Result);
   FEntityMap[Result.ID] := Result;

   Inc(Pool^.HitCount);
   {$IFDEF DEBUG}
   Inc(FTotalReused);
   Logger.Debug(Format('[EntityManager] Pool hit: tag="%s", ID=%d, pool remaining=%d',
      [ATag, Result.ID, Pool^.Entities.Count]));
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

{ CreatePooledEntity
  ─────────────────────────────────────────────────────────────────────────────
  Pool HIT  (AcquireFromPool succeeds):
    The entity comes from the pool list, is added to FEntities + FEntityMap,
    and its name is updated. No new object is allocated.

  Pool MISS (pool empty or not found):
    A fresh entity is created via CreateEntity (enters FEntities + FEntityMap
    immediately as active). GetOrCreatePool ensures the pool slot exists so
    that PurgeDestroyed can find it later when this entity is recycled.
    The entity is NOT added to the pool list here — it starts its life as
    active. It will be moved to the pool list by PurgeDestroyed when destroyed.
  ───────────────────────────────────────────────────────────────────────────── }
function TEntityManager.CreatePooledEntity(const ATag: string;
   const AName: string): TEntity;
begin
   Result := AcquireFromPool(ATag);
   if Assigned(Result) then
   begin
      Result.Name := AName;
      Exit;
   end;

   { Pool miss — create a fresh active entity. }
   Result     := CreateEntity(AName);
   Result.Tag := ATag;

   { Ensure the pool slot exists so PurgeDestroyed can recycle it. }
   GetOrCreatePool(ATag);

   {$IFDEF DEBUG}
   Logger.Debug(Format('[EntityManager] Pool miss — new entity: tag="%s", ID=%d',
      [ATag, Result.ID]));
   {$ENDIF}
end;

procedure TEntityManager.DestroyEntity(AID: TEntityID);
var
   E: TEntity;
begin
   E := GetEntity(AID);
   if Assigned(E) then
   begin
      {$IFDEF DEBUG}
      Logger.Debug(Format('[EntityManager] Marking entity dead: ID=%d, Tag="%s"',
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

{ PurgeDestroyed
  ─────────────────────────────────────────────────────────────────────────────
  Called once per frame by TWorld.Update after all system updates complete.
  Iterates FEntities from back to front (so that Delete(I) does not invalidate
  earlier indices) and processes every entity with Alive=False.

  For each dead entity:

    ── RECYCLE PATH (tagged entity, pool enabled, pool not full) ────────────
      1. ResetForPool   — frees all components, clears FSignature,
                          sets FAlive=False, FPooled=True, FName=''.
      2. Remove from FEntityMap (already done — happens for both paths).
      3. Ownership transfer: FEntities → Pool^.Entities
           FEntities.OwnsObjects := False  (prevent Free on Delete)
           FEntities.Delete(I)             (removes pointer, no Free)
           FEntities.OwnsObjects := True   (restore normal ownership)
           Pool^.Entities.Add(E)           (pool takes ownership)
      After this, FEntities contains no trace of the entity.
      The entity is ready to be reactivated by AcquireFromPool.

    ── DESTROY PATH (untagged entity, pooling disabled, or pool full) ───────
      FEntities.Delete(I) with OwnsObjects=True calls E.Free immediately.
      Entity memory is released.

  Invariant upheld after every PurgeDestroyed call:
    Every entry in FEntities has Alive=True.
    Every entry in any Pool^.Entities has Alive=False and Pooled=True.
  ───────────────────────────────────────────────────────────────────────────── }
procedure TEntityManager.PurgeDestroyed;
var
   I         : Integer;
   AID       : TEntityID;
   MapIdx    : Integer;
   E         : TEntity;
   EntityTag : string;
   PoolIdx   : Integer;
   Pool      : ^TEntityPool;
   ShouldPool: Boolean;
begin
   for I := FEntities.Count - 1 downto 0 do
   begin
      E := FEntities[I];

      { Fast-path: skip alive entities — the overwhelming majority. }
      if E.Alive then
         Continue;

      AID       := E.ID;
      EntityTag := E.Tag;

      { Always remove from the ID map — entity is no longer addressable. }
      MapIdx := FEntityMap.IndexOf(AID);
      if MapIdx >= 0 then
         FEntityMap.Delete(MapIdx);

      { Determine whether to recycle or destroy. }
      ShouldPool := (EntityTag <> '') and FPoolingEnabled;
      if ShouldPool then
      begin
         PoolIdx := FindPool(EntityTag);
         if PoolIdx >= 0 then
            Pool := @FPools[PoolIdx]
         else
            Pool := nil;
      end
      else
         Pool := nil;

      if Assigned(Pool) and (Pool^.Entities.Count < Pool^.MaxSize) then
      begin
         { ── RECYCLE PATH ────────────────────────────────────────────────────
           Step 1: reset — all components freed, entity made blank and poolable. }
         E.ResetForPool;

         { Step 2: transfer ownership from FEntities to Pool^.Entities.
           OwnsObjects controls whether TFPGObjectList calls E.Free on removal.
           We disable it for the duration of the Delete call only. }
         FEntities.FreeObjects := False;
         FEntities.Delete(I);
         FEntities.FreeObjects := True;

         { Step 3: pool takes ownership. }
         Pool^.Entities.Add(E);

         {$IFDEF DEBUG}
         Inc(FTotalPooled);
         Logger.Debug(Format(
            '[EntityManager] Entity recycled → pool "%s" (ID=%d, pool size=%d)',
            [EntityTag, AID, Pool^.Entities.Count]));
         {$ENDIF}
      end
      else
      begin
         { ── DESTROY PATH ────────────────────────────────────────────────────
           OwnsObjects=True: FEntities.Delete calls E.Free. }
         FEntities.Delete(I);
         {$IFDEF DEBUG}
         Inc(FTotalDestroyed);
         if ShouldPool then
            Logger.Debug(Format(
               '[EntityManager] Pooled entity destroyed (pool full/missing): ID=%d',
               [AID]))
         else
            Logger.Debug(Format('[EntityManager] Entity destroyed: ID=%d', [AID]));
         {$ENDIF}
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
   Logger.Info(Format('[EntityManager] Pool "%s" configured (Max=%d)', [ATag, AMaxSize]));
   {$ENDIF}
end;

{ PreallocatePool
  ─────────────────────────────────────────────────────────────────────────────
  Creates entities and places them DIRECTLY into the pool list.
  They never enter FEntities or FEntityMap until AcquireFromPool is called.

  This avoids the round-trip overhead of:
    CreateEntity (FEntities + FEntityMap) → PurgeDestroyed → recycle

  The entity is constructed with a valid FNextID so that when it is later
  activated, its ID is unique and can be safely inserted into FEntityMap.
  ───────────────────────────────────────────────────────────────────────────── }
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

      { Create directly — bypass CreateEntity to avoid FEntities/FEntityMap
        registration. The entity starts as pooled/inactive. }
      E        := TEntity.Create(FNextID, Format('%s_Pool_%d', [ATag, I]));
      E.Tag    := ATag;
      E.Alive  := False;
      E.Pooled := True;
      Inc(FNextID);

      { Pool owns the entity from the start. }
      FPools[PoolIndex].Entities.Add(E);
   end;

   {$IFDEF DEBUG}
   Logger.Info(Format('[EntityManager] Pool "%s" preallocated: %d entities ready',
      [ATag, FPools[PoolIndex].Entities.Count]));
   {$ENDIF}
end;

{ ClearPool
  Empties the pool list for ATag. OwnsObjects=True so .Clear calls E.Free
  on each entity, releasing all components and entity memory. }
procedure TEntityManager.ClearPool(const ATag: string);
var
   PoolIndex: Integer;
begin
   PoolIndex := FindPool(ATag);
   if PoolIndex < 0 then Exit;
   FPools[PoolIndex].Entities.Clear;  { OwnsObjects=True → frees all pooled entities }
   {$IFDEF DEBUG}
   Logger.Info(Format('[EntityManager] Pool "%s" cleared', [ATag]));
   {$ENDIF}
end;

{ ClearAllPools
  Frees every pool list. Since each pool list has OwnsObjects=True, .Free
  releases all entities currently in that pool. FEntities is NOT touched here;
  its entities are freed when FEntities.Free is called in the destructor.
  The ownership invariant ensures no entity is freed twice. }
procedure TEntityManager.ClearAllPools;
var
   I: Integer;
begin
   for I := 0 to High(FPools) do
      FPools[I].Entities.Free;  { OwnsObjects=True → frees all pooled entity objects }
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
   I          : Integer;
   Pool       : ^TEntityPool;
   HitRate    : Single;
   TotalAccess: Int64;
begin
   if Length(FPools) = 0 then
   begin
      Logger.Info('[EntityManager] No pools configured');
      Exit;
   end;
   Logger.Info('=== Entity Pool Stats ===');
   for I := 0 to High(FPools) do
   begin
      Pool        := @FPools[I];
      TotalAccess := Pool^.HitCount + Pool^.MissCount;
      if TotalAccess > 0 then
         HitRate := (Pool^.HitCount / TotalAccess) * 100.0
      else
         HitRate := 0.0;
      Logger.Info(Format('Pool: "%s"',            [Pool^.Tag]));
      Logger.Info(Format('  Available (pooled): %d / %d',
         [Pool^.Entities.Count, Pool^.MaxSize]));
      Logger.Info(Format('  Hit Rate: %.1f%% (%d hits, %d misses)',
         [HitRate, Pool^.HitCount, Pool^.MissCount]));
      Logger.Info('');
   end;
   Logger.Info('=========================');
end;

function TEntityManager.GetPoolUtilization(const ATag: string): Single;
var
   PoolIndex: Integer;
begin
   Result    := 0.0;
   PoolIndex := FindPool(ATag);
   if PoolIndex < 0 then Exit;
   { In the new model, all entities in Pool^.Entities are by definition pooled.
     Utilization = pool list size as a fraction of the maximum capacity.
     0% = pool empty (all entities active or none created yet).
     100% = pool at max capacity (all pre-allocated entities available). }
   if FPools[PoolIndex].MaxSize > 0 then
      Result := (FPools[PoolIndex].Entities.Count / FPools[PoolIndex].MaxSize) * 100.0;
end;
{$ENDIF}

end.
