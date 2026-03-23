unit Mario.Systems.Player;

{$mode objfpc}{$H+}

{ Adaptation to the expanded TRigidBodyComponent.
  Changes from the previous version:
    • Jump detection reads CoyoteTimeLeft (instead of Grounded) so the
      player can jump for a brief window after walking off a ledge.
    • AddImpulse replaces direct Velocity.Y assignment for jumps so Mass
      is respected and the API is consistent.
    • RequestJump in the input phase fills JumpBufferLeft so late-pressed
      jumps still register when the player lands.
    • Kill-zone respawn uses AddImpulse instead of direct Velocity write. }

interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World, P2D.Core.ComponentRegistry,
   P2D.Components.Transform, P2D.Components.RigidBody, P2D.Components.Sprite, P2D.Components.Animation, P2D.Components.InputMap, P2D.Components.Collider, P2D.Components.StateMachine,
   P2D.Utils.Math,
   Mario.Common, Mario.Components.Player;

type
   TPlayerPhysicsSystem = class(TSystem2D)
   private
      FTransformID: Integer;
      FRigidBodyID: Integer;
      FPlayerID   : Integer;
      FFSMID      : Integer;
      procedure SetState(PC: TPlayerComponent; FSM: TStateMachineComponent2D; AState: TPlayerState); inline;
      procedure OnPlayerEnterState(AEntityID: Cardinal; AStateID: TStateID);
      procedure OnPlayerExitState (AEntityID: Cardinal; AStateID: TStateID);
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure FixedUpdate(AFixedDelta: Single); override;
   end;

   TPlayerAnimSystem = class(TSystem2D)
   private
      FPlayerID   : Integer;
      FRigidBodyID: Integer;
      FSpriteID   : Integer;
      FAnimID     : Integer;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
   end;

implementation

uses
   Mario.Events, P2D.Core.InputManager;

{ TPlayerPhysicsSystem }
constructor TPlayerPhysicsSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 7;
   Name     := 'PlayerPhysicsSystem';
end;

procedure TPlayerPhysicsSystem.SetState(PC: TPlayerComponent; FSM: TStateMachineComponent2D; AState: TPlayerState);
begin
   PC.State := AState;
   if Assigned(FSM) then
      FSM.RequestTransition(Ord(AState));
end;

procedure TPlayerPhysicsSystem.OnPlayerEnterState(AEntityID: Cardinal; AStateID: TStateID);
var
   E  : TEntity;
   PC : TPlayerComponent;
   RB : TRigidBodyComponent;
begin
   E := World.GetEntity(AEntityID);
   if not Assigned(E) or not E.Alive then
      Exit;
   PC := TPlayerComponent(E.GetComponentByID(FPlayerID));
   if not Assigned(PC) then
      Exit;
   case TPlayerState(AStateID) of
      psJumping, psRunJumping: World.EventBus.Publish(TPlayerJumpEvent.Create);
      psSpinJump: World.EventBus.Publish(TPlayerSpinEvent.Create);
      psDead:
         begin
            RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
            if Assigned(RB) then
               RB.AddImpulse(Vector2Create(0, -400));  { ← AddImpulse, not direct write }
            World.EventBus.Publish(TPlayerDiedEvent.Create);
         end;
   end;
end;

procedure TPlayerPhysicsSystem.OnPlayerExitState(AEntityID: Cardinal; AStateID: TStateID);
begin

end;

procedure TPlayerPhysicsSystem.Init;
var
   E  : TEntity;
   FSM: TStateMachineComponent2D;
begin
   inherited;

   RequireComponent(TTransformComponent);
   RequireComponent(TRigidBodyComponent);
   RequireComponent(TPlayerComponent);
   RequireComponent(TStateMachineComponent2D);
   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
   FRigidBodyID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
   FPlayerID    := ComponentRegistry.GetComponentID(TPlayerComponent);
   FFSMID       := ComponentRegistry.GetComponentID(TStateMachineComponent2D);
   for E in GetMatchingEntities do
   begin
      FSM := TStateMachineComponent2D(E.GetComponentByID(FFSMID));
      if not Assigned(FSM) then
         Continue;
      FSM.OnEnter := @OnPlayerEnterState;
      FSM.OnExit  := @OnPlayerExitState;
   end;
end;

procedure TPlayerPhysicsSystem.Update(ADelta: Single);
begin

end;

procedure TPlayerPhysicsSystem.FixedUpdate(AFixedDelta: Single);
var
   E          : TEntity;
   Tr         : TTransformComponent;
   RB         : TRigidBodyComponent;
   PC         : TPlayerComponent;
   FSM        : TStateMachineComponent2D;
   TargetSpeed: Single;
   Accel, Fric: Single;
   InputDir   : Integer;
   CanJump    : Boolean;   { coyote window OR grounded }
begin
   for E in GetMatchingEntities do
   begin
      Tr  := TTransformComponent(E.GetComponentByID(FTransformID));
      RB  := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
      PC  := TPlayerComponent(E.GetComponentByID(FPlayerID));
      FSM := TStateMachineComponent2D(E.GetComponentByID(FFSMID));

      { Dead / special states: minimal physics }
      if PC.State in [psDead, psVictory, psPipe] then
      begin
         if PC.State = psDead then
         begin
            Tr.Position.Y := Tr.Position.Y + RB.Velocity.Y * AFixedDelta;
            RB.Velocity.Y := RB.Velocity.Y + 980.0 * AFixedDelta;
         end;
         Continue;
      end;

      { ── Input direction ────────────────────────────────────────────────── }
      InputDir := 0;
      if PC.WantsMoveLeft then
         InputDir := -1;
      if PC.WantsMoveRight then
         InputDir :=  1;
      if RB.Grounded and PC.WantsDuck then
         InputDir := 0;

      { ── Horizontal movement ────────────────────────────────────────────── }
      if PC.WantsRun then
         TargetSpeed := PC.RunSpeed
      else
          TargetSpeed := PC.WalkSpeed;
      TargetSpeed := TargetSpeed * InputDir;

      if RB.Grounded then
      begin
         if (InputDir <> 0) and (Sign(RB.Velocity.X) <> InputDir) and (Abs(RB.Velocity.X) > SKID_THRESHOLD) then
            Accel := FRICTION_SKID
         else if PC.WantsRun then
            Accel := ACCEL_RUN
         else
            Accel := ACCEL_WALK;
         Fric := IfThen(InputDir = 0, FRICTION_GND, 0);
      end
      else
      begin
         Accel := ACCEL_AIR;
         Fric  := FRICTION_AIR;
      end;

      if InputDir <> 0 then
         RB.Velocity.X := ApproachF(RB.Velocity.X, TargetSpeed, Accel * AFixedDelta)
      else
         RB.Velocity.X := ApproachF(RB.Velocity.X, 0, (FRICTION_GND + Fric) * AFixedDelta);

      { ── Jump (Coyote Time + Jump Buffer) ───────────────────────────────── }
      { CanJump is True when: (a) standing on ground, OR (b) within the coyote
      window after walking off a ledge.  JumpBufferLeft allows a jump pressed
      just before landing to execute immediately on contact. }
      CanJump := RB.Grounded or (RB.CoyoteTimeLeft > 0);

      if CanJump and ((PC.WantsJump) or (RB.JumpBufferLeft > 0)) then
      begin
         { Consume both flags }
         PC.WantsJump       := False;
         RB.JumpBufferLeft  := 0;
         RB.CoyoteTimeLeft  := 0;   { prevent double-jump on coyote window }
         RB.Grounded        := False;

         { Use AddImpulse so Mass is respected (heavier entities jump lower). }
         RB.AddImpulse(Vector2Create(0, PC.JumpForce));

         if PC.WantsSpin then
         begin
            SetState(PC, FSM, psSpinJump);
            PC.WantsSpin := False;
         end
         else
         begin
            if Abs(RB.Velocity.X) > (PC.RunSpeed * 0.85) then
               SetState(PC, FSM, psRunJumping)
            else
               SetState(PC, FSM, psJumping);
         end;
      end
      else if PC.WantsJump and not CanJump then
      begin
         { Not on ground yet — fill jump buffer for landing window. }
         RB.RequestJump;
         PC.WantsJump := False;
      end
      else
         PC.WantsJump := False;

      { Variable jump height (jump cut) }
      if PC.WantsJumpCut then
      begin
         if RB.Velocity.Y < -200 then
            RB.Velocity.Y := -200;
         PC.WantsJumpCut := False;
      end;

      { ── Ground state machine ───────────────────────────────────────────── }
      if RB.Grounded then
      begin
         if PC.WantsDuck then
         begin
            SetState(PC, FSM, psCrouching);
            RB.Velocity.X := ApproachF(RB.Velocity.X, 0, FRICTION_SKID * AFixedDelta);
         end
         else if (InputDir <> 0) and (Sign(RB.Velocity.X) <> InputDir) and (Abs(RB.Velocity.X) > SKID_THRESHOLD) then
            SetState(PC, FSM, psSkid)
         else if Abs(RB.Velocity.X) > 10.0 then
         begin
            if PC.WantsRun then
               SetState(PC, FSM, psRunning)
            else
               SetState(PC, FSM, psWalking);
         end
         else
         SetState(PC, FSM, psIdle);
      end
      else
      begin
         if PC.State = psSpinJump then { stay }
         else if RB.Velocity.Y < 0 then
         begin
            if PC.State <> psRunJumping then
               SetState(PC, FSM, psJumping);
         end
         else
            SetState(PC, FSM, psFalling);
      end;

      { ── Kill zone ──────────────────────────────────────────────────────── }
      if Tr.Position.Y > PLAYER_KILL_ZONE then
      begin
         Dec(PC.Lives);
         if PC.Lives > 0 then
         begin
            Tr.Position    := Vector2Create(PLAYER_SPAWN_X, PLAYER_SPAWN_Y);
            RB.Velocity    := Vector2Create(0, 0);
            RB.Acceleration:= Vector2Create(0, 0);
            RB.ForceAccum  := Vector2Create(0, 0);
            PC.InvFrames   := RESPAWN_INV_TIME;
            SetState(PC, FSM, psIdle);
         end
         else
            SetState(PC, FSM, psDead);
      end;
   end;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  TPlayerAnimSystem — unchanged
  ═══════════════════════════════════════════════════════════════════════════ }
constructor TPlayerAnimSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 8;
   Name     := 'PlayerAnimSystem';
end;

procedure TPlayerAnimSystem.Init;
begin
   inherited;

   RequireComponent(TPlayerComponent);
   RequireComponent(TRigidBodyComponent);
   RequireComponent(TSpriteComponent);
   RequireComponent(TAnimationComponent);
   FPlayerID    := ComponentRegistry.GetComponentID(TPlayerComponent);
   FRigidBodyID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
   FSpriteID    := ComponentRegistry.GetComponentID(TSpriteComponent);
   FAnimID      := ComponentRegistry.GetComponentID(TAnimationComponent);
end;

procedure TPlayerAnimSystem.Update(ADelta: Single);
var
   E   : TEntity;
   PC  : TPlayerComponent;
   RB  : TRigidBodyComponent;
   Spr : TSpriteComponent;
   Anim: TAnimationComponent;
begin
   for E in GetMatchingEntities do
   begin
      PC   := TPlayerComponent(E.GetComponentByID(FPlayerID));
      RB   := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
      Spr  := TSpriteComponent(E.GetComponentByID(FSpriteID));
      Anim := TAnimationComponent(E.GetComponentByID(FAnimID));
      if PC.State <> psDead then
      begin
         if PC.State = psSkid then
         begin
            if RB.Velocity.X > 0 then
               Spr.Flip := flNone
            else if RB.Velocity.X < 0 then
               Spr.Flip := flHorizontal;
         end
         else
         begin
            if PC.WantsMoveLeft then
               Spr.Flip := flHorizontal
            else if PC.WantsMoveRight then
               Spr.Flip := flNone
            else if Abs(RB.Velocity.X) > 1.0 then
            begin
               if RB.Velocity.X < 0 then
                  Spr.Flip := flHorizontal
               else
                  Spr.Flip := flNone;
            end;
         end;
      end;
      case PC.State of
         psIdle       : Anim.Play('idle');
         psWalking    : Anim.Play('walk');
         psRunning    : Anim.Play('run');
         psSkid       : Anim.Play('skid');
         psCrouching  : Anim.Play('duck');
         psJumping    : Anim.Play('jump');
         psRunJumping : Anim.Play('run_jump');
         psSpinJump   : Anim.Play('spin');
         psFalling    : Anim.Play('fall');
         psVictory    : Anim.Play('victory');
         psPipe       : Anim.Play('pipe');
         psDead       : Anim.Play('dead');
      end;
   end;
end;

end.
