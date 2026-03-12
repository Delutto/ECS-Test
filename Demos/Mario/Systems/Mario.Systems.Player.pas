unit Mario.Systems.Player;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Components.Transform, P2D.Components.RigidBody, P2D.Components.Sprite, P2D.Components.Animation,
   P2D.Components.Tags, P2D.Components.InputMap, P2D.Components.Collider, P2D.Components.TileMap,
   P2D.Utils.Math, Mario.Common, Mario.Components.Player;

type
   TPlayerPhysicsSystem = class(TSystem2D)
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure FixedUpdate(AFixedDelta: Single); override;
   end;

   TPlayerAnimSystem = class(TSystem2D)
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

procedure TPlayerPhysicsSystem.Init;
begin
   inherited;
   RequireComponent(TPlayerTag);
   RequireComponent(TTransformComponent);
   RequireComponent(TRigidBodyComponent);
   RequireComponent(TPlayerComponent);
end;

procedure TPlayerPhysicsSystem.Update(ADelta: Single);
begin
   // Empty - Physics runs in FixedUpdate
end;

procedure TPlayerPhysicsSystem.FixedUpdate(AFixedDelta: Single);
var
   E    : TEntity;
   Tr   : TTransformComponent;
   RB   : TRigidBodyComponent;
   PC   : TPlayerComponent;
   TargetSpeed, Accel, Fric: Single;
   InputDir: Integer;
begin
   for E in GetMatchingEntities do
   begin
      //if not E.Alive then
      //   Continue;

      Tr := TTransformComponent(E.GetComponent(TTransformComponent));
      RB := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
      PC := TPlayerComponent(E.GetComponent(TPlayerComponent));

      if PC.State in [psDead, psVictory, psPipe] then
      begin
         // Minimal physics for dead state (gravity only)
         if PC.State = psDead then
         begin
            Tr.Position.Y := Tr.Position.Y + RB.Velocity.Y * AFixedDelta;
            RB.Velocity.Y := RB.Velocity.Y + 980.0 * AFixedDelta;
         end;
         Continue;
      end;

      { ── Input Direction ────────────────────────────────────────────────── }
      InputDir := 0;
      if PC.WantsMoveLeft then
         InputDir := -1;
      if PC.WantsMoveRight then
         InputDir := 1;
      // Prevent moving if crouching (unless in air)
      if RB.Grounded and PC.WantsDuck then
         InputDir := 0;

      { ── Horizontal Movement ────────────────────────────────────────────── }
      if PC.WantsRun then
         TargetSpeed := PC.RunSpeed
      else
         TargetSpeed := PC.WalkSpeed;
      TargetSpeed := TargetSpeed * InputDir;

      if RB.Grounded then
      begin
         if (InputDir <> 0) and (Sign(RB.Velocity.X) <> InputDir) and (Abs(RB.Velocity.X) > SKID_THRESHOLD) then
            Accel := FRICTION_SKID // Skidding
         else if PC.WantsRun then
            Accel := ACCEL_RUN
         else
            Accel := ACCEL_WALK;

         // Higher friction when stopping
         if InputDir = 0 then
            Fric := FRICTION_GND
         else
            Fric := 0;
      end
      else
      begin
         Accel := ACCEL_AIR;
         Fric  := FRICTION_AIR;
      end;

      // Apply horizontal force
      if InputDir <> 0 then
         RB.Velocity.X := ApproachF(RB.Velocity.X, TargetSpeed, Accel * AFixedDelta)
      else
         RB.Velocity.X := ApproachF(RB.Velocity.X, 0, (FRICTION_GND + Fric) * AFixedDelta);

      { ── Jump Logic ─────────────────────────────────────────────────────── }
      if PC.WantsJump and RB.Grounded then
      begin
         RB.Velocity.Y := PC.JumpForce;
         RB.Grounded   := False;

         if PC.WantsSpin then
         begin
            PC.State := psSpinJump;
            World.EventBus.Publish(TPlayerSpinEvent.Create);
         end
         else
         begin
            if Abs(RB.Velocity.X) > (PC.RunSpeed * 0.85) then
               PC.State := psRunJumping
            else
               PC.State := psJumping;
            World.EventBus.Publish(TPlayerJumpEvent.Create);
         end;

         PC.WantsJump := False; // Consume input
         PC.WantsSpin := False;
      end;

      // Variable jump height (Jump Cut)
      if PC.WantsJumpCut then
      begin
         if RB.Velocity.Y < -200 then
            RB.Velocity.Y := -200;
         PC.WantsJumpCut := False;
      end;

      { ── State Machine ──────────────────────────────────────────────────── }
      if RB.Grounded then
      begin
         if PC.WantsDuck then
         begin
            PC.State := psCrouching;
            RB.Velocity.X := ApproachF(RB.Velocity.X, 0, FRICTION_SKID * AFixedDelta);
         end
         else if (InputDir <> 0) and (Sign(RB.Velocity.X) <> InputDir) and (Abs(RB.Velocity.X) > SKID_THRESHOLD) then
            PC.State := psSkid
         else if Abs(RB.Velocity.X) > 10.0 then
         begin
            if PC.WantsRun then
               PC.State := psRunning
            else
               PC.State := psWalking;
         end
         else
            PC.State := psIdle;
      end
      else // Airborne
      begin
         // Preserve SpinJump state if we are already in it
         if PC.State = psSpinJump then
         begin
            // Spin jump logic implies we stay in this state until grounded
         end
         else if RB.Velocity.Y < 0 then
         begin
            if PC.State <> psRunJumping then // Preserve RunJump animation
               PC.State := psJumping;
         end
         else
            PC.State := psFalling;
      end;

      { ── Kill Zone ──────────────────────────────────────────────────────── }
      if Tr.Position.Y > PLAYER_KILL_ZONE then
      begin
         Dec(PC.Lives);
         if PC.Lives > 0 then
         begin
            // Respawn
            Tr.Position := Vector2Create(PLAYER_SPAWN_X, PLAYER_SPAWN_Y);
            RB.Velocity := Vector2Create(0, 0);
            RB.Acceleration := Vector2Create(0, 0);
            PC.InvFrames := RESPAWN_INV_TIME;
            PC.State := psIdle;
         end
         else
         begin
            // Game Over
            PC.State := psDead;
            RB.Velocity := Vector2Create(0, -400); // Death hop
            World.EventBus.Publish(TPlayerDiedEvent.Create);
         end;
      end;
   end;
end;

{ TPlayerAnimSystem }

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
      //if not E.Alive then
      //   Continue;
      PC   := TPlayerComponent(E.GetComponent(TPlayerComponent));
      RB   := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
      Spr  := TSpriteComponent(E.GetComponent(TSpriteComponent));
      Anim := TAnimationComponent(E.GetComponent(TAnimationComponent));

      // Handle Facing Direction
      if PC.State <> psDead then
      begin
         // If skidding, we face the direction we are MOVING (to show the "braking" animation correctly)
         // or we face the INPUT? In SMW, Mario looks at the screen while skidding.
         // Usually, if Input is Left and Velocity is Right -> Skid. Sprite should face Right (Velocity).
         if PC.State = psSkid then
         begin
            if RB.Velocity.X > 0 then Spr.Flip := flNone
            else if RB.Velocity.X < 0 then Spr.Flip := flHorizontal;
         end
         else
         begin
            // Normal facing based on input or velocity
            if PC.WantsMoveLeft then Spr.Flip := flHorizontal
            else if PC.WantsMoveRight then Spr.Flip := flNone
            else if Abs(RB.Velocity.X) > 1.0 then
            begin
               if RB.Velocity.X < 0 then Spr.Flip := flHorizontal else Spr.Flip := flNone;
            end;
         end;
      end;

      case PC.State of
         psIdle      : Anim.Play('idle');
         psWalking   : Anim.Play('walk');
         psRunning   : Anim.Play('run');
         psSkid      : Anim.Play('skid');
         psCrouching : Anim.Play('duck');
         psJumping   : Anim.Play('jump');
         psRunJumping: Anim.Play('run_jump');
         psSpinJump  : Anim.Play('spin');
         psFalling   : Anim.Play('fall');
         psVictory   : Anim.Play('victory');
         psPipe      : Anim.Play('pipe');
         psDead      : Anim.Play('dead');
      end;
   end;
end;

end.
