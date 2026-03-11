unit P2D.Core.ObjectPool;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fgl;

type
   { TP2DPoolableObject }
   TP2DPoolableObject = class
   private
      FActive: Boolean;
      FPooled: Boolean;
   public
      procedure Reset; virtual;
      procedure OnAcquire; virtual;
      procedure OnRelease; virtual;
      property Active: Boolean read FActive write FActive;
      property Pooled: Boolean read FPooled write FPooled;
   end;

   { TP2DObjectPool }
   generic TP2DObjectPool<T: TP2DPoolableObject> = class
   private
      type
      TObjectList = specialize TFPGObjectList<T>;
   private
      FPool: TObjectList;
      FMaxSize: Integer;
      FAutoGrow: Boolean;
      FGrowthFactor: Single;
      FCreateFunc: function: T of object;
   public
      constructor Create(AInitialSize: Integer; AMaxSize: Integer; ACreateFunc: function: T of object);
      destructor Destroy; override;

      function Acquire: T;
      procedure Release(AObject: T);
      procedure Clear;
      procedure Preallocate(ACount: Integer);

      property MaxSize: Integer read FMaxSize write FMaxSize;
      property AutoGrow: Boolean read FAutoGrow write FAutoGrow;
      property GrowthFactor: Single read FGrowthFactor write FGrowthFactor;
      property PoolSize: Integer read FPool.Count;
   end;

implementation

uses
   P2D.Utils.Logger, Math;

{ TP2DPoolableObject }

procedure TP2DPoolableObject.Reset;
begin
   FActive := False;
   FPooled := True;
end;

procedure TP2DPoolableObject.OnAcquire;
begin
   FActive := True;
   FPooled := False;
end;

procedure TP2DPoolableObject.OnRelease;
begin
   Reset;
end;

{ TP2DObjectPool }

constructor TP2DObjectPool.Create(AInitialSize: Integer; AMaxSize: Integer; ACreateFunc: function: T of object);
begin
   inherited Create;

   FPool := TObjectList.Create(True);
   FMaxSize := AMaxSize;
   FAutoGrow := True;
   FGrowthFactor := 1.5;
   FCreateFunc := ACreateFunc;

   Preallocate(AInitialSize);
   TP2DLogger.Info(Format('Object pool created (Initial: %d, Max: %d)', [AInitialSize, AMaxSize]));
end;

destructor TP2DObjectPool.Destroy;
begin
   Clear;
   FPool.Free;
   TP2DLogger.Info('Object pool destroyed');

   inherited;
end;

function TP2DObjectPool.Acquire: T;
var
   i: Integer;
   NewObj: T;
begin
   Result := nil;

   // Procura objeto disponível no pool
   for i := 0 to FPool.Count - 1 do
   begin
      if FPool[i].Pooled then
      begin
         Result := FPool[i];
         Result.OnAcquire;
         Exit;
      end;
   end;

   // Se não encontrou, cria novo objeto
   if FAutoGrow and (FPool.Count < FMaxSize) then
   begin
      NewObj := FCreateFunc();
      if Assigned(NewObj) then
      begin
         FPool.Add(NewObj);
         NewObj.OnAcquire;
         Result := NewObj;
         Logger.Debug(Format('Pool grew to %d objects', [FPool.Count]));
      end;
   end
   else
   Logger.Warning('Object pool exhausted!');
end;

procedure TP2DObjectPool.Release(AObject: T);
var
   Index: Integer;
begin
   if not Assigned(AObject) then
      Exit;

   Index := FPool.IndexOf(AObject);
   if Index >= 0 then
      AObject.OnRelease
   else
      Logger.Warning('Trying to release object not in pool');
end;

procedure TP2DObjectPool.Clear;
begin
   FPool.Clear;
   Logger.Info('Object pool cleared');
end;

procedure TP2DObjectPool.Preallocate(ACount: Integer);
var
   i: Integer;
   Obj: T;
   TargetCount: Integer;
begin
   TargetCount := Min(ACount, FMaxSize);

   for i := FPool.Count to TargetCount - 1 do
   begin
      Obj := FCreateFunc();
      if Assigned(Obj) then
      begin
         Obj.Reset;
         FPool.Add(Obj);
      end;
   end;

   Logger.Info(Format('Pool preallocated %d objects', [FPool.Count]));
end;

end.
