unit P2D.Systems.Collision;

{$mode objfpc}{$H+}

interface
uses
	SysUtils, Math,
     P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
     P2D.Components.Transform, P2D.Components.RigidBody,
     P2D.Components.Collider, P2D.Components.TileMap, P2D.Components.Tags;
	 
type
  TCollisionSystem = class(TSystem2D)
  private
    procedure SolveTileCollision(ATr: TTransformComponent; ARB: TRigidBodyComponent;
      ACol: TColliderComponent; AMap: TTileMapComponent; AMapTr: TTransformComponent);
    procedure SolveEntityCollisions;
  public
    constructor Create(AWorld: TWorld); override;
    procedure Update(ADelta: Single); override;
  end;
implementation

constructor TCollisionSystem.Create(AWorld: TWorld);
begin
	inherited Create(AWorld); Priority:=20; Name:='CollisionSystem';
end;

procedure TCollisionSystem.SolveTileCollision(ATr: TTransformComponent; ARB: TRigidBodyComponent; ACol: TColliderComponent; AMap: TTileMapComponent; AMapTr: TTransformComponent);
var
   R: TRectF; ColL,ColR,RowT,RowB,C,Row: Integer;
   Tile: TTileData; TileR: TRectF; OverX,OverY: Single;
begin
  R:=ACol.GetWorldRect(ATr.Position);
  ColL:=Trunc((R.X-AMapTr.Position.X)/AMap.TileWidth);
  ColR:=Trunc((R.Right-AMapTr.Position.X-1)/AMap.TileWidth);
  RowT:=Trunc((R.Y-AMapTr.Position.Y)/AMap.TileHeight);
  RowB:=Trunc((R.Bottom-AMapTr.Position.Y-1)/AMap.TileHeight);
  for Row:=RowT to RowB do
    for C:=ColL to ColR do
	begin
      Tile:=AMap.GetTile(C,Row);
      if not Tile.Solid then
		Continue;
      TileR:=AMap.GetTileWorldRect(C,Row);
      TileR.X:=TileR.X+AMapTr.Position.X; TileR.Y:=TileR.Y+AMapTr.Position.Y;
      if not R.Overlaps(TileR) then
		Continue;
      OverX:=Min(R.Right,TileR.Right)-Max(R.X,TileR.X);
      OverY:=Min(R.Bottom,TileR.Bottom)-Max(R.Y,TileR.Y);
      if OverX<OverY then
	  begin
        if ATr.Position.X<TileR.X then
			ATr.Position.X:=ATr.Position.X-OverX
        else
			ATr.Position.X:=ATr.Position.X+OverX;
        ARB.Velocity.X:=0;
      end
	  else
	  begin
        if ATr.Position.Y<TileR.Y then
		begin
          ATr.Position.Y:=ATr.Position.Y-OverY; ARB.Grounded:=True;
          if ARB.Velocity.Y>0 then
			ARB.Velocity.Y:=0;
        end
		else
		begin
          ATr.Position.Y:=ATr.Position.Y+OverY;
          if ARB.Velocity.Y<0 then
			ARB.Velocity.Y:=0;
        end;
      end;
      R:=ACol.GetWorldRect(ATr.Position);
    end;
end;

procedure TCollisionSystem.SolveEntityCollisions;
var
   EA,EB: TEntity; TA,TB: TTransformComponent; CA,CB: TColliderComponent;
   RA,RB_: TRectF; PlayerComp: TPlayerComponent;
   EntList: array of TEntity; I,J,Count: Integer;
begin
  Count:=0; SetLength(EntList,World.Entities.GetAll.Count);
  for EA in World.Entities.GetAll do
    if EA.Alive and EA.HasComponent(TColliderComponent) and EA.HasComponent(TTransformComponent) then
    begin
	   EntList[Count]:=EA; Inc(Count);
	end;
  for I:=0 to Count-2 do
    for J:=I+1 to Count-1 do
	begin
      EA:=EntList[I]; EB:=EntList[J];
      TA:=TTransformComponent(EA.GetComponent(TTransformComponent));
      TB:=TTransformComponent(EB.GetComponent(TTransformComponent));
      CA:=TColliderComponent(EA.GetComponent(TColliderComponent));
      CB:=TColliderComponent(EB.GetComponent(TColliderComponent));
      RA:=CA.GetWorldRect(TA.Position); RB_:=CB.GetWorldRect(TB.Position);
      if not RA.Overlaps(RB_) then
		Continue;
      if(CA.Tag=ctPlayer)and(CB.Tag=ctCoin) then
	  begin
        if EA.HasComponent(TPlayerComponent) then
		begin
          PlayerComp:=TPlayerComponent(EA.GetComponent(TPlayerComponent));
          Inc(PlayerComp.Coins); PlayerComp.Score:=PlayerComp.Score+200;
        end;
		World.DestroyEntity(EB.ID);
      end
	  else
      if(CA.Tag=ctCoin)and(CB.Tag=ctPlayer) then
	  begin
        if EB.HasComponent(TPlayerComponent) then
		begin
          PlayerComp:=TPlayerComponent(EB.GetComponent(TPlayerComponent));
          Inc(PlayerComp.Coins); PlayerComp.Score:=PlayerComp.Score+200;
        end;
		World.DestroyEntity(EA.ID);
      end;
      if(CA.Tag=ctPlayer)and(CB.Tag=ctEnemy) then
	  begin
        if EA.HasComponent(TPlayerComponent) then
		begin
          PlayerComp:=TPlayerComponent(EA.GetComponent(TPlayerComponent));
          if PlayerComp.InvFrames<=0 then
		  begin
            PlayerComp.Score:=PlayerComp.Score-100; PlayerComp.InvFrames:=2;
          end;
        end;
      end;
    end;
end;

procedure TCollisionSystem.Update(ADelta: Single);
var
	E,MapE: TEntity;
	Tr: TTransformComponent;
	RB: TRigidBodyComponent;
    Col: TColliderComponent;
	TileM: TTileMapComponent;
	MapTr: TTransformComponent;
begin
  TileM:=nil;
  MapTr:=nil;
  for MapE in World.Entities.GetAll do
    if MapE.Alive and MapE.HasComponent(TTileMapComponent) then
	begin
      TileM:=TTileMapComponent(MapE.GetComponent(TTileMapComponent));
      MapTr:=TTransformComponent(MapE.GetComponent(TTransformComponent)); Break;
    end;
  if Assigned(TileM) then
    for E in World.Entities.GetAll do
	begin
      if not E.Alive then Continue;
      if not E.HasComponent(TTransformComponent) then
		Continue;
      if not E.HasComponent(TRigidBodyComponent)  then
		Continue;
      if not E.HasComponent(TColliderComponent)   then
		Continue;
      Tr:=TTransformComponent(E.GetComponent(TTransformComponent));
      RB:=TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
      Col:=TColliderComponent(E.GetComponent(TColliderComponent));
      if Tr.Enabled and RB.Enabled and Col.Enabled then
        SolveTileCollision(Tr,RB,Col,TileM,MapTr);
    end;
  SolveEntityCollisions;
end;
end.