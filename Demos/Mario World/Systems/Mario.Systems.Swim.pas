unit Mario.Systems.Swim;

{$mode objfpc}{$H+}

{ =============================================================================
  TSwimSystem — underwater physics driver for the player.

  PRIORITY: 4  (before TStateMachineSystem2D=6, TPlayerPhysicsSystem=7,
                 TPhysicsSystem=10, TCollisionSystem=20)

  INIT
  ────
  Reads TSwimmerComponent overrides and writes them into TRigidBodyComponent,
  replacing the land-physics defaults:
    GravityScale  → UnderwaterGravityScale (gentle sink)
    LinearDragX   → UnderwaterDragX        (water resistance)
    LinearDragY   → UnderwaterDragY        (water resistance)
    MaxFallSpeed  → UnderwaterMaxFallSpeed  (slow terminal velocity)
    MaxSpeedX     → UnderwaterMaxSpeedX     (capped swim speed)
    Restitution   → UnderwaterRestitution   (slight coral bounce)
  Original values are saved in the Swimmer component for later restoration.

  FIXEDUPDATE
  ───────────
  1. WantsJump (held) → AddForce(SwimUpForce)   — continuous upward thrust.
     WantsDuck (held) → AddForce(SwimDownForce) — dive down.
     Both forces are integrated by TPhysicsSystem; drag ensures the entity
     doesn't accelerate indefinitely.

  2. WantsJump is cleared so TPlayerPhysicsSystem sees False and does NOT
     execute the sharp-impulse land-jump logic.

  3. State transitions:
     Moving (|Vx| or |Vy| > threshold) → psSwimming
     Otherwise                          → psSwimIdle
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
   P2D.Components.StateMachine,
   Mario.Components.Player,
   Mario.Components.Swimmer;

type
   TSwimSystem = class(TSystem2D)
   private
      FTransformID: Integer;
      FRigidBodyID: Integer;
      FPlayerID: Integer;
      FSwimmerID: Integer;
      FFSMID: Integer;

      procedure SetState(PC: TPlayerComponent; FSM: TStateMachineComponent2D; AState: TPlayerState); inline;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure FixedUpdate(AFixedDelta: Single); override;
   end;

implementation

constructor TSwimSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);
   Priority := 4;
   Name := 'SwimSystem';
end;

procedure TSwimSystem.SetState(PC: TPlayerComponent; FSM: TStateMachineComponent2D; AState: TPlayerState);
begin
   PC.State := AState;
   if Assigned(FSM) then
   begin
      FSM.RequestTransition(Ord(AState));
   end;
end;

procedure TSwimSystem.Init;
var
   E: TEntity;
   RB: TRigidBodyComponent;
   SW: TSwimmerComponent;
begin
   inherited;

   RequireComponent(TRigidBodyComponent);
   RequireComponent(TSwimmerComponent);
   RequireComponent(TPlayerComponent);

   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
   FRigidBodyID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
   FPlayerID := ComponentRegistry.GetComponentID(TPlayerComponent);
   FSwimmerID := ComponentRegistry.GetComponentID(TSwimmerComponent);
   FFSMID := ComponentRegistry.GetComponentID(TStateMachineComponent2D);

  { Apply underwater physics overrides to every swimmer entity.
    This runs once after LoadLevel (entities already exist) and replaces
    land-physics defaults on the RigidBody component. }
   for E in GetMatchingEntities do
   begin
      RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
      SW := TSwimmerComponent(E.GetComponentByID(FSwimmerID));
      if not Assigned(RB) or not Assigned(SW) then
      begin
         Continue;
      end;

      { Save original values for potential future surface restore }
      SW.SavedGravityScale := RB.GravityScale;
      SW.SavedDragX := RB.LinearDragX;
      SW.SavedDragY := RB.LinearDragY;
      SW.SavedMaxFallSpeed := RB.MaxFallSpeed;
      SW.SavedMaxSpeedX := RB.MaxSpeedX;
      SW.SavedRestitution := RB.Restitution;

      { Apply underwater overrides }
      RB.GravityScale := SW.UnderwaterGravityScale;
      RB.LinearDragX := SW.UnderwaterDragX;
      RB.LinearDragY := SW.UnderwaterDragY;
      RB.MaxFallSpeed := SW.UnderwaterMaxFallSpeed;
      RB.MaxSpeedX := SW.UnderwaterMaxSpeedX;
      RB.Restitution := SW.UnderwaterRestitution;
   end;
end;

procedure TSwimSystem.FixedUpdate(AFixedDelta: Single);
var
   E: TEntity;
   RB: TRigidBodyComponent;
   PC: TPlayerComponent;
   SW: TSwimmerComponent;
   FSM: TStateMachineComponent2D;
   Moving: boolean;
begin
   for E in GetMatchingEntities do
   begin
      RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
      PC := TPlayerComponent(E.GetComponentByID(FPlayerID));
      SW := TSwimmerComponent(E.GetComponentByID(FSwimmerID));

      if not Assigned(RB) or not Assigned(PC) or not Assigned(SW) then
      begin
         Continue;
      end;
      if PC.State = psDead then
      begin
         Continue;
      end;

      FSM := TStateMachineComponent2D(E.GetComponentByID(FFSMID));

      { ── 1. Swim thrust via AddForce (integrated by TPhysicsSystem) ───────── }
    { Holding Jump = swim upward: AddForce applies SwimUpForce each physics
      step. Drag prevents unlimited acceleration. The net effect at steady
      state (when drag balances force) is a comfortable upward glide. }
      if PC.WantsJump then
      begin
         RB.AddForce(Vector2Create(0, SW.SwimUpForce));
      { Consume WantsJump so TPlayerPhysicsSystem does NOT also trigger a
        land-jump impulse. CoyoteTimeLeft and JumpBufferLeft are irrelevant
        underwater so we leave them alone. }
         PC.WantsJump := False;
         PC.WantsJumpCut := False;
      end;

      { Holding Down (Duck in land context) = dive downward }
      if PC.WantsDuck then
      begin
         RB.AddForce(Vector2Create(0, SW.SwimDownForce));
      end;

      { ── 2. State transition (swim idle vs actively moving) ───────────────── }
      Moving := (Abs(RB.Velocity.X) > 8) or (Abs(RB.Velocity.Y) > 8);

      if Moving then
      begin
         SetState(PC, FSM, psSwimming);
      end
      else
      begin
         SetState(PC, FSM, psSwimIdle);
      end;
   end;
end;

end.
