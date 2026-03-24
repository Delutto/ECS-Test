unit Mario.Systems.GameRules;

{$mode objfpc}
{$H+}

interface

uses
   SysUtils,
   raylib,
   Math,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Core.Event,
   P2D.Core.Events,
   P2D.Components.Transform,
   P2D.Components.RigidBody,
   P2D.Components.Collider,
   P2D.Components.StateMachine,
   Mario.Events,
   Mario.Components.Player,
   Mario.Components.Enemy;

type
   TGameRulesSystem = class(TSystem2D)
   private
      function ResolvePlayer(const AEv: TEntityOverlapEvent; out APlayer, AOther: TEntity; out APlayerTag, AOtherTag: TColliderTag): Boolean;
      procedure HandleCoinPickup(APlayer, ACoin: TEntity);
      procedure HandleEnemyCollision(APlayer, AEnemy: TEntity);
      procedure HandleGoalReached(APlayer, AGoal: TEntity);   { ← NEW }
      procedure OnEntityOverlap(AEvent: TEvent2D);
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Shutdown; override;
      procedure Update(ADelta: Single); override;
   end;

implementation

uses
   Mario.Components.Swimmer;

constructor TGameRulesSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);
   Priority := 25;
   Name := 'GameRulesSystem';
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
      APlayer := World.GetEntity(AEv.EntityAID);
      AOther := World.GetEntity(AEv.EntityBID);
      APlayerTag := AEv.TagA;
      AOtherTag := AEv.TagB;
      Result := Assigned(APlayer) And Assigned(AOther) And APlayer.Alive And AOther.Alive;
   end
   else
   if AEv.TagB = ctPlayer then
   begin
      APlayer := World.GetEntity(AEv.EntityBID);
      AOther := World.GetEntity(AEv.EntityAID);
      APlayerTag := AEv.TagB;
      AOtherTag := AEv.TagA;
      Result := Assigned(APlayer) And Assigned(AOther) And APlayer.Alive And AOther.Alive;
   end;
end;

procedure TGameRulesSystem.HandleCoinPickup(APlayer, ACoin: TEntity);
var
   PC: TPlayerComponent;
   TrC: TTransformComponent;
begin
   if Not ACoin.HasComponent(TCoinTag) then
   begin
      Exit
   end;
   PC := TPlayerComponent(APlayer.GetComponent(TPlayerComponent));
   if Not Assigned(PC) then
   begin
      Exit
   end;
   TrC := TTransformComponent(ACoin.GetComponent(TTransformComponent));
   Inc(PC.Coins);
   PC.Score := PC.Score + 200;
   World.DestroyEntity(ACoin.ID);
   World.EventBus.Publish(TCoinCollectedEvent.Create(PC.Coins, PC.Score,
      IfThen(Assigned(TrC), TrC.Position.X + 8, 0),
      IfThen(Assigned(TrC), TrC.Position.Y, 0)));
end;

procedure TGameRulesSystem.HandleEnemyCollision(APlayer, AEnemy: TEntity);
var
   PC: TPlayerComponent;
   RBP: TRigidBodyComponent;
   TrP, TrE: TTransformComponent;
   ColE: TColliderComponent;
   FSM: TStateMachineComponent2D;
   EnemyRect: TRectF;
begin
   PC := TPlayerComponent(APlayer.GetComponent(TPlayerComponent));
   RBP := TRigidBodyComponent(APlayer.GetComponent(TRigidBodyComponent));
   TrP := TTransformComponent(APlayer.GetComponent(TTransformComponent));
   TrE := TTransformComponent(AEnemy.GetComponent(TTransformComponent));
   ColE := TColliderComponent(AEnemy.GetComponent(TColliderComponent));
   if Not (Assigned(PC) And Assigned(RBP) And Assigned(TrP) And Assigned(TrE) And Assigned(ColE)) then
   begin
      Exit
   end;
   if PC.State = psDead then
   begin
      Exit
   end;
   FSM := TStateMachineComponent2D(AEnemy.GetComponent(TStateMachineComponent2D));
   if Assigned(FSM) And (TGoombaState(FSM.CurrentState) = gsStomped) then
   begin
      Exit
   end;
   EnemyRect := ColE.GetWorldRect(TrE.Position);
   if (RBP.Velocity.Y > 0) And (TrP.Position.Y + 14 < TrE.Position.Y + EnemyRect.H * 0.5) then
   begin
      PC.Score := PC.Score + 100;
      RBP.Velocity.Y := -350.0;
      if Assigned(FSM) then
      begin
         FSM.RequestTransition(Ord(gsStomped))
      end
      else
      begin
         World.DestroyEntity(AEnemy.ID)
      end;
      World.EventBus.Publish(TEnemyStompedEvent.Create(100, PC.Score, TrE.Position.X + 8, TrE.Position.Y - 8));
   end
   else
   begin
      if PC.InvFrames > 0 then
      begin
         Exit
      end;
      Dec(PC.Lives);
      PC.InvFrames := 2.0;
      World.EventBus.Publish(TPlayerDamagedEvent.Create(PC.Lives));
      if PC.Lives <= 0 then
      begin
         PC.State := psDead
      end;
   end;
end;

{ ── HandleGoalReached — destroys goal and fires TLevelCompleteEvent ──────── }
procedure TGameRulesSystem.HandleGoalReached(APlayer, AGoal: TEntity);
var
   PC: TPlayerComponent;
   Tr: TTransformComponent;
   LevelNum: Integer;
begin
   PC := TPlayerComponent(APlayer.GetComponent(TPlayerComponent));
   if Not Assigned(PC) Or (PC.State = psDead) then
   begin
      Exit
   end;
   Tr := TTransformComponent(AGoal.GetComponent(TTransformComponent));
   World.DestroyEntity(AGoal.ID);
  { Score bonus for completing the level }
   PC.Score := PC.Score + 1000;
  { Infer which level we are in from the player's physics context:
    if the player has a TSwimmerComponent it's level 2, otherwise level 1. }
   if APlayer.HasComponent(TSwimmerComponent) then
   begin
      LevelNum := 2
   end
   else
   begin
      LevelNum := 1
   end;
   World.EventBus.Publish(TLevelCompleteEvent.Create(LevelNum));
end;

procedure TGameRulesSystem.OnEntityOverlap(AEvent: TEvent2D);
var
   Ev: TEntityOverlapEvent;
   Player, Other: TEntity;
   PlayerTag, OtherTag: TColliderTag;
begin
   Ev := TEntityOverlapEvent(AEvent);
   if Not ResolvePlayer(Ev, Player, Other, PlayerTag, OtherTag) then
   begin
      Exit
   end;
   case OtherTag of
      ctCoin:
      begin
         HandleCoinPickup(Player, Other)
      end;
      ctEnemy:
      begin
         HandleEnemyCollision(Player, Other)
      end;
      ctGoal:
      begin
         HandleGoalReached(Player, Other)
      end;     { ← NEW }
   end;
end;

end.
