unit P2D.Core.EntityPool;

{$mode ObjFPC}{$H+}

interface

uses
   Classes, SysUtils, fgl,
   P2D.Core.Types, P2D.Core.Entity, P2D.Core.World;

type
   {---------------------------------------------------------------------------
   TPooledEntity
   ---------------------------------------------------------------------------
   Entidade que pode ser pooled. Adiciona funcionalidade de reset.
   ---------------------------------------------------------------------------}
   TPooledEntity = class(TEntity)
   private
      FInPool: Boolean;
      FPoolIndex: Integer;
   public
      procedure Reset; virtual;
      procedure OnAcquire; virtual;
      procedure OnRelease; virtual;

      property InPool: Boolean read FInPool write FInPool;
      property PoolIndex: Integer read FPoolIndex write FPoolIndex;
   end;

   {---------------------------------------------------------------------------
   TEntityPool
   ---------------------------------------------------------------------------
   Pool de entidades pré-alocadas para evitar alocação/liberação constante.
   Ideal para projéteis, partículas, efeitos temporários, etc.
   ---------------------------------------------------------------------------}
   TEntityPool = class
   private
      FWorld: TWorld;
      FPool: array of TPooledEntity;
      FPoolSize: Integer;
      FActiveCount: Integer;
      FAutoGrow: Boolean;
      FMaxSize: Integer;
      FName: string;

      { Estatísticas }
      FTotalAcquired: Int64;
      FTotalReleased: Int64;
      FGrowCount: Integer;
      FPeakUsage: Integer;

      function CreatePooledEntity: TPooledEntity;
      procedure GrowPool;

   public
      constructor Create(AWorld: TWorld; const AName: string;
                        AInitialSize: Integer; AMaxSize: Integer = 1000);
      destructor Destroy; override;

      function Acquire: TPooledEntity;
      procedure Release(AEntity: TPooledEntity);
      procedure ReleaseAll;

      procedure Clear;
      function GetActiveEntities: TArray<TPooledEntity>;

      { Estatísticas }
      procedure PrintStats;
      function GetUtilization: Single;

      property PoolSize: Integer read FPoolSize;
      property ActiveCount: Integer read FActiveCount;
      property AutoGrow: Boolean read FAutoGrow write FAutoGrow;
      property MaxSize: Integer read FMaxSize write FMaxSize;
      property Name: string read FName;
   end;

   {---------------------------------------------------------------------------
   TEntityPoolManager
   ---------------------------------------------------------------------------
   Gerencia múltiplos pools de entidades.
   Singleton para acesso global.
   ---------------------------------------------------------------------------}
   TEntityPoolManager = class
   private
      FPools: TStringList; // Nome -> TEntityPool
      class var FInstance: TEntityPoolManager;

      constructor Create;

   public
      destructor Destroy; override;

      class function Instance: TEntityPoolManager;
      class procedure FreeInstance;

      function CreatePool(AWorld: TWorld; const AName: string;
                         AInitialSize: Integer; AMaxSize: Integer = 1000): TEntityPool;
      function GetPool(const AName: string): TEntityPool;
      procedure RemovePool(const AName: string);

      procedure PrintAllStats;
      procedure ReleaseAll;

      property Pools: TStringList read FPools;
   end;

implementation

uses
   P2D.Utils.Logger, Math;

{ TPooledEntity }

procedure TPooledEntity.Reset;
var
   I: Integer;
begin
   // Remove todos os componentes
   // Nota: Não libera a entidade, apenas reseta para estado inicial

   {$IFDEF DEBUG}
   Logger.Debug(Format('[PooledEntity %d] Reset called', [ID]));
   {$ENDIF}

   // Desabilita todos os componentes sem removê-los
   // Sistemas concretos podem sobrescrever Reset para comportamento específico

   FAlive := False;
   FInPool := True;
end;

procedure TPooledEntity.OnAcquire;
begin
   FAlive := True;
   FInPool := False;

   {$IFDEF DEBUG}
   Logger.Debug(Format('[PooledEntity %d] Acquired from pool', [ID]));
   {$ENDIF}
end;

procedure TPooledEntity.OnRelease;
begin
   Reset;

   {$IFDEF DEBUG}
   Logger.Debug(Format('[PooledEntity %d] Released to pool', [ID]));
   {$ENDIF}
end;

{ TEntityPool }

constructor TEntityPool.Create(AWorld: TWorld; const AName: string;
                               AInitialSize: Integer; AMaxSize: Integer);
var
   I: Integer;
begin
   inherited Create;

   FWorld := AWorld;
   FName := AName;
   FPoolSize := 0;
   FActiveCount := 0;
   FAutoGrow := True;
   FMaxSize := AMaxSize;

   FTotalAcquired := 0;
   FTotalReleased := 0;
   FGrowCount := 0;
   FPeakUsage := 0;

   SetLength(FPool, AInitialSize);

   // Pré-aloca entidades
   for I := 0 to AInitialSize - 1 do
   begin
      FPool[I] := CreatePooledEntity;
      FPool[I].PoolIndex := I;
      Inc(FPoolSize);
   end;

   Logger.Info(Format('[EntityPool "%s"] Created with %d entities (Max: %d)',
                     [FName, AInitialSize, AMaxSize]));
end;

destructor TEntityPool.Destroy;
var
   I: Integer;
begin
   {$IFDEF DEBUG}
   Logger.Info(Format('[EntityPool "%s"] Destroying', [FName]));
   PrintStats;
   {$ENDIF}

   // Libera todas as entidades do pool
   for I := 0 to FPoolSize - 1 do
   begin
      if Assigned(FPool[I]) then
         FPool[I].Free;
   end;

   SetLength(FPool, 0);

   Logger.Info(Format('[EntityPool "%s"] Destroyed', [FName]));

   inherited;
end;

function TEntityPool.CreatePooledEntity: TPooledEntity;
begin
   // Cria entidade através do world para obter ID válido
   Result := TPooledEntity.Create(0, FName); // ID temporário
   Result.InPool := True;
   Result.Alive := False;
end;

procedure TEntityPool.GrowPool;
var
   OldSize, NewSize, I: Integer;
   GrowAmount: Integer;
begin
   if not FAutoGrow then
   begin
      Logger.Warn(Format('[EntityPool "%s"] Pool exhausted and AutoGrow is disabled', [FName]));
      Exit;
   end;

   OldSize := FPoolSize;

   // Cresce 50% ou pelo menos 10 entidades
   GrowAmount := Max(FPoolSize div 2, 10);
   NewSize := Min(OldSize + GrowAmount, FMaxSize);

   if NewSize <= OldSize then
   begin
      Logger.Error(Format('[EntityPool "%s"] Cannot grow: reached max size %d',
                         [FName, FMaxSize]));
      Exit;
   end;

   SetLength(FPool, NewSize);

   // Cria novas entidades
   for I := OldSize to NewSize - 1 do
   begin
      FPool[I] := CreatePooledEntity;
      FPool[I].PoolIndex := I;
      Inc(FPoolSize);
   end;

   Inc(FGrowCount);

   Logger.Info(Format('[EntityPool "%s"] Grew from %d to %d entities (Growth #%d)',
                     [FName, OldSize, NewSize, FGrowCount]));
end;

function TEntityPool.Acquire: TPooledEntity;
var
   I: Integer;
begin
   Result := nil;

   // Procura entidade disponível no pool
   for I := 0 to FPoolSize - 1 do
   begin
      if FPool[I].InPool then
      begin
         Result := FPool[I];
         Result.OnAcquire;
         Inc(FActiveCount);
         Inc(FTotalAcquired);

         // Atualiza pico de uso
         if FActiveCount > FPeakUsage then
            FPeakUsage := FActiveCount;

         {$IFDEF DEBUG}
         Logger.Debug(Format('[EntityPool "%s"] Entity acquired (Active: %d/%d)',
                            [FName, FActiveCount, FPoolSize]));
         {$ENDIF}

         Exit;
      end;
   end;

   // Pool esgotado - tenta crescer
   if FActiveCount >= FPoolSize then
   begin
      Logger.Warn(Format('[EntityPool "%s"] Pool exhausted (%d/%d)',
                        [FName, FActiveCount, FPoolSize]));
      GrowPool;

      // Tenta novamente após crescer
      if FPoolSize > FActiveCount then
         Result := Acquire;
   end;
end;

procedure TEntityPool.Release(AEntity: TPooledEntity);
begin
   if not Assigned(AEntity) then
   begin
      Logger.Warn(Format('[EntityPool "%s"] Attempted to release nil entity', [FName]));
      Exit;
   end;

   if AEntity.InPool then
   begin
      Logger.Warn(Format('[EntityPool "%s"] Entity %d already in pool',
                        [FName, AEntity.ID]));
      Exit;
   end;

   AEntity.OnRelease;
   Dec(FActiveCount);
   Inc(FTotalReleased);

   {$IFDEF DEBUG}
   Logger.Debug(Format('[EntityPool "%s"] Entity released (Active: %d/%d)',
                      [FName, FActiveCount, FPoolSize]));
   {$ENDIF}
end;

procedure TEntityPool.ReleaseAll;
var
   I: Integer;
begin
   for I := 0 to FPoolSize - 1 do
   begin
      if not FPool[I].InPool then
         Release(FPool[I]);
   end;

   Logger.Info(Format('[EntityPool "%s"] All entities released', [FName]));
end;

procedure TEntityPool.Clear;
begin
   ReleaseAll;
   FActiveCount := 0;

   Logger.Info(Format('[EntityPool "%s"] Cleared', [FName]));
end;

function TEntityPool.GetActiveEntities: TArray<TPooledEntity>;
var
   I, Index: Integer;
begin
   SetLength(Result, FActiveCount);
   Index := 0;

   for I := 0 to FPoolSize - 1 do
   begin
      if not FPool[I].InPool then
      begin
         Result[Index] := FPool[I];
         Inc(Index);
      end;
   end;
end;

procedure TEntityPool.PrintStats;
var
   Utilization: Single;
begin
   Utilization := GetUtilization;

   Logger.Info(Format('=== EntityPool "%s" Stats ===', [FName]));
   Logger.Info(Format('  Pool Size: %d', [FPoolSize]));
   Logger.Info(Format('  Active: %d', [FActiveCount]));
   Logger.Info(Format('  Available: %d', [FPoolSize - FActiveCount]));
   Logger.Info(Format('  Utilization: %.1f%%', [Utilization]));
   Logger.Info(Format('  Peak Usage: %d', [FPeakUsage]));
   Logger.Info(Format('  Total Acquired: %d', [FTotalAcquired]));
   Logger.Info(Format('  Total Released: %d', [FTotalReleased]));
   Logger.Info(Format('  Growth Count: %d', [FGrowCount]));
   Logger.Info(Format('  Max Size: %d', [FMaxSize]));
   Logger.Info('==============================');
end;

function TEntityPool.GetUtilization: Single;
begin
   if FPoolSize > 0 then
      Result := (FActiveCount / FPoolSize) * 100.0
   else
      Result := 0.0;
end;

{ TEntityPoolManager }

constructor TEntityPoolManager.Create;
begin
   inherited Create;

   FPools := TStringList.Create;
   FPools.Sorted := True;
   FPools.OwnsObjects := True; // Automaticamente libera os pools

   Logger.Info('[EntityPoolManager] Created');
end;

destructor TEntityPoolManager.Destroy;
begin
   {$IFDEF DEBUG}
   Logger.Info('[EntityPoolManager] Destroying');
   PrintAllStats;
   {$ENDIF}

   FPools.Free;

   Logger.Info('[EntityPoolManager] Destroyed');

   inherited;
end;

class function TEntityPoolManager.Instance: TEntityPoolManager;
begin
   if FInstance = nil then
      FInstance := TEntityPoolManager.Create;
   Result := FInstance;
end;

class procedure TEntityPoolManager.FreeInstance;
begin
   FreeAndNil(FInstance);
end;

function TEntityPoolManager.CreatePool(AWorld: TWorld; const AName: string;
                                       AInitialSize: Integer; AMaxSize: Integer): TEntityPool;
var
   Index: Integer;
begin
   Index := FPools.IndexOf(AName);

   if Index >= 0 then
   begin
      Logger.Warn(Format('[EntityPoolManager] Pool "%s" already exists', [AName]));
      Result := TEntityPool(FPools.Objects[Index]);
      Exit;
   end;

   Result := TEntityPool.Create(AWorld, AName, AInitialSize, AMaxSize);
   FPools.AddObject(AName, Result);

   Logger.Info(Format('[EntityPoolManager] Pool "%s" created', [AName]));
end;

function TEntityPoolManager.GetPool(const AName: string): TEntityPool;
var
   Index: Integer;
begin
   Result := nil;
   Index := FPools.IndexOf(AName);

   if Index >= 0 then
      Result := TEntityPool(FPools.Objects[Index])
   else
      Logger.Warn(Format('[EntityPoolManager] Pool "%s" not found', [AName]));
end;

procedure TEntityPoolManager.RemovePool(const AName: string);
var
   Index: Integer;
begin
   Index := FPools.IndexOf(AName);

   if Index >= 0 then
   begin
      FPools.Delete(Index); // Libera automaticamente (OwnsObjects=True)
      Logger.Info(Format('[EntityPoolManager] Pool "%s" removed', [AName]));
   end
   else
      Logger.Warn(Format('[EntityPoolManager] Pool "%s" not found for removal', [AName]));
end;

procedure TEntityPoolManager.PrintAllStats;
var
   I: Integer;
   Pool: TEntityPool;
begin
   Logger.Info('=== ALL ENTITY POOLS STATS ===');
   Logger.Info(Format('Total Pools: %d', [FPools.Count]));
   Logger.Info('');

   for I := 0 to FPools.Count - 1 do
   begin
      Pool := TEntityPool(FPools.Objects[I]);
      Pool.PrintStats;
      Logger.Info('');
   end;

   Logger.Info('==============================');
end;

procedure TEntityPoolManager.ReleaseAll;
var
   I: Integer;
   Pool: TEntityPool;
begin
   for I := 0 to FPools.Count - 1 do
   begin
      Pool := TEntityPool(FPools.Objects[I]);
      Pool.ReleaseAll;
   end;

   Logger.Info('[EntityPoolManager] All pools released');
end;

initialization

finalization
   TEntityPoolManager.FreeInstance;

end.
