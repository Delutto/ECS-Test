unit P2D.Components.RigidBody;

{$mode objfpc}{$H+}

{ =============================================================================
  TRigidBodyComponent — expanded physics data bag.

  EXPANSION SUMMARY (vs original)
  ────────────────────────────────
  ① Mass now drives F=ma: Acceleration is divided by Mass before being
    integrated, so heavier entities accelerate slower under the same force.
    The dedicated AddForce / AddImpulse helpers handle the division.

  ② ForceAccumulator — a per-step accumulation buffer.
    Call AddForce(F) one or many times per FixedUpdate. TPhysicsSystem
    integrates the accumulator once and clears it. Replaces the pattern of
    manually writing to Acceleration from multiple systems.

  ③ LinearDragX / LinearDragY — velocity-proportional air resistance.
    Applied as an exponential decay:  V *= exp(-drag * dt)
    which is frame-rate-independent and never overshoots zero.

  ④ Restitution — bounciness coefficient [0..1].
    0 = perfectly inelastic (current behaviour), 1 = perfectly elastic.
    TCollisionSystem uses it when resolving vertical tile hits.

  ⑤ MaxSpeedX — horizontal velocity cap, symmetric.
    Complements MaxFallSpeed (vertical cap) that already existed.

  ⑥ CoyoteTimeLeft / JumpBufferLeft — platform-game feel timers.
    Written and decremented by TPhysicsSystem. Read by TPlayerPhysicsSystem
    to allow forgiving jumps without any game-specific hacks in the engine.

  ⑦ PrevVelocity — velocity from the previous FixedUpdate step.
    Used by TPhysicsSystem to write TTransformComponent.PrevPosition,
    enabling the existing Engine.Alpha render interpolation.

  BACKWARD COMPATIBILITY
  ──────────────────────
  All original fields keep their names and defaults. Code that only uses
  Velocity / Acceleration / GravityScale / MaxFallSpeed / Grounded / OnWall
  / UseGravity compiles and behaves identically without changes.
  ============================================================================= }

interface

uses
   P2D.Common,
   P2D.Core.Component,
   P2D.Core.Types;

type
   TRigidBodyComponent = class(TComponent2D)
   public
      { ── Core kinematics (original fields — unchanged semantics) ────────── }
      Velocity: TVector2;   { world-units / second                        }
      Acceleration: TVector2;   { world-units / second²  (persistent force)   }
      Mass: Single;     { kg — now used: Acceleration / Mass = a      }

      { ── Gravity ─────────────────────────────────────────────────────────── }
      GravityScale: Single;     { multiplier on the global GRAVITY constant    }
      UseGravity: boolean;

      { ── Speed limits ────────────────────────────────────────────────────── }
      MaxFallSpeed: Single;     { terminal velocity on Y (positive = downward) }
      MaxSpeedX: Single;     { ① horizontal speed cap; 0 = unlimited        }

      { ── Contact state (set by TCollisionSystem each FixedUpdate) ─────────── }
      Grounded: boolean;
      OnWall: boolean;
      OnCeiling: boolean;    { ① True when pushed down from a tile above    }

      { ── Drag ────────────────────────────────────────────────────────────── }
      LinearDragX: Single;     { ③ horizontal drag coefficient (≥ 0)          }
      LinearDragY: Single;     { ③ vertical drag coefficient  (≥ 0)           }

      { ── Restitution ─────────────────────────────────────────────────────── }
      Restitution: Single;     { ④ bounciness [0=inelastic .. 1=elastic]      }

      { ── Force accumulator (cleared by TPhysicsSystem each step) ─────────── }
      ForceAccum: TVector2;   { ② sum of AddForce() calls this step          }

      { ── Platform-feel timers (managed by TPhysicsSystem) ─────────────────── }
      CoyoteTime: Single;  { ⑥ max coyote window in seconds               }
      CoyoteTimeLeft: Single;  { ⑥ remaining coyote seconds (> 0 = can jump)  }
      JumpBuffer: Single;  { ⑥ max jump-buffer window in seconds          }
      JumpBufferLeft: Single;  { ⑥ remaining buffer seconds (> 0 = buffered)  }

      { ── Previous-step snapshot (used for render interpolation) ───────────── }
      PrevVelocity: TVector2;   { ⑦ velocity at start of last FixedUpdate      }

      constructor Create; override;

      { AddForce: accumulates a continuous force (world-units/s² × mass).
      Call once per FixedUpdate from any system; TPhysicsSystem integrates
      and clears ForceAccum at the beginning of each step.
      Example: AddForce(Vector2Create(0, -500)) for an upward push. }
      procedure AddForce(const AForce: TVector2); inline;

      { AddImpulse: applies an instantaneous velocity change (world-units/s).
      Bypasses ForceAccum and Mass; directly modifies Velocity.
      Use for immediate reactions: jump, knockback, explosion push. }
      procedure AddImpulse(const AImpulse: TVector2); inline;

      { RequestJump: marks a jump-buffer request for the current/next frames.
      Call from the input system instead of writing Velocity.Y directly;
      TPlayerPhysicsSystem (or any consumer) reads JumpBufferLeft. }
      procedure RequestJump; inline;

      { ResetContacts: zeroes Grounded, OnWall, OnCeiling.
      Called at the start of each FixedUpdate by TPhysicsSystem. }
      procedure ResetContacts; inline;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TRigidBodyComponent.Create;
begin
   inherited Create;

   Velocity.X := 0;
   Velocity.Y := 0;
   Acceleration.X := 0;
   Acceleration.Y := 0;
   ForceAccum.X := 0;
   ForceAccum.Y := 0;
   PrevVelocity.X := 0;
   PrevVelocity.Y := 0;
   Mass := 1.0;
   GravityScale := 1.0;
   MaxFallSpeed := 600.0;
   MaxSpeedX := 0.0;      { 0 = unlimited }
   Grounded := False;
   OnWall := False;
   OnCeiling := False;
   UseGravity := True;
   LinearDragX := 0.0;
   LinearDragY := 0.0;
   Restitution := 0.0;
   CoyoteTime := DEFAULT_COYOTE_TIME;
   CoyoteTimeLeft := 0.0;
   JumpBuffer := DEFAULT_JUMP_BUFFER;
   JumpBufferLeft := 0.0;
end;

procedure TRigidBodyComponent.AddForce(const AForce: TVector2);
begin
   ForceAccum.X := ForceAccum.X + AForce.X;
   ForceAccum.Y := ForceAccum.Y + AForce.Y;
end;

procedure TRigidBodyComponent.AddImpulse(const AImpulse: TVector2);
begin
   Velocity.X := Velocity.X + AImpulse.X;
   Velocity.Y := Velocity.Y + AImpulse.Y;
end;

procedure TRigidBodyComponent.RequestJump;
begin
   JumpBufferLeft := JumpBuffer;
end;

procedure TRigidBodyComponent.ResetContacts;
begin
   Grounded := False;
   OnWall := False;
   OnCeiling := False;
end;

initialization
   ComponentRegistry.Register(TRigidBodyComponent);

end.
