unit Mario.Systems.GameRules;

{$mode objfpc}{$H+}

{ ── Game rules: collision resolution with FSM-aware enemy stomp ─────────────
  The only change from the previous version is in HandleEnemyCollision:
    BEFORE: World.DestroyEntity(AEnemy.ID)
    AFTER:  FSM.RequestTransition(Ord(gsStomped))  (if enemy has an FSM)
            fallback to DestroyEntity for enemies without an FSM.
  ─────────────────────────────────────────────────────────────────────────── }

interface

uses
  SysUtils, raylib, Math,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Core.Event, P2D.Core.Events,
  P2D.Components.Transform, P2D.Components.RigidBody, P2D.Components.Collider, P2D.Components.StateMachine,
  Mario.Events, Mario.Components.Player, Mario.Components.Enemy;

type
  TGameRulesSystem = class(TSystem2D)
  private
    function ResolvePlayer(const AEv: TEntityOverlapEvent; out APlayer, AOther: TEntity; out APlayerTag, AOtherTag: TColliderTag): Boolean;
    procedure HandleCoinPickup(APlayer, ACoin: TEntity);
    procedure HandleEnemyCollision(APlayer, AEnemy: TEntity);
    procedure OnEntityOverlap(AEvent: TEvent2D);
  public
    constructor Create(AWorld: TWorldBase); override;
    procedure Init; override;
    procedure Shutdown; override;
    procedure Update(ADelta: Single); override;
  end;

implementation

constructor TGameRulesSystem.Create(AWorld: TWorldBase);
begin
  inherited Create(AWorld);

  Priority := 25;
  Name     := 'GameRulesSystem';
end;

procedure TGameRulesSystem.Init;
begin
  inherited;
  World.EventBus.Subscribe(TEntityOverlapEvent, @OnEntityOverlap);
end;

procedure TGameRulesSystem.Shutdown;
begin
  World.EventBus.Unsubscribe(TEntityOverlapEvent, @OnEntityOverlap);
  inherited;
end;

procedure TGameRulesSystem.Update(ADelta: Single);
begin

end;

function TGameRulesSystem.ResolvePlayer(const AEv: TEntityOverlapEvent; out APlayer, AOther: TEntity; out APlayerTag, AOtherTag: TColliderTag): Boolean;
begin
  Result := False;
  APlayer := nil;
  AOther := nil;
  if AEv.TagA = ctPlayer then
  begin
    APlayer    := World.GetEntity(AEv.EntityAID);
    AOther     := World.GetEntity(AEv.EntityBID);
    APlayerTag := AEv.TagA; AOtherTag := AEv.TagB;
    Result := Assigned(APlayer) and Assigned(AOther) and APlayer.Alive and AOther.Alive;
  end
  else if AEv.TagB = ctPlayer then
  begin
    APlayer    := World.GetEntity(AEv.EntityBID);
    AOther     := World.GetEntity(AEv.EntityAID);
    APlayerTag := AEv.TagB; AOtherTag := AEv.TagA;
    Result := Assigned(APlayer) and Assigned(AOther) and APlayer.Alive and AOther.Alive;
  end;
end;

procedure TGameRulesSystem.HandleCoinPickup(APlayer, ACoin: TEntity);
var
  PC  : TPlayerComponent;
  TrC : TTransformComponent;
begin
  if not ACoin.HasComponent(TCoinTag) then
    Exit;
  PC := TPlayerComponent(APlayer.GetComponent(TPlayerComponent));
  if not Assigned(PC) then
    Exit;
  TrC := TTransformComponent(ACoin.GetComponent(TTransformComponent));
  Inc(PC.Coins);
  PC.Score := PC.Score + 200;
  World.DestroyEntity(ACoin.ID);
  World.EventBus.Publish(TCoinCollectedEvent.Create(PC.Coins, PC.Score, IfThen(Assigned(TrC), TrC.Position.X + 8, 0), IfThen(Assigned(TrC), TrC.Position.Y,     0)));
end;

procedure TGameRulesSystem.HandleEnemyCollision(APlayer, AEnemy: TEntity);
var
  PC: TPlayerComponent;
  RBP: TRigidBodyComponent;
  TrP: TTransformComponent;
  TrE: TTransformComponent;
  ColE: TColliderComponent;
  FSM: TStateMachineComponent2D;
  EnemyRect: TRectF;
begin
  PC   := TPlayerComponent(APlayer.GetComponent(TPlayerComponent));
  RBP  := TRigidBodyComponent(APlayer.GetComponent(TRigidBodyComponent));
  TrP  := TTransformComponent(APlayer.GetComponent(TTransformComponent));
  TrE  := TTransformComponent(AEnemy.GetComponent(TTransformComponent));
  ColE := TColliderComponent(AEnemy.GetComponent(TColliderComponent));
  if not (Assigned(PC) and Assigned(RBP) and Assigned(TrP) and Assigned(TrE) and Assigned(ColE)) then
    Exit;
  if PC.State = psDead then
    Exit;

  { Skip if enemy is already in the stomped state. }
  FSM := TStateMachineComponent2D(AEnemy.GetComponent(TStateMachineComponent2D));
  if Assigned(FSM) and (TGoombaState(FSM.CurrentState) = gsStomped) then
    Exit;

  EnemyRect := ColE.GetWorldRect(TrE.Position);

  if (RBP.Velocity.Y > 0) and (TrP.Position.Y + 14 < TrE.Position.Y + EnemyRect.H * 0.5) then
  begin
    { ── Stomp ──────────────────────────────────────────────────────────── }
    PC.Score       := PC.Score + 100;
    RBP.Velocity.Y := -350.0;    { bounce }

    if Assigned(FSM) then
      { FSM transition → TEnemySystem.OnGoombaEnterStomped handles visuals,
        freeze, and lifetime countdown. No direct DestroyEntity needed. }
      FSM.RequestTransition(Ord(gsStomped))
    else
      { Fallback for enemies that don't carry a FSM component. }
      World.DestroyEntity(AEnemy.ID);

    World.EventBus.Publish(
      TEnemyStompedEvent.Create(100, PC.Score, TrE.Position.X + 8, TrE.Position.Y - 8));
  end
  else
  begin
    { ── Player takes damage ─────────────────────────────────────────────── }
    if PC.InvFrames > 0 then
	  Exit;
    Dec(PC.Lives);
    PC.InvFrames := 2.0;
    World.EventBus.Publish(TPlayerDamagedEvent.Create(PC.Lives));
    if PC.Lives <= 0 then
      PC.State := psDead;
  end;
end;

procedure TGameRulesSystem.OnEntityOverlap(AEvent: TEvent2D);
var
  Ev: TEntityOverlapEvent;
  Player, Other: TEntity;
  PlayerTag, OtherTag: TColliderTag;
begin
  Ev := TEntityOverlapEvent(AEvent);
  if not ResolvePlayer(Ev, Player, Other, PlayerTag, OtherTag) then
    Exit;
  case OtherTag of
    ctCoin  : HandleCoinPickup(Player, Other);
    ctEnemy : HandleEnemyCollision(Player, Other);
  end;
end;

end.
