unit Mario.Systems.Fish;

{$mode objfpc}
{$H+}

{ =============================================================================
  TFishSystem — AI for underwater fish enemies.

  PHYSICS EXPANSION FEATURES DEMONSTRATED
  ─────────────────────────────────────────
  • UseGravity = False         — fish are neutrally buoyant
  • LinearDragY = 6.0         — strong vertical damping; smooths oscillation
  • AddForce (sine wave)      — sinusoidal vertical thrust creates a natural
                                 swimming undulation without hard-coded Y positions
  • LinearDragX = 0.3         — very light horizontal drag; speed mostly via
                                 direct Velocity assignment (simple AI)
  • Restitution = 0           — dead stop on wall hit (flip direction instead)

  MOVEMENT
  ─────────
  Horizontal: constant Velocity.X = Speed × Direction
    Reverses on OnWall (same pattern as Goomba) with a cooldown guard.
  Vertical: AddForce(sin(OscTimer × 2π × Freq) × Amplitude)
    The sine wave is integrated by TPhysicsSystem. LinearDragY prevents
    the force from producing unbounded vertical velocity; the fish
    oscillates around its nominal height with a smooth, natural look.
  ============================================================================= }

interface

uses
   SysUtils,
   Math,
   raylib,
   P2D.Core.ComponentRegistry,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Components.Transform,
   P2D.Components.RigidBody,
   P2D.Components.Sprite,
   Mario.Common,
   Mario.Components.Fish;

type
   TFishSystem = class(TSystem2D)
   private
      FTransformID: Integer;
      FRigidBodyID: Integer;
      FFishID: Integer;
      FSpriteID: Integer;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
   end;

implementation

constructor TFishSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 3;
   Name := 'FishSystem';
end;

procedure TFishSystem.Init;
begin
   inherited;

   RequireComponent(TFishComponent);
   RequireComponent(TTransformComponent);
   RequireComponent(TRigidBodyComponent);
   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
   FRigidBodyID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
   FFishID := ComponentRegistry.GetComponentID(TFishComponent);
   FSpriteID := ComponentRegistry.GetComponentID(TSpriteComponent);
end;

procedure TFishSystem.Update(ADelta: Single);
var
   E: TEntity;
   Tr: TTransformComponent;
   RB: TRigidBodyComponent;
   F: TFishComponent;
   Spr: TSpriteComponent;
   OscForce: Single;
begin
   for E In GetMatchingEntities do
   begin
      Tr := TTransformComponent(E.GetComponentByID(FTransformID));
      RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
      F := TFishComponent(E.GetComponentByID(FFishID));
      Spr := TSpriteComponent(E.GetComponentByID(FSpriteID));

      if Not Assigned(Tr) Or Not Assigned(RB) Or Not Assigned(F) then
      begin
         Continue
      end;

      { ── 1. Wall-cooldown timer ─────────────────────────────────────────── }
      if F.WallCooldown > 0 then
      begin
         F.WallCooldown := F.WallCooldown - ADelta
      end;

      { ── 2. Reverse on wall ──────────────────────────────────────────────── }
      if RB.OnWall And (F.WallCooldown <= 0) then
      begin
         F.Direction := -F.Direction;
         F.WallCooldown := GOOMBA_WALL_COOLDOWN;  { reuse existing constant }
      end;

      { ── 3. Horizontal velocity (direct assignment, no integration needed) ── }
      RB.Velocity.X := F.Speed * F.Direction;

      { ── 4. Vertical sine-wave oscillation via AddForce ─────────────────── }
      { F = A × sin(2π × freq × t)
      The force is integrated by TPhysicsSystem; LinearDragY (set during
      entity creation) damps the resulting velocity so the fish oscillates
      smoothly around its current height rather than drifting away. }
      F.OscTimer := F.OscTimer + ADelta;
      OscForce := F.OscAmplitude * Sin(F.OscTimer * 2 * Pi * F.OscFrequency);
      RB.AddForce(Vector2Create(0, OscForce));

      { ── 5. Sprite flip ─────────────────────────────────────────────────── }
      if Assigned(Spr) then
      begin
         if F.Direction < 0 then
         begin
            Spr.Flip := flNone
         end
         else
         begin
            Spr.Flip := flHorizontal
         end;
      end;

      { ── 6. Kill zone ───────────────────────────────────────────────────── }
      if Tr.Position.Y > PLAYER_KILL_ZONE then
      begin
         World.DestroyEntity(E.ID)
      end;
   end;
end;

end.
