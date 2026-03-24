unit P2D.Systems.Physics;

{$mode objfpc}
{$H+}

{ =============================================================================
  TPhysicsSystem — expanded fixed-step integrator.

  PIPELINE PER FIXEDUPDATE STEP
  ──────────────────────────────
  All steps run in FixedUpdate so behaviour is frame-rate-independent.
  Priority 10 → always before TCollisionSystem (20).

  1. Snapshot PrevPosition on TTransformComponent for render interpolation.
  2. Reset contact flags (Grounded, OnWall, OnCeiling) via ResetContacts.
  3. Tick platform-feel timers (CoyoteTimeLeft, JumpBufferLeft).
  4. Integrate ForceAccumulator: a = F / m  →  clear accumulator.
  5. Apply Acceleration (persistent forces, e.g. wind or conveyor belts).
  6. Apply gravity (GRAVITY × GravityScale) if UseGravity is True.
  7. Apply linear drag (exponential decay, frame-rate-independent).
  8. Clamp speed on both axes (MaxFallSpeed, MaxSpeedX).
  9. Semi-implicit Euler position integration.

  PLATFORM-FEEL TIMERS
  ─────────────────────
  CoyoteTimeLeft  — counts down after the entity walks off a ledge.
                    While > 0 the entity may still jump even though
                    Grounded is False.  Refilled to CoyoteTime each step
                    that Grounded is True.

  JumpBufferLeft  — counts down after RequestJump() is called in mid-air.
                    While > 0 TPlayerPhysicsSystem executes the jump as
                    soon as the entity becomes Grounded.

  FORCE ACCUMULATOR
  ─────────────────
  Any system can call RB.AddForce(F) during its Update/FixedUpdate.
  TPhysicsSystem reads ForceAccum once, converts to velocity change
  (ΔV = F / Mass × dt) and clears it.  This gives clean F=ma semantics
  without requiring systems to coordinate Acceleration writes.

  RENDER INTERPOLATION
  ─────────────────────
  TTransformComponent.PrevPosition is now written at the START of every
  step (before position changes).  TEngine2D.Alpha = accumulator/FIXED_DT
  is already exposed via the Engine.Alpha property.  The render system (or
  custom camera code) can lerp between PrevPosition and Position with Alpha
  for sub-frame-smooth visuals.
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
   P2D.Core.World,
   P2D.Components.Transform,
   P2D.Components.RigidBody;

type
   TPhysicsSystem = class(TSystem2D)
   private
      FTransformID: Integer;
      FRigidBodyID: Integer;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure FixedUpdate(AFixedDelta: Single); override;
   end;

implementation

constructor TPhysicsSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 10;
   Name := 'PhysicsSystem';
end;

procedure TPhysicsSystem.Init;
begin
   inherited;

   RequireComponent(TTransformComponent);
   RequireComponent(TRigidBodyComponent);
   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
   FRigidBodyID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
end;

procedure TPhysicsSystem.Update(ADelta: Single);
begin
   { All integration is in FixedUpdate — frame-rate independence. }
end;

procedure TPhysicsSystem.FixedUpdate(AFixedDelta: Single);
var
   E: TEntity;
   Tr: TTransformComponent;
   RB: TRigidBodyComponent;
   WasGrounded: Boolean;
   SafeMass: Single;
   DragFactorX: Single;
   DragFactorY: Single;
begin
   for E In GetMatchingEntities do
   begin
      Tr := TTransformComponent(E.GetComponentByID(FTransformID));
      RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));

      if Not Assigned(Tr) Or Not Assigned(RB) then
      begin
         Continue
      end;
      if Not (Tr.Enabled And RB.Enabled) then
      begin
         Continue
      end;

      { ── 1. Snapshot position for render interpolation ──────────────────── }
      Tr.PrevPosition := Tr.Position;

      { ── 2. Save Grounded state, then reset contact flags ───────────────── }
      WasGrounded := RB.Grounded;
      RB.ResetContacts;

      { ── 3. Platform-feel timers ────────────────────────────────────────── }

      { Coyote time: refill while standing on ground, tick down when airborne. }
      if WasGrounded then
      begin
         RB.CoyoteTimeLeft := RB.CoyoteTime
      end
      else
      if RB.CoyoteTimeLeft > 0 then
      begin
         RB.CoyoteTimeLeft := Max(0, RB.CoyoteTimeLeft - AFixedDelta)
      end;

      { Jump buffer: tick down every step regardless of ground state. }
      if RB.JumpBufferLeft > 0 then
      begin
         RB.JumpBufferLeft := Max(0, RB.JumpBufferLeft - AFixedDelta)
      end;

      { ── 4. Force accumulator → velocity (F = ma → a = F/m) ────────────── }
      { Guard against zero / negative mass to avoid division by zero. }
      SafeMass := Max(RB.Mass, 0.001);

      if (RB.ForceAccum.X <> 0) Or (RB.ForceAccum.Y <> 0) then
      begin
         RB.Velocity.X := RB.Velocity.X + (RB.ForceAccum.X / SafeMass) * AFixedDelta;
         RB.Velocity.Y := RB.Velocity.Y + (RB.ForceAccum.Y / SafeMass) * AFixedDelta;
         RB.ForceAccum.X := 0;
         RB.ForceAccum.Y := 0;
      end;

      { ── 5. Persistent acceleration (wind, conveyors, etc.) ─────────────── }
      if (RB.Acceleration.X <> 0) Or (RB.Acceleration.Y <> 0) then
      begin
         RB.Velocity.X := RB.Velocity.X + RB.Acceleration.X * AFixedDelta;
         RB.Velocity.Y := RB.Velocity.Y + RB.Acceleration.Y * AFixedDelta;
      end;

      { ── 6. Gravity ─────────────────────────────────────────────────────── }
      { Applied unconditionally so the entity always slightly penetrates the
      tile surface — TCollisionSystem (priority 20) then corrects this and
      re-sets Grounded := True.  Removing the guard was intentional. }
      if RB.UseGravity then
      begin
         RB.Velocity.Y := RB.Velocity.Y + GRAVITY * RB.GravityScale * AFixedDelta
      end;

      { ── 7. Linear drag (exponential decay, frame-rate-independent) ──────── }
      { exp(-drag * dt) approaches 0 as drag→∞, never produces negative V.
      A drag of 0 is a no-op (exp(0)=1). Typical values: 1..8.             }
      if RB.LinearDragX > 0 then
      begin
         DragFactorX := Exp(-RB.LinearDragX * AFixedDelta);
         RB.Velocity.X := RB.Velocity.X * DragFactorX;
      end;

      if RB.LinearDragY > 0 then
      begin
         DragFactorY := Exp(-RB.LinearDragY * AFixedDelta);
         RB.Velocity.Y := RB.Velocity.Y * DragFactorY;
      end;

      { ── 8. Speed clamping ───────────────────────────────────────────────── }
      { Vertical: clamp downward (positive Y) velocity only. }
      if RB.Velocity.Y > RB.MaxFallSpeed then
      begin
         RB.Velocity.Y := RB.MaxFallSpeed
      end;

      { Horizontal: symmetric clamp; skip if MaxSpeedX = 0 (unlimited). }
      if (RB.MaxSpeedX > 0) And (Abs(RB.Velocity.X) > RB.MaxSpeedX) then
      begin
         RB.Velocity.X := Sign(RB.Velocity.X) * RB.MaxSpeedX
      end;

      { ── 9. Semi-implicit Euler position integration ─────────────────────── }
      { PrevVelocity stored after all modifications so interpolated frames
      use the velocity that was actually applied this step. }
      RB.PrevVelocity := RB.Velocity;
      Tr.Position.X := Tr.Position.X + RB.Velocity.X * AFixedDelta;
      Tr.Position.Y := Tr.Position.Y + RB.Velocity.Y * AFixedDelta;
   end;
end;

end.
