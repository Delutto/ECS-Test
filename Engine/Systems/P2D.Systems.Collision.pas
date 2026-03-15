unit P2D.Systems.Collision;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math,
   P2D.Common,
   P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.Events,
   P2D.Components.Transform, P2D.Components.RigidBody,
   P2D.Components.Collider, P2D.Components.TileMap;

type
   TCollisionSystem = class(TSystem2D)
   private
      FTileMapEntity : TEntity;
      FEntList       : array of TEntity;

      FTransformID: Integer;
      FColliderID: Integer;

      { ── Tile collision helpers ── }
      procedure SolveTileCollision(ATr: TTransformComponent; ARB: TRigidBodyComponent; ACol: TColliderComponent; AMap: TTileMapComponent; AMapTr: TTransformComponent);
      procedure SolveSolidTile(ATr: TTransformComponent; ARB: TRigidBodyComponent; const R: TRectF; const TileR: TRectF; AMap: TTileMapComponent; ACol: Integer; ARow: Integer);
      procedure SolveSemiTile(ATr: TTransformComponent; ARB: TRigidBodyComponent; const R: TRectF; const TileR: TRectF);

      { ── Entity-vs-entity overlap ── }
      procedure SolveEntityCollisions;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure FixedUpdate(AFixedDelta: Single); override;
   end;

implementation

uses
   P2D.Core.World;

{ ══════════════════════════════════════════════════════════════════════════════
  Constructor / Init
  ══════════════════════════════════════════════════════════════════════════════ }
constructor TCollisionSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 20;
   Name     := 'CollisionSystem';
end;

procedure TCollisionSystem.Init;
var
   E: TEntity;
begin
   inherited;

   RequireComponent(TColliderComponent);
   RequireComponent(TTransformComponent);

   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
   FColliderID := ComponentRegistry.GetComponentID(TColliderComponent);

   { Cache the first tilemap entity found in the world }
   FTileMapEntity := nil;
   for E in World.Entities.GetAll do
      if E.Alive and E.HasComponent(TTileMapComponent) then
      begin
         FTileMapEntity := E;
         Break;
      end;
end;

procedure TCollisionSystem.Update(ADelta: Single);
begin
   { Intentionally empty — all work is done in FixedUpdate }
end;

{ ══════════════════════════════════════════════════════════════════════════════
  FixedUpdate — drives both tile and entity collision each physics step
  ══════════════════════════════════════════════════════════════════════════════ }
procedure TCollisionSystem.FixedUpdate(AFixedDelta: Single);
var
   E    : TEntity;
   Tr   : TTransformComponent;
   RB   : TRigidBodyComponent;
   Col  : TColliderComponent;
   TileM: TTileMapComponent;
   MapTr: TTransformComponent;
begin
   TileM := nil;
   MapTr := nil;
   if Assigned(FTileMapEntity) then
   begin
      TileM := TTileMapComponent(FTileMapEntity.GetComponent(TTileMapComponent));
      MapTr := TTransformComponent(FTileMapEntity.GetComponent(TTransformComponent));
   end;

   if Assigned(TileM) then
      for E in GetMatchingEntities do
      begin
         if not E.HasComponent(TRigidBodyComponent) then
            Continue;

         Tr  := TTransformComponent(E.GetComponentByID(FTransformID));
         RB  := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
         Col := TColliderComponent(E.GetComponentByID(FColliderID));

         if Tr.Enabled and RB.Enabled and Col.Enabled then
            SolveTileCollision(Tr, RB, Col, TileM, MapTr);
      end;

   SolveEntityCollisions;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  SolveTileCollision
  Iterates only the tiles that the entity AABB overlaps, then dispatches
  each tile to SolveSolidTile or SolveSemiTile based on TileType.
  ══════════════════════════════════════════════════════════════════════════════ }
procedure TCollisionSystem.SolveTileCollision(ATr: TTransformComponent; ARB: TRigidBodyComponent; ACol: TColliderComponent; AMap: TTileMapComponent; AMapTr: TTransformComponent);
var
   R              : TRectF;
   ColL, ColR     : Integer;
   RowT, RowB     : Integer;
   C, Row         : Integer;
   Tile           : TTileData;
   TileR          : TRectF;
begin
   R := ACol.GetWorldRect(ATr.Position);

   { Compute the range of tile indices that overlap R }
   ColL := Trunc((R.X      - AMapTr.Position.X) / AMap.TileWidth);
   ColR := Trunc((R.Right  - AMapTr.Position.X) / AMap.TileWidth);
   RowT := Trunc((R.Y      - AMapTr.Position.Y) / AMap.TileHeight);
   RowB := Trunc((R.Bottom - AMapTr.Position.Y) / AMap.TileHeight);

   for Row := RowT to RowB do
   for C := ColL to ColR do
   begin
      Tile := AMap.GetTile(C, Row);

      { Skip completely empty tiles }
      if Tile.TileType = TILE_NONE then
         Continue;

      { Compute this tile's world AABB }
      TileR   := AMap.GetTileWorldRect(C, Row);
      TileR.X := TileR.X + AMapTr.Position.X;
      TileR.Y := TileR.Y + AMapTr.Position.Y;

      if not R.Overlaps(TileR) then
         Continue;

      case Tile.TileType of
         TILE_SOLID: SolveSolidTile(ATr, ARB, R, TileR, AMap, C, Row);

         TILE_SEMI: SolveSemiTile(ATr, ARB, R, TileR);
      end;

      { Update R after each resolution so subsequent tiles see the
        corrected position — same behaviour as the original code }
      R := ACol.GetWorldRect(ATr.Position);
   end;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  SolveSolidTile
  Full AABB push-out on whichever axis has the smaller overlap, with
  internal-edge suppression on the horizontal axis.
  ══════════════════════════════════════════════════════════════════════════════ }
procedure TCollisionSystem.SolveSolidTile(ATr: TTransformComponent; ARB: TRigidBodyComponent; const R: TRectF; const TileR: TRectF; AMap: TTileMapComponent; ACol: Integer; ARow: Integer);
var
   OverX, OverY     : Single;
   IsInternalEdgeX  : Boolean;
begin
   OverX := Min(R.Right,  TileR.Right)  - Max(R.X, TileR.X);
   OverY := Min(R.Bottom, TileR.Bottom) - Max(R.Y, TileR.Y);

   { Detect ghost horizontal collisions caused by internal seams between
   two adjacent solid tiles }
   IsInternalEdgeX := False;
   if OverX < OverY then
   begin
      if ATr.Position.X < TileR.X then
         IsInternalEdgeX := AMap.GetTile(ACol - 1, ARow).Solid
      else
         IsInternalEdgeX := AMap.GetTile(ACol + 1, ARow).Solid;
   end;

   if (OverX < OverY) and not IsInternalEdgeX then
   begin
      { ── Horizontal resolution ── }
      if ATr.Position.X < TileR.X then
         ATr.Position.X := ATr.Position.X - OverX
      else
         ATr.Position.X := ATr.Position.X + OverX;
      ARB.Velocity.X := 0;
      ARB.OnWall     := True;
   end
   else
   begin
      { ── Vertical resolution ── }
      if ATr.Position.Y < TileR.Y then
      begin
         { Entity is ABOVE the tile: push up, land }
         ATr.Position.Y := ATr.Position.Y - OverY;
         ARB.Grounded   := True;
         if ARB.Velocity.Y > 0 then
            ARB.Velocity.Y := 0;
      end
      else
      begin
         { Entity is BELOW the tile: push down, cancel upward velocity }
         ATr.Position.Y := ATr.Position.Y + OverY;
         if ARB.Velocity.Y < 0 then
            ARB.Velocity.Y := 0;
      end;
   end;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  SolveSemiTile  (one-way / pass-through platform)

  Rules for a semi-solid tile:
    1. Resolve ONLY vertically, never horizontally — the entity passes
       through from the sides and from below.
    2. Only block when the entity is falling DOWN onto the TOP surface:
         a. Vertical velocity must be >= 0 (moving down or still).
         b. The entity's feet (R.Bottom) in the PREVIOUS frame must be AT or ABOVE the tile's top edge.  We approximate this with:
            R.Bottom - OverY <= TileR.Y
            i.e. after pushing the entity up it would sit ON TOP of the tile,
            not embedded in the middle of it.
    3. When both conditions are met: push the entity up and set Grounded.
  ══════════════════════════════════════════════════════════════════════════════ }
procedure TCollisionSystem.SolveSemiTile(ATr: TTransformComponent; ARB: TRigidBodyComponent; const R: TRectF; const TileR: TRectF);
var
   OverY         : Single;
   FeetWereAbove : Boolean;
begin
   { Only handle the vertical (top-surface) case }
   if ARB.Velocity.Y < 0 then
      Exit; { Moving up → pass through }

   OverY := Min(R.Bottom, TileR.Bottom) - Max(R.Y, TileR.Y);

   { "Feet were above" heuristic:
    After the push-out the bottom of the entity would sit exactly on the
    tile top.  We accept this only when the penetration is shallow enough
    that the entity really was approaching from above rather than already
    being well inside the tile (which would mean it spawned or teleported
    inside it). }
   FeetWereAbove := (R.Bottom - OverY) <= TileR.Y;

   if not FeetWereAbove then
      Exit; { Entity is coming from below → pass through }

   { ── Land on top of the semi-solid ── }
   ATr.Position.Y := ATr.Position.Y - OverY;
   ARB.Grounded   := True;
   if ARB.Velocity.Y > 0 then
      ARB.Velocity.Y := 0;
end;

{ ══════════════════════════════════════════════════════════════════════════════
  SolveEntityCollisions — unchanged from original
  ══════════════════════════════════════════════════════════════════════════════ }
procedure TCollisionSystem.SolveEntityCollisions;
var
   Count: Integer;
   I, J : Integer;
   EA, EB: TEntity;
   TA, TB: TTransformComponent;
   CA, CB: TColliderComponent;
   RA, RB_: TRectF;
begin
   Count := GetMatchingEntities.Count;
   if Count < 2 then
      Exit;

   if Length(FEntList) < Count then
      SetLength(FEntList, Count);

   Count := 0;
   for EA in GetMatchingEntities do
   begin
      if not EA.Alive then
         Continue;
      FEntList[Count] := EA;
      Inc(Count);
   end;

   for I := 0 to Count - 2 do
   begin
      EA := FEntList[I];
      TA := TTransformComponent(EA.GetComponentByID(FTransformID));
      CA := TColliderComponent(EA.GetComponentByID(FColliderID));
      if not Assigned(TA) or not Assigned(CA) then
         Continue;
      RA := CA.GetWorldRect(TA.Position);

      for J := I + 1 to Count - 1 do
      begin
         EB  := FEntList[J];
         TB  := TTransformComponent(EB.GetComponentByID(FTransformID));
         CB  := TColliderComponent(EB.GetComponentByID(FColliderID));
         if not Assigned(TB) or not Assigned(CB) then
            Continue;
         RB_ := CB.GetWorldRect(TB.Position);

         if RA.Overlaps(RB_) then
         World.EventBus.Publish(TEntityOverlapEvent.Create(EA.ID, EB.ID, CA.Tag, CB.Tag, CA.IsTrigger, CB.IsTrigger));
      end;
   end;
end;

end.
