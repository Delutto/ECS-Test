unit P2D.Core.Entity;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, fgl, P2D.Core.Types, P2D.Core.Component;

type
   { -------------------------------------------------------------------------
   Component storage per entity: maps component-class to component instance
   -------------------------------------------------------------------------}
   TComponentMap = specialize TFPGMap<Pointer, TComponent2D>;

   TEntity = class
   private
      FID        : TEntityID;
      FName      : string;
      FAlive     : Boolean;
      FComponents: TComponentMap;
   public
      constructor Create(AID: TEntityID; const AName: string = '');
      destructor  Destroy; override;

      function  AddComponent(AComp: TComponent2D): TComponent2D;
      function  GetComponent(AClass: TComponent2DClass): TComponent2D;
      function  HasComponent(AClass: TComponent2DClass): Boolean;
      procedure RemoveComponent(AClass: TComponent2DClass);

      property ID    : TEntityID read FID;
      property Name  : string    read FName  write FName;
      property Alive : Boolean   read FAlive write FAlive;
   end;

   { -------------------------------------------------------------------------
   Entity manager – creates, destroys and stores all entities in the world
   -------------------------------------------------------------------------}
   TEntityList = specialize TFPGObjectList<TEntity>;
   TEntityMap = specialize TFPGMap<TEntityID, TEntity>;

   TEntityManager = class
   private
      FEntities : TEntityList;  // Lista para iteração
      FEntityMap: TEntityMap;   // Mapa para lookup rápido
      FNextID   : TEntityID;
   public
      constructor Create;
      destructor  Destroy; override;

      function  CreateEntity(const AName: string = ''): TEntity;
      procedure DestroyEntity(AID: TEntityID);
      function  GetEntity(AID: TEntityID): TEntity;
      function  GetAll: TEntityList;
      procedure PurgeDestroyed;
   end;

implementation

{ TEntity }
constructor TEntity.Create(AID: TEntityID; const AName: string);
begin
   inherited Create;

   FID         := AID;
   FName       := AName;
   FAlive      := True;
   FComponents := TComponentMap.Create;
   FComponents.Sorted := True;
end;

destructor TEntity.Destroy;
var
  I: Integer;
begin
   for I := 0 to FComponents.Count - 1 do
      FComponents.Data[I].Free;
   FComponents.Free;

   inherited;
end;

function TEntity.AddComponent(AComp: TComponent2D): TComponent2D;
var
   Idx: Integer;
begin
   AComp.OwnerEntity := FID;
   Idx := FComponents.IndexOf(Pointer(AComp.ClassType));
   if Idx >= 0 then
      FComponents.Data[Idx].Free;
   FComponents[Pointer(AComp.ClassType)] := AComp;
   Result := AComp;
end;

function TEntity.GetComponent(AClass: TComponent2DClass): TComponent2D;
var
  Idx: Integer;
begin
   Result := nil;
   Idx := FComponents.IndexOf(Pointer(AClass));
   if Idx >= 0 then
      Result := FComponents.Data[Idx];
end;

function TEntity.HasComponent(AClass: TComponent2DClass): Boolean;
begin
   Result := FComponents.IndexOf(Pointer(AClass)) >= 0;
end;

procedure TEntity.RemoveComponent(AClass: TComponent2DClass);
var
   Idx: Integer;
begin
   Idx := FComponents.IndexOf(Pointer(AClass));
   if Idx >= 0 then
   begin
      FComponents.Data[Idx].Free;
      FComponents.Delete(Idx);
   end;
end;

{ TEntityManager }
constructor TEntityManager.Create;
begin
   inherited Create;

   FEntities := TEntityList.Create(True);  { OwnsObjects=True: libera TEntity ao deletar }
   FEntityMap := TEntityMap.Create;        { Instancia o mapa }
   FEntityMap.Sorted := True;
   FNextID := 1;
end;

destructor TEntityManager.Destroy;
begin
   FEntities.Free; { Libera todas as entidades }
   FEntityMap.Free; { Libera o mapa (não-proprietário: só o mapa, não as entidades) }

   inherited;
end;

function TEntityManager.CreateEntity(const AName: string): TEntity;
begin
   Result := TEntity.Create(FNextID, AName);
   FEntities.Add(Result);
   FEntityMap[FNextID] := Result; { Registro no mapa para lookup rápido }
   Inc(FNextID);
end;

procedure TEntityManager.DestroyEntity(AID: TEntityID);
var
   E: TEntity;
begin
   E := GetEntity(AID);
   if Assigned(E) then
      E.Alive := False;
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
  I  : Integer;
  AID: TEntityID;
  Idx: Integer;
begin
   { Percorre de trás para frente para deletar com segurança. Antes de remover de FEntities, remove a entrada de FEntityMap para evitar dangling pointers. }
   for I := FEntities.Count - 1 downto 0 do
      if not FEntities[I].Alive then
      begin
         AID := FEntities[I].ID;

         { Remove do mapa de lookup ANTES de liberar o objeto. }
         Idx := FEntityMap.IndexOf(AID);
         if Idx >= 0 then
            FEntityMap.Delete(Idx);

         { FEntities.Delete libera o TEntity (OwnsObjects=True). }
         FEntities.Delete(I);
      end;
end;

end.
