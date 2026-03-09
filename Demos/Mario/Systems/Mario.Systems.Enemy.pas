unit Mario.Systems.Enemy;
{$mode objfpc}{$H+}

interface

uses
   SysUtils, raylib,
   P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Components.Transform, P2D.Components.RigidBody, P2D.Core.Component,
   P2D.Components.Sprite, P2D.Components.Tags, P2D.Utils.Math,
   Mario.Common;

type
   TGoombaComponent = class(TComponent2D)
   public
      Speed        : Single;
      Direction    : Single;  // -1 = left,  +1 = right
      WallCooldown : Single;  // seconds remaining before another wall-flip is allowed
      constructor Create; override;
   end;

   TEnemySystem = class(TSystem2D)
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
   end;

implementation

uses
   Mario.Systems.Player;

{ TGoombaComponent }

constructor TGoombaComponent.Create;
begin
   inherited Create;

   Speed        := 60;
   Direction    := -1;
   WallCooldown := 0.0;
end;

{ TEnemySystem }

constructor TEnemySystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 3;
   Name     := 'EnemySystem';
end;

procedure TEnemySystem.Init;
begin
   inherited;

   RequireComponent(TEnemyTag);
   RequireComponent(TTransformComponent);
   RequireComponent(TRigidBodyComponent);
   RequireComponent(TGoombaComponent);
end;

procedure TEnemySystem.Update(ADelta: Single);
var
   E   : TEntity;
   Tr  : TTransformComponent;
   RB  : TRigidBodyComponent;
   G   : TGoombaComponent;
   Spr : TSpriteComponent;
begin
   for E in GetMatchingEntities do
   begin
      if not E.Alive then
         Continue;

      Tr  := TTransformComponent(E.GetComponent(TTransformComponent));
      RB  := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
      G   := TGoombaComponent(E.GetComponent(TGoombaComponent));
      Spr := TSpriteComponent(E.GetComponent(TSpriteComponent));

      { --- 1. Advance the wall-flip cooldown timer -------------------------- }
      if G.WallCooldown > 0 then
         G.WallCooldown := G.WallCooldown - ADelta;

      { --- 2. Reverse direction on wall contact ----------------------------
      OnWall is set by TCollisionSystem (FixedUpdate, priority 20) whenever
      a horizontal tile resolution is applied, and is reset to False by
      TPhysicsSystem at the START of each FixedUpdate step (priority 10).

      The cooldown guard prevents rapid oscillation in the frames where
      the physics solver has not yet moved the collider far enough from the
      tile surface to avoid triggering another horizontal resolution.

      The check runs BEFORE the velocity assignment so that the corrected
      direction is applied immediately in the same Update frame.             }
      if RB.OnWall and (G.WallCooldown <= 0) then
      begin
         G.Direction    := -G.Direction;
         G.WallCooldown := GOOMBA_WALL_COOLDOWN;
      end;

      { --- 3. Apply walking velocity (uses the already-corrected direction) - }
      RB.Velocity.X := G.Speed * G.Direction;

      { --- 4. Sync sprite flip with current direction ----------------------- }
      if Assigned(Spr) then
      begin
         if G.Direction < 0 then
            Spr.Flip := flHorizontal
         else
             Spr.Flip := flNone;
      end;

      { --- 5. Destroy if fell below the kill zone -------------------------- }
      if Tr.Position.Y > PLAYER_KILL_ZONE then
         World.DestroyEntity(E.ID);
   end;
end;

end.

