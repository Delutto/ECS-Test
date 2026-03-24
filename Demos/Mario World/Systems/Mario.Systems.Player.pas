unit Mario.Systems.Player;

{$mode objfpc}
{$H+}

interface

uses
   SysUtils,
   Math,
   raylib,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Core.ComponentRegistry,
   P2D.Components.Transform,
   P2D.Components.RigidBody,
   P2D.Components.Sprite,
   P2D.Components.Animation,
   P2D.Components.InputMap,
   P2D.Components.Collider,
   P2D.Components.StateMachine,
   P2D.Utils.Math,
   Mario.Common,
   Mario.Components.Player,
   Mario.Components.Swimmer;

type
   TPlayerPhysicsSystem = class(TSystem2D)
   private
      FTransformID: Integer;
	     FRigidBodyID: Integer;
      FPlayerID: Integer;
	     FFSMID: Integer;
	     FSwimmerID: Integer;
      procedure SetState(PC: TPlayerComponent; FSM: TStateMachineComponent2D; AState: TPlayerState); inline;
      procedure OnPlayerEnterState(AEntityID: Cardinal; AStateID: TStateID);
      procedure OnPlayerExitState(AEntityID: Cardinal; AStateID: TStateID);
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure FixedUpdate(AFixedDelta: Single); override;
   end;

   TPlayerAnimSystem = class(TSystem2D)
   private
      FPlayerID: Integer;
	     FRigidBodyID: Integer;
      FSpriteID: Integer;
	     FAnimID: Integer;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
   end;

implementation

uses
   Mario.Events,
   P2D.Core.InputManager;

{ ═══ TPlayerPhysicsSystem ═══════════════════════════════════════════════════ }
constructor TPlayerPhysicsSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);
   Priority := 7;
   Name := 'PlayerPhysicsSystem';
end;

procedure TPlayerPhysicsSystem.SetState(PC: TPlayerComponent; FSM: TStateMachineComponent2D; AState: TPlayerState);
begin
   PC.State := AState;
   if Assigned(FSM) then
   begin
      FSM.RequestTransition(Ord(AState))
   end;
end;

procedure TPlayerPhysicsSystem.OnPlayerEnterState(AEntityID: Cardinal; AStateID: TStateID);
var
   E: TEntity;
   PC: TPlayerComponent;
   RB: TRigidBodyComponent;
begin
   E := World.GetEntity(AEntityID);
   if Not Assigned(E) Or Not E.Alive then
   begin
      Exit
   end;
   PC := TPlayerComponent(E.GetComponentByID(FPlayerID));
   if Not Assigned(PC) then
   begin
      Exit
   end;
   case TPlayerState(AStateID) of
      psJumping, psRunJumping:
      begin
         World.EventBus.Publish(TPlayerJumpEvent.Create)
      end;
      psSpinJump:
      begin
         World.EventBus.Publish(TPlayerSpinEvent.Create)
      end;
      psDead:
      begin
         RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
         if Assigned(RB) then
	        begin
            RB.AddImpulse(Vector2Create(0, -400))
         end;
         World.EventBus.Publish(TPlayerDiedEvent.Create);
      end;
   end;
end;

procedure TPlayerPhysicsSystem.OnPlayerExitState(AEntityID: Cardinal; AStateID: TStateID);
begin

end;

procedure TPlayerPhysicsSystem.Init;
var
   E: TEntity;
   FSM: TStateMachineComponent2D;
begin
   inherited;

   RequireComponent(TTransformComponent);
   RequireComponent(TRigidBodyComponent);
   RequireComponent(TPlayerComponent);
   RequireComponent(TStateMachineComponent2D);

   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
   FRigidBodyID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
   FPlayerID := ComponentRegistry.GetComponentID(TPlayerComponent);
   FFSMID := ComponentRegistry.GetComponentID(TStateMachineComponent2D);
   FSwimmerID := ComponentRegistry.GetComponentID(TSwimmerComponent);
   for E In GetMatchingEntities do
   begin
      FSM := TStateMachineComponent2D(E.GetComponentByID(FFSMID));
      if Not Assigned(FSM) then
      begin
         Continue;
      end;
      FSM.OnEnter := @OnPlayerEnterState;
      FSM.OnExit := @OnPlayerExitState;
   end;
end;

procedure TPlayerPhysicsSystem.Update(ADelta: Single);
begin
end;

procedure TPlayerPhysicsSystem.FixedUpdate(AFixedDelta: Single);
var
   E: TEntity;
   Tr: TTransformComponent;
   RB: TRigidBodyComponent;
   PC: TPlayerComponent;
   FSM: TStateMachineComponent2D;
   TargetSpeed, Accel, Fric: Single;
   InputDir: Integer;
   CanJump, IsUnderwater: Boolean;
begin
   for E In GetMatchingEntities do
   begin
      Tr := TTransformComponent(E.GetComponentByID(FTransformID));
      RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
      PC := TPlayerComponent(E.GetComponentByID(FPlayerID));
      FSM := TStateMachineComponent2D(E.GetComponentByID(FFSMID));

    { Determine if the player is in underwater mode }
      IsUnderwater := (FSwimmerID >= 0) And Assigned(E.GetComponentByID(FSwimmerID));

      if PC.State In [psDead, psVictory, psPipe] then
      begin
         if PC.State = psDead then
         begin
            Tr.Position.Y := Tr.Position.Y + RB.Velocity.Y * AFixedDelta;
            RB.Velocity.Y := RB.Velocity.Y + 980.0 * AFixedDelta;
         end;
         Continue;
      end;

    { Skip land-physics logic for underwater states (TSwimSystem handles them) }
      if IsUnderwater then
      begin
      { Horizontal movement still applies underwater (TSwimSystem doesn't override X) }
         InputDir := 0;
         if PC.WantsMoveLeft then
         begin
            InputDir := -1
         end;
         if PC.WantsMoveRight then
         begin
            InputDir := 1
         end;
         if InputDir <> 0 then
         begin
            if PC.WantsRun then
            begin
               TargetSpeed := PC.RunSpeed * 0.6
            end
            else
            begin
               TargetSpeed := PC.WalkSpeed * 0.6
            end;
            RB.Velocity.X := ApproachF(RB.Velocity.X, TargetSpeed * InputDir, ACCEL_AIR * AFixedDelta);
         end;
      { Kill zone check }
         if Tr.Position.Y > WATER_KILL_ZONE then
         begin
            Dec(PC.Lives);
            if PC.Lives > 0 then
            begin
               Tr.Position := Vector2Create(WATER_SPAWN_X, WATER_SPAWN_Y);
               RB.Velocity := Vector2Create(0, 0);
               RB.ForceAccum := Vector2Create(0, 0);
               PC.InvFrames := RESPAWN_INV_TIME;
               PC.State := psSwimIdle;
            end
            else
            begin
               SetState(PC, FSM, psDead)
            end;
         end;
         Continue;
      end;

    { ── Land physics ──────────────────────────────────────────────────────── }
      InputDir := 0;
      if PC.WantsMoveLeft then
      begin
         InputDir := -1
      end;
      if PC.WantsMoveRight then
      begin
         InputDir := 1
      end;
      if RB.Grounded And PC.WantsDuck then
      begin
         InputDir := 0
      end;
      if PC.WantsRun then
      begin
         TargetSpeed := PC.RunSpeed
      end
      else
      begin
         TargetSpeed := PC.WalkSpeed
      end;
      TargetSpeed := TargetSpeed * InputDir;
      if RB.Grounded then
      begin
         if (InputDir <> 0) And (Sign(RB.Velocity.X) <> InputDir) And (Abs(RB.Velocity.X) > SKID_THRESHOLD) then
         begin
            Accel := FRICTION_SKID
         end
         else
         if PC.WantsRun then
         begin
            Accel := ACCEL_RUN
         end
         else
         begin
            Accel := ACCEL_WALK
         end;
         Fric := IfThen(InputDir = 0, FRICTION_GND, 0);
      end
      else
      begin
         Accel := ACCEL_AIR;
         Fric := FRICTION_AIR;
      end;
      if InputDir <> 0 then
      begin
         RB.Velocity.X := ApproachF(RB.Velocity.X, TargetSpeed, Accel * AFixedDelta)
      end
      else
      begin
         RB.Velocity.X := ApproachF(RB.Velocity.X, 0, (FRICTION_GND + Fric) * AFixedDelta)
      end;

      CanJump := RB.Grounded Or (RB.CoyoteTimeLeft > 0);
      if CanJump And (PC.WantsJump Or (RB.JumpBufferLeft > 0)) then
      begin
         PC.WantsJump := False;
         RB.JumpBufferLeft := 0;
         RB.CoyoteTimeLeft := 0;
         RB.Grounded := False;
         RB.AddImpulse(Vector2Create(0, PC.JumpForce));
         if PC.WantsSpin then
         begin
            SetState(PC, FSM, psSpinJump);
            PC.WantsSpin := False;
         end
         else
         if Abs(RB.Velocity.X) > (PC.RunSpeed * 0.85) then
         begin
            SetState(PC, FSM, psRunJumping)
         end
         else
         begin
            SetState(PC, FSM, psJumping)
         end;
      end
      else
      if PC.WantsJump And Not CanJump then
      begin
         RB.RequestJump;
         PC.WantsJump := False;
      end
      else
      begin
         PC.WantsJump := False
      end;
      if PC.WantsJumpCut then
      begin
         if RB.Velocity.Y < -200 then
         begin
            RB.Velocity.Y := -200
         end;
         PC.WantsJumpCut := False;
      end;

      if RB.Grounded then
      begin
         if PC.WantsDuck then
         begin
            SetState(PC, FSM, psCrouching);
            RB.Velocity.X := ApproachF(RB.Velocity.X, 0, FRICTION_SKID * AFixedDelta);
         end
         else
         if (InputDir <> 0) And (Sign(RB.Velocity.X) <> InputDir) And (Abs(RB.Velocity.X) > SKID_THRESHOLD) then
         begin
            SetState(PC, FSM, psSkid)
         end
         else
         if Abs(RB.Velocity.X) > 10 then
         begin
            if PC.WantsRun then
            begin
               SetState(PC, FSM, psRunning)
            end
            else
            begin
               SetState(PC, FSM, psWalking)
            end;
         end
         else
         begin
            SetState(PC, FSM, psIdle)
         end;
      end
      else
      begin
         if PC.State = psSpinJump then
         begin
         end
         else
         if RB.Velocity.Y < 0 then
         begin
            if PC.State <> psRunJumping then
            begin
               SetState(PC, FSM, psJumping)
            end;
         end
         else
         begin
            SetState(PC, FSM, psFalling)
         end;
      end;

      if Tr.Position.Y > PLAYER_KILL_ZONE then
      begin
         Dec(PC.Lives);
         if PC.Lives > 0 then
         begin
            Tr.Position := Vector2Create(PLAYER_SPAWN_X, PLAYER_SPAWN_Y);
            RB.Velocity := Vector2Create(0, 0);
            RB.Acceleration := Vector2Create(0, 0);
            RB.ForceAccum := Vector2Create(0, 0);
            PC.InvFrames := RESPAWN_INV_TIME;
            SetState(PC, FSM, psIdle);
         end
         else
         begin
            SetState(PC, FSM, psDead)
         end;
      end;
   end;
end;

{ ═══ TPlayerAnimSystem ═══════════════════════════════════════════════════════ }
constructor TPlayerAnimSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);
   Priority := 8;
   Name := 'PlayerAnimSystem';
end;

procedure TPlayerAnimSystem.Init;
begin
   inherited;
   RequireComponent(TPlayerComponent);
   RequireComponent(TRigidBodyComponent);
   RequireComponent(TSpriteComponent);
   RequireComponent(TAnimationComponent);

   FPlayerID := ComponentRegistry.GetComponentID(TPlayerComponent);
   FRigidBodyID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
   FSpriteID := ComponentRegistry.GetComponentID(TSpriteComponent);
   FAnimID := ComponentRegistry.GetComponentID(TAnimationComponent);
end;

procedure TPlayerAnimSystem.Update(ADelta: Single);
var
   E: TEntity;
   PC: TPlayerComponent;
   RB: TRigidBodyComponent;
   Spr: TSpriteComponent;
   Anim: TAnimationComponent;
begin
   for E In GetMatchingEntities do
   begin
      PC := TPlayerComponent(E.GetComponentByID(FPlayerID));
      RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
      Spr := TSpriteComponent(E.GetComponentByID(FSpriteID));
      Anim := TAnimationComponent(E.GetComponentByID(FAnimID));
      if PC.State <> psDead then
      begin
         if PC.State = psSkid then
	        begin
            if RB.Velocity.X > 0 then
			         begin
               Spr.Flip := flNone
            end
		          else
            if RB.Velocity.X < 0 then
			         begin
               Spr.Flip := flHorizontal
            end;
         end
	        else
	        begin
            if PC.WantsMoveLeft then
			         begin
               Spr.Flip := flHorizontal
            end
            else
            if PC.WantsMoveRight then
			         begin
               Spr.Flip := flNone
            end
            else
            if Abs(RB.Velocity.X) > 1 then
		          begin
			            if RB.Velocity.X < 0 then
				           begin
                  Spr.Flip := flHorizontal
               end
			            else
				           begin
                  Spr.Flip := flNone
               end;
		          end;
         end;
      end;
      case PC.State of
         psIdle:
         begin
            Anim.Play('idle')
         end;
         psWalking:
         begin
            Anim.Play('walk')
         end;
         psRunning:
         begin
            Anim.Play('run')
         end;
         psSkid:
         begin
            Anim.Play('skid')
         end;
         psCrouching:
         begin
            Anim.Play('duck')
         end;
         psJumping:
         begin
            Anim.Play('jump')
         end;
         psRunJumping:
         begin
            Anim.Play('run_jump')
         end;
         psSpinJump:
         begin
            Anim.Play('spin')
         end;
         psFalling:
         begin
            Anim.Play('fall')
         end;
         psVictory:
         begin
            Anim.Play('victory')
         end;
         psPipe:
         begin
            Anim.Play('pipe')
         end;
         psDead:
         begin
            Anim.Play('dead')
         end;
      { Underwater states }
         psSwimIdle:
         begin
            Anim.Play('swim_idle')
         end;
         psSwimming:
         begin
            Anim.Play('swimming')
         end;
      end;
   end;
end;

end.
