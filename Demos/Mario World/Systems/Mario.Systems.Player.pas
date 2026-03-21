unit Mario.Systems.Player;

{$mode objfpc}{$H+}

{ ── Player systems with FSM integration ──────────────────────────────────────

  DESIGN: Two-track state management
  ────────────────────────────────────
  TPlayerComponent.State  — immediate authoritative state.
                            Written directly in FixedUpdate so that physics
                            logic within the SAME step can read the new value.
                            Drives TPlayerAnimSystem without any frame delay.

  TStateMachineComponent2D — lifecycle FSM.
                            RequestTransition() is called alongside every
                            State assignment. TStateMachineSystem2D.Update
                            (priority 6) processes pending transitions AFTER
                            FixedUpdate completes (inside TWorld.Update), so
                            OnEnter/OnExit fire once per variable frame.
                            Used to publish audio/event side-effects
                            (TPlayerJumpEvent, TPlayerDiedEvent, etc.) in one
                            clean, central place.

  This avoids duplicating event-publish logic across multiple FixedUpdate
  branches while keeping PC.State immediately consistent for logic reads.
  ─────────────────────────────────────────────────────────────────────────── }

interface

uses
  SysUtils, Math, raylib,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Core.ComponentRegistry,
  P2D.Components.Transform, P2D.Components.RigidBody,
  P2D.Components.Sprite, P2D.Components.Animation,
  P2D.Components.InputMap, P2D.Components.Collider,
  P2D.Components.StateMachine,
  P2D.Utils.Math,
  Mario.Common, Mario.Components.Player;

type
  { ─────────────────────────────────────────────────────────────────────────
    TPlayerPhysicsSystem — FixedUpdate physics + state transitions
    ───────────────────────────────────────────────────────────────────────── }
  TPlayerPhysicsSystem = class(TSystem2D)
  private
    FTransformID: Integer;
    FRigidBodyID: Integer;
    FPlayerID   : Integer;
    FFSMID      : Integer;

    { Helper: sets PC.State (immediate) AND requests the FSM transition
      (for lifecycle callbacks on the next Update frame). }
    procedure SetState(PC: TPlayerComponent; FSM: TStateMachineComponent2D;
                       AState: TPlayerState); inline;

    { ── FSM lifecycle callbacks ── }
    procedure OnPlayerEnterState(AEntityID: Cardinal; AStateID: TStateID);
    procedure OnPlayerExitState (AEntityID: Cardinal; AStateID: TStateID);
  public
    constructor Create(AWorld: TWorldBase); override;
    procedure Init; override;
    procedure Update(ADelta: Single); override;
    procedure FixedUpdate(AFixedDelta: Single); override;
  end;

  { ─────────────────────────────────────────────────────────────────────────
    TPlayerAnimSystem — maps TPlayerState → animation clip
    ───────────────────────────────────────────────────────────────────────── }
  TPlayerAnimSystem = class(TSystem2D)
  private
    FPlayerID: Integer;
    FRigidBodyID: Integer;
    FSpriteID: Integer;
    FAnimID  : Integer;
  public
    constructor Create(AWorld: TWorldBase); override;
    procedure Init; override;
    procedure Update(ADelta: Single); override;
  end;

implementation

uses
  Mario.Events, P2D.Core.InputManager;

{ ═══════════════════════════════════════════════════════════════════════════
  TPlayerPhysicsSystem
  ═══════════════════════════════════════════════════════════════════════════ }
constructor TPlayerPhysicsSystem.Create(AWorld: TWorldBase);
begin
  inherited Create(AWorld);
  Priority := 7;
  Name     := 'PlayerPhysicsSystem';
end;

procedure TPlayerPhysicsSystem.SetState(PC: TPlayerComponent;
                                         FSM: TStateMachineComponent2D;
                                         AState: TPlayerState);
begin
  PC.State := AState;                         { immediate — readable same step }
  if Assigned(FSM) then
    FSM.RequestTransition(Ord(AState));        { lifecycle callbacks next frame }
end;

{ ── FSM OnEnter: publishes audio/game events when a state is entered ──── }
procedure TPlayerPhysicsSystem.OnPlayerEnterState(AEntityID: Cardinal;
                                                   AStateID: TStateID);
var
  E  : TEntity;
  PC : TPlayerComponent;
  RB : TRigidBodyComponent;
begin
  E := World.GetEntity(AEntityID);
  if not Assigned(E) or not E.Alive then Exit;

  PC := TPlayerComponent(E.GetComponentByID(FPlayerID));
  if not Assigned(PC) then Exit;

  case TPlayerState(AStateID) of
    psJumping, psRunJumping:
      World.EventBus.Publish(TPlayerJumpEvent.Create);

    psSpinJump:
      World.EventBus.Publish(TPlayerSpinEvent.Create);

    psDead:
    begin
      { Death hop — velocity is set here (in the lifecycle callback) rather
        than in FixedUpdate, so it happens exactly once regardless of how
        many FixedUpdate steps ran this frame. }
      RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
      if Assigned(RB) then
        RB.Velocity := Vector2Create(0, -400);
      World.EventBus.Publish(TPlayerDiedEvent.Create);
    end;
  end;
end;

procedure TPlayerPhysicsSystem.OnPlayerExitState(AEntityID: Cardinal;
                                                   AStateID: TStateID);
begin
  { Extend here to add cleanup when leaving specific states, e.g.:
      psSpinJump → cancel spin-jump SFX loop
      psInvincible → reset tint }
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

  { Attach lifecycle callbacks to the player entity.
    LoadLevel ran before World.Init, so the player entity exists here. }
  for E in GetMatchingEntities do
  begin
    FSM := TStateMachineComponent2D(E.GetComponentByID(FFSMID));
    if not Assigned(FSM) then Continue;
    FSM.OnEnter := @OnPlayerEnterState;
    FSM.OnExit  := @OnPlayerExitState;
  end;
end;

procedure TPlayerPhysicsSystem.Update(ADelta: Single);
begin
  { All player movement logic is in FixedUpdate. }
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
begin
  for E in GetMatchingEntities do
  begin
    Tr  := TTransformComponent(E.GetComponentByID(FTransformID));
    RB  := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
    PC  := TPlayerComponent(E.GetComponentByID(FPlayerID));
    FSM := TStateMachineComponent2D(E.GetComponentByID(FFSMID));

    { ── Dead / special states: minimal physics only ───────────────────── }
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
    if PC.WantsMoveLeft  then InputDir := -1;
    if PC.WantsMoveRight then InputDir :=  1;
    if RB.Grounded and PC.WantsDuck then InputDir := 0;

    { ── Horizontal movement ────────────────────────────────────────────── }
    if PC.WantsRun then TargetSpeed := PC.RunSpeed
    else                TargetSpeed := PC.WalkSpeed;
    TargetSpeed := TargetSpeed * InputDir;

    if RB.Grounded then
    begin
      if (InputDir <> 0) and (Sign(RB.Velocity.X) <> InputDir) and
         (Abs(RB.Velocity.X) > SKID_THRESHOLD) then
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

    { ── Jump ───────────────────────────────────────────────────────────── }
    if PC.WantsJump and RB.Grounded then
    begin
      RB.Velocity.Y := PC.JumpForce;
      RB.Grounded   := False;

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
      PC.WantsJump := False;
    end;

    if PC.WantsJumpCut then
    begin
      if RB.Velocity.Y < -200 then RB.Velocity.Y := -200;
      PC.WantsJumpCut := False;
    end;

    { ── Grounded state machine ─────────────────────────────────────────── }
    if RB.Grounded then
    begin
      if PC.WantsDuck then
      begin
        SetState(PC, FSM, psCrouching);
        RB.Velocity.X := ApproachF(RB.Velocity.X, 0, FRICTION_SKID * AFixedDelta);
      end
      else if (InputDir <> 0) and (Sign(RB.Velocity.X) <> InputDir) and
              (Abs(RB.Velocity.X) > SKID_THRESHOLD) then
        SetState(PC, FSM, psSkid)
      else if Abs(RB.Velocity.X) > 10.0 then
      begin
        if PC.WantsRun then SetState(PC, FSM, psRunning)
        else                SetState(PC, FSM, psWalking);
      end
      else
        SetState(PC, FSM, psIdle);
    end
    else
    begin
      { Airborne }
      if PC.State = psSpinJump then
        { Stay in spin — no transition needed. }
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
        Tr.Position := Vector2Create(PLAYER_SPAWN_X, PLAYER_SPAWN_Y);
        RB.Velocity := Vector2Create(0, 0);
        RB.Acceleration := Vector2Create(0, 0);
        PC.InvFrames := RESPAWN_INV_TIME;
        SetState(PC, FSM, psIdle);
      end
      else
        SetState(PC, FSM, psDead);
        { OnPlayerEnterState(psDead) sets RB.Velocity for the death hop
          and publishes TPlayerDiedEvent — no extra code needed here. }
    end;
  end;
end;

{ ═══════════════════════════════════════════════════════════════════════════
  TPlayerAnimSystem — unchanged logic, reads PC.State which is kept in sync
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

    { Facing direction }
    if PC.State <> psDead then
    begin
      if PC.State = psSkid then
      begin
        if RB.Velocity.X > 0 then Spr.Flip := flNone
        else if RB.Velocity.X < 0 then Spr.Flip := flHorizontal;
      end
      else
      begin
        if PC.WantsMoveLeft then Spr.Flip := flHorizontal
        else if PC.WantsMoveRight then Spr.Flip := flNone
        else if Abs(RB.Velocity.X) > 1.0 then
        begin
          if RB.Velocity.X < 0 then Spr.Flip := flHorizontal
          else                       Spr.Flip := flNone;
        end;
      end;
    end;

    { Animation clip selection — reads PC.State (synced by SetState helper) }
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

