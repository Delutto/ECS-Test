unit P2D.Systems.Collision;

{$mode objfpc}
{$H+}

{ =============================================================================
  TCollisionSystem — expanded AABB tile + entity collision resolver.

  EXPANSIONS VS ORIGINAL
  ──────────────────────
  ① OnCeiling flag: SolveSolidTile now sets RB.OnCeiling := True and applies
    Restitution when the entity is pushed down from a tile above.

  ② Restitution on vertical tile collisions:
    Landing:   Velocity.Y := -Velocity.Y * RB.Restitution   (bounce up)
    Ceiling:   Velocity.Y :=  Abs(Velocity.Y) * RB.Restitution (bounce down)
    Restitution = 0 (default) → same as original (velocity zeroed).

  ③ Entity-vs-entity AABB push-apart (solid colliders only):
    When both colliders are non-trigger and at least one entity has a
    RigidBodyComponent, the system resolves the overlap on the minimum
    axis and distributes the push proportional to the inverse of each
    entity's mass (heavier entities move less).
    Trigger colliders still only publish TEntityOverlapEvent.

  ④ TILE_HAZARD support:
    Entities overlapping a TILE_HAZARD tile receive a TEntityHazardEvent
    published on the EventBus. Game systems subscribe and react (damage,
    death, bounce, etc.) without coupling to the collision code.

  UNCHANGED
  ─────────
  - Solid tile full push-out with internal-edge suppression.
  - Semi-solid one-way platform logic.
  - TEntityOverlapEvent publication for all overlapping entities.
  - Priority 20, runs after TPhysicsSystem (10).
  ============================================================================= }

interface

uses
   SysUtils,
   Math,
   P2D.Common,
   P2D.Core.ComponentRegistry,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.Events,
   P2D.Core.Event,
   P2D.Components.Transform,
   P2D.Components.RigidBody,
   P2D.Components.Collider,
   P2D.Components.TileMap;

{ ── New engine-level events published by TCollisionSystem ────────────────── }
type
   { Fired when an entity overlaps a TILE_HAZARD tile. }
   TEntityHazardEvent = class(TEvent2D)
   public
      EntityID: TEntityID;
      TileCol: Integer;
      TileRow: Integer;
      constructor Create(AEntityID: TEntityID; ACol, ARow: Integer);
   end;

   TCollisionSystem = class(TSystem2D)
   private
      FTileMapEntity: TEntity;
      FEntList: array of TEntity;
      FTransformID: Integer;
      FColliderID: Integer;
      FRigidBodyID: Integer;

      { ── Tile collision ── }
      procedure SolveTileCollision(ATr: TTransformComponent; ARB: TRigidBodyComponent; ACol: TColliderComponent; AMap: TTileMapComponent; AMapTr: TTransformComponent);
      procedure SolveSolidTile(ATr: TTransformComponent; ARB: TRigidBodyComponent; const R, TileR: TRectF; AMap: TTileMapComponent; ACol, ARow: Integer);
      procedure SolveSemiTile(ATr: TTransformComponent; ARB: TRigidBodyComponent; const R, TileR: TRectF);

      { ── Entity-vs-entity ── }
      procedure SolveEntityCollisions;
      procedure PushEntitiesApart(EA, EB: TEntity; TA, TB: TTransformComponent; CA, CB: TColliderComponent; const RA, RB_: TRectF);
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure FixedUpdate(AFixedDelta: Single); override;
   end;

implementation

uses
   P2D.Core.World;

{ TEntityHazardEvent }
constructor TEntityHazardEvent.Create(AEntityID: TEntityID; ACol, ARow: Integer);
begin
   inherited Create;

   EntityID := AEntityID;
   TileCol := ACol;
   TileRow := ARow;
end;

{ TCollisionSystem }

constructor TCollisionSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 20;
   Name := 'CollisionSystem';
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
   FRigidBodyID := ComponentRegistry.GetComponentID(TRigidBodyComponent);

   FTileMapEntity := nil;
   for E In World.Entities.GetAll do
   begin
      if E.Alive And E.HasComponent(TTileMapComponent) then
      begin
         FTileMapEntity := E;
         Break;
      end;
   end;
end;

procedure TCollisionSystem.Update(ADelta: Single);
begin

end;

procedure TCollisionSystem.FixedUpdate(AFixedDelta: Single);
var
   E: TEntity;
   Tr: TTransformComponent;
   RB: TRigidBodyComponent;
   Col: TColliderComponent;
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
   begin
      for E In GetMatchingEntities do
      begin
         RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
         if Not Assigned(RB) then
         begin
            Continue
         end;

         Tr := TTransformComponent(E.GetComponentByID(FTransformID));
         Col := TColliderComponent(E.GetComponentByID(FColliderID));

         if Not Assigned(Tr) Or Not Assigned(Col) then
         begin
            Continue
         end;
         if Not (Tr.Enabled And RB.Enabled And Col.Enabled) then
         begin
            Continue
         end;

         SolveTileCollision(Tr, RB, Col, TileM, MapTr);
      end;
   end;
   SolveEntityCollisions;
end;

{ ── SolveTileCollision ───────────────────────────────────────────────────── }
procedure TCollisionSystem.SolveTileCollision(ATr: TTransformComponent; ARB: TRigidBodyComponent; ACol: TColliderComponent; AMap: TTileMapComponent; AMapTr: TTransformComponent);
var
   R: TRectF;
   ColL, ColR: Integer;
   RowT, RowB: Integer;
   C, Row: Integer;
   Tile: TTileData;
   TileR: TRectF;
begin
   R := ACol.GetWorldRect(ATr.Position);

   ColL := Trunc((R.X - AMapTr.Position.X) / AMap.TileWidth);
   ColR := Trunc((R.Right - AMapTr.Position.X) / AMap.TileWidth);
   RowT := Trunc((R.Y - AMapTr.Position.Y) / AMap.TileHeight);
   RowB := Trunc((R.Bottom - AMapTr.Position.Y) / AMap.TileHeight);

   for Row := RowT to RowB do
   begin
      for C := ColL to ColR do
      begin
         Tile := AMap.GetTile(C, Row);
         if Tile.TileType = TILE_NONE then
         begin
            Continue
         end;

         TileR.X := AMapTr.Position.X + C * AMap.TileWidth;
         TileR.Y := AMapTr.Position.Y + Row * AMap.TileHeight;
         TileR.W := AMap.TileWidth;
         TileR.H := AMap.TileHeight;

         if Not R.Overlaps(TileR) then
         begin
            Continue
         end;

         case Tile.TileType of
            TILE_SOLID:
            begin
               SolveSolidTile(ATr, ARB, R, TileR, AMap, C, Row)
            end;
            TILE_SEMI:
            begin
               SolveSemiTile(ATr, ARB, R, TileR)
            end;
            TILE_HAZARD:
            begin
               World.EventBus.Publish(TEntityHazardEvent.Create(ATr.OwnerEntity, C, Row))
            end; { ④ Hazard tile: no geometric resolution — publish event only. }
         end;

         R := ACol.GetWorldRect(ATr.Position);
      end;
   end;
end;

{ ── SolveSolidTile ───────────────────────────────────────────────────────── }
procedure TCollisionSystem.SolveSolidTile(ATr: TTransformComponent; ARB: TRigidBodyComponent; const R, TileR: TRectF; AMap: TTileMapComponent; ACol, ARow: Integer);
var
   OverX, OverY: Single;
   InternalEdgeX: Boolean;
   Bounce: Single;
begin
   OverX := Min(R.Right, TileR.Right) - Max(R.X, TileR.X);
   OverY := Min(R.Bottom, TileR.Bottom) - Max(R.Y, TileR.Y);

   { Internal-edge suppression: skip horizontal push-out when the
   neighbouring tile in the push direction is also solid, preventing
   "ghost" horizontal hits along a solid floor or wall. }
   InternalEdgeX := False;
   if OverX < OverY then
   begin
      if ATr.Position.X < TileR.X then
      begin
         InternalEdgeX := AMap.GetTile(ACol - 1, ARow).Solid
      end
      else
      begin
         InternalEdgeX := AMap.GetTile(ACol + 1, ARow).Solid
      end;
   end;

   Bounce := Max(0, Min(1, ARB.Restitution));  { clamp to [0,1] }

   if (OverX < OverY) And Not InternalEdgeX then
   begin
      { ── Horizontal resolution ── }
      if ATr.Position.X < TileR.X then
      begin
         ATr.Position.X := ATr.Position.X - OverX
      end
      else
      begin
         ATr.Position.X := ATr.Position.X + OverX
      end;

      { Reflect horizontal velocity with restitution (0 = stop, 1 = mirror). }
      ARB.Velocity.X := -ARB.Velocity.X * Bounce;
      ARB.OnWall := True;
   end
   else
   begin
      { ── Vertical resolution ── }
      if ATr.Position.Y < TileR.Y then
      begin
         { Entity above the tile → push up (landing). }
         ATr.Position.Y := ATr.Position.Y - OverY;
         ARB.Grounded := True;
         { ① Bounce on landing: reflect upward with restitution. }
         if ARB.Velocity.Y > 0 then
         begin
            ARB.Velocity.Y := -ARB.Velocity.Y * Bounce
         end;
      end
      else
      begin
         { Entity below the tile → push down (ceiling hit). }
         ATr.Position.Y := ATr.Position.Y + OverY;
         ARB.OnCeiling := True;   { ① new flag }
         { ① Bounce off ceiling: reflect downward with restitution. }
         if ARB.Velocity.Y < 0 then
         begin
            ARB.Velocity.Y := Abs(ARB.Velocity.Y) * Bounce
         end;
      end;
   end;
end;

{ ── SolveSemiTile (unchanged) ────────────────────────────────────────────── }
procedure TCollisionSystem.SolveSemiTile(ATr: TTransformComponent; ARB: TRigidBodyComponent; const R, TileR: TRectF);
var
   OverY: Single;
   FeetWereAbove: Boolean;
begin
   if ARB.Velocity.Y < 0 then
   begin
      Exit
   end;

   OverY := Min(R.Bottom, TileR.Bottom) - Max(R.Y, TileR.Y);
   FeetWereAbove := (R.Bottom - OverY) <= TileR.Y;
   if Not FeetWereAbove then
   begin
      Exit
   end;

   ATr.Position.Y := ATr.Position.Y - OverY;
   ARB.Grounded := True;
   if ARB.Velocity.Y > 0 then
   begin
      ARB.Velocity.Y := 0
   end;
end;

{ ── SolveEntityCollisions ────────────────────────────────────────────────── }
procedure TCollisionSystem.SolveEntityCollisions;
var
   Count: Integer;
   I, J: Integer;
   EA, EB: TEntity;
   TA, TB: TTransformComponent;
   CA, CB: TColliderComponent;
   RA, RB_: TRectF;
begin
   Count := GetMatchingEntities.Count;
   if Count < 2 then
   begin
      Exit
   end;

   if Length(FEntList) < Count then
   begin
      SetLength(FEntList, Count)
   end;

   Count := 0;
   for EA In GetMatchingEntities do
   begin
      if Not EA.Alive then
      begin
         Continue
      end;
      FEntList[Count] := EA;
      Inc(Count);
   end;

   for I := 0 to Count - 2 do
   begin
      EA := FEntList[I];
      TA := TTransformComponent(EA.GetComponentByID(FTransformID));
      CA := TColliderComponent(EA.GetComponentByID(FColliderID));
      if Not Assigned(TA) Or Not Assigned(CA) then
      begin
         Continue
      end;
      RA := CA.GetWorldRect(TA.Position);

      for J := I + 1 to Count - 1 do
      begin
         EB := FEntList[J];
         TB := TTransformComponent(EB.GetComponentByID(FTransformID));
         CB := TColliderComponent(EB.GetComponentByID(FColliderID));
         if Not Assigned(TB) Or Not Assigned(CB) then
         begin
            Continue
         end;
         RB_ := CB.GetWorldRect(TB.Position);

         if Not RA.Overlaps(RB_) then
         begin
            Continue
         end;

         { Always publish overlap event (triggers and solids alike). }
         World.EventBus.Publish(TEntityOverlapEvent.Create(EA.ID, EB.ID, CA.Tag, CB.Tag, CA.IsTrigger, CB.IsTrigger));

         { ③ Physical push-apart: only when NEITHER collider is a trigger. }
         if Not CA.IsTrigger And Not CB.IsTrigger then
         begin
            PushEntitiesApart(EA, EB, TA, TB, CA, CB, RA, RB_)
         end;
      end;
   end;
end;

{ ── PushEntitiesApart ③ ──────────────────────────────────────────────────── }
procedure TCollisionSystem.PushEntitiesApart(EA, EB: TEntity; TA, TB: TTransformComponent; CA, CB: TColliderComponent; const RA, RB_: TRectF);
var
   OverX, OverY: Single;
   RBA, RBB: TRigidBodyComponent;
   MassA, MassB: Single;
   TotalMass: Single;
   RatioA, RatioB: Single;
   PushX, PushY: Single;
   HasA, HasB: Boolean;
begin
   OverX := Min(RA.Right, RB_.Right) - Max(RA.X, RB_.X);
   OverY := Min(RA.Bottom, RB_.Bottom) - Max(RA.Y, RB_.Y);

   RBA := TRigidBodyComponent(EA.GetComponentByID(FRigidBodyID));
   RBB := TRigidBodyComponent(EB.GetComponentByID(FRigidBodyID));
   HasA := Assigned(RBA) And RBA.Enabled;
   HasB := Assigned(RBB) And RBB.Enabled;

   { At least one entity must be dynamic. }
   if Not HasA And Not HasB then
   begin
      Exit
   end;

   { Mass-weighted push distribution:
   immovable entity → ratio 0 (no shift); other gets ratio 1 (full shift). }
   MassA := IfThen(HasA, Max(RBA.Mass, 0.001), 1e9);
   MassB := IfThen(HasB, Max(RBB.Mass, 0.001), 1e9);
   TotalMass := MassA + MassB;
   RatioA := MassB / TotalMass;   { A moves less if heavier }
   RatioB := MassA / TotalMass;

   if OverX < OverY then
   begin
      { ── Horizontal separation ── }
      if RA.X < RB_.X then
      begin
         PushX := OverX;
         if HasA then
         begin
            TA.Position.X := TA.Position.X - PushX * RatioA
         end;
         if HasB then
         begin
            TB.Position.X := TB.Position.X + PushX * RatioB
         end;
      end
      else
      begin
         PushX := OverX;
         if HasA then
         begin
            TA.Position.X := TA.Position.X + PushX * RatioA
         end;
         if HasB then
         begin
            TB.Position.X := TB.Position.X - PushX * RatioB
         end;
      end;
      { Cancel horizontal velocity of both on the collision axis. }
      if HasA then
      begin
         RBA.Velocity.X := 0
      end;
      if HasB then
      begin
         RBB.Velocity.X := 0
      end;
   end
   else
   begin
      { ── Vertical separation ── }
      if RA.Y < RB_.Y then
      begin
         PushY := OverY;
         if HasA then
         begin
            TA.Position.Y := TA.Position.Y - PushY * RatioA
         end;
         if HasB then
         begin
            TB.Position.Y := TB.Position.Y + PushY * RatioB
         end;
      end
      else
      begin
         PushY := OverY;
         if HasA then
         begin
            TA.Position.Y := TA.Position.Y + PushY * RatioA
         end;
         if HasB then
         begin
            TB.Position.Y := TB.Position.Y - PushY * RatioB
         end;
      end;
      if HasA then
      begin
         RBA.Velocity.Y := 0
      end;
      if HasB then
      begin
         RBB.Velocity.Y := 0
      end;
   end;
end;

end.
