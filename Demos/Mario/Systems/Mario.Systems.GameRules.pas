unit Mario.Systems.GameRules;

{$mode objfpc}{$H+}

{ ── Regras de jogo do demo Mario ────────────────────────────────────────────
  Subscreve TEntityOverlapEvent (evento genérico da engine) e implementa
  toda a lógica específica do Mario: coleta de moedas, dano de inimigos,
  mecânica de pular em cima do inimigo.

  Este sistema é o único ponto do demo que traduz eventos físicos genéricos
  em consequências de jogo. A engine não tem conhecimento algum deste código.
  ─────────────────────────────────────────────────────────────────────────── }

interface

uses
   SysUtils, raylib,
   P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Core.Event, P2D.Core.Events,
   P2D.Components.Transform, P2D.Components.RigidBody,
   P2D.Components.Collider, P2D.Components.Tags,
   Mario.Events;

type
   TGameRulesSystem = class(TSystem2D)
   private
      { Resolve qual entidade é o jogador e qual é a outra no par do evento, independente da ordem A/B em que chegaram no TEntityOverlapEvent. }
      function ResolvePlayer(const AEv: TEntityOverlapEvent; out APlayer: TEntity; out AOther: TEntity; out APlayerTag: TColliderTag; out AOtherTag: TColliderTag): Boolean;

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

   { Prioridade alta para processar regras antes de outros handlers.
     Roda após TCollisionSystem (20) mas antes de sistemas visuais. }
   Priority := 25;
   Name     := 'GameRulesSystem';
end;

procedure TGameRulesSystem.Init;
begin
   inherited;

   { Subscreve o evento GENÉRICO da engine — sem dependência circular }
   World.EventBus.Subscribe(TEntityOverlapEvent, @OnEntityOverlap);
end;

procedure TGameRulesSystem.Shutdown;
begin
   World.EventBus.Unsubscribe(TEntityOverlapEvent, @OnEntityOverlap);

   inherited;
end;

procedure TGameRulesSystem.Update(ADelta: Single);
begin
   { Lógica de update deste sistema roda via OnEntityOverlap (evento).
     Update permanece vazio intencionalmente. }
end;

{ ── Helpers ─────────────────────────────────────────────────────────────── }

function TGameRulesSystem.ResolvePlayer(const AEv: TEntityOverlapEvent; out APlayer: TEntity; out AOther: TEntity; out APlayerTag: TColliderTag; out AOtherTag: TColliderTag): Boolean;
begin
   Result := False;
   APlayer := nil; AOther := nil;

   if AEv.TagA = ctPlayer then
   begin
      APlayer    := World.GetEntity(AEv.EntityAID);
      AOther     := World.GetEntity(AEv.EntityBID);
      APlayerTag := AEv.TagA;
      AOtherTag  := AEv.TagB;
      Result := Assigned(APlayer) and Assigned(AOther) and APlayer.Alive and AOther.Alive;
   end
   else
      if AEv.TagB = ctPlayer then
      begin
         APlayer    := World.GetEntity(AEv.EntityBID);
         AOther     := World.GetEntity(AEv.EntityAID);
         APlayerTag := AEv.TagB;
         AOtherTag  := AEv.TagA;
         Result := Assigned(APlayer) and Assigned(AOther) and APlayer.Alive and AOther.Alive;
      end;
end;

{ ── Regras de Coleta de Moeda ────────────────────────────────────────────── }

procedure TGameRulesSystem.HandleCoinPickup(APlayer, ACoin: TEntity);
var
   PC: TPlayerComponent;
begin
   if not ACoin.HasComponent(TCoinTag) then
      Exit;

   PC := TPlayerComponent(APlayer.GetComponent(TPlayerComponent));
   if not Assigned(PC) then
      Exit;

   Inc(PC.Coins);
   PC.Score := PC.Score + 200;

   World.DestroyEntity(ACoin.ID);

   { Publica evento de jogo — HUD e AudioSystem podem reagir }
   World.EventBus.Publish(TCoinCollectedEvent.Create(PC.Coins, PC.Score));
end;

{ ── Regras de Colisão com Inimigo ────────────────────────────────────────── }

procedure TGameRulesSystem.HandleEnemyCollision(APlayer, AEnemy: TEntity);
var
   PC    : TPlayerComponent;
   RBP   : TRigidBodyComponent;
   TrP   : TTransformComponent;
   TrE   : TTransformComponent;
   ColE  : TColliderComponent;
   PlayerRect, EnemyRect: TRectF;
begin
   PC  := TPlayerComponent(APlayer.GetComponent(TPlayerComponent));
   RBP := TRigidBodyComponent(APlayer.GetComponent(TRigidBodyComponent));
   TrP := TTransformComponent(APlayer.GetComponent(TTransformComponent));
   TrE := TTransformComponent(AEnemy.GetComponent(TTransformComponent));
   ColE:= TColliderComponent(AEnemy.GetComponent(TColliderComponent));

   if not (Assigned(PC) and Assigned(RBP) and Assigned(TrP) and Assigned(TrE) and Assigned(ColE)) then
      Exit;

   if PC.State = psDead then
      Exit;

   EnemyRect  := ColE.GetWorldRect(TrE.Position);

   { ── Mecânica de Stomp: jogador caindo e acima da metade do inimigo ── }
   if (RBP.Velocity.Y > 0) and (TrP.Position.Y + 14 < TrE.Position.Y + EnemyRect.H * 0.5) then
   begin
      PC.Score      := PC.Score + 100;
      RBP.Velocity.Y := -350.0; { quique de ricochete }
      World.DestroyEntity(AEnemy.ID);

      World.EventBus.Publish(TEnemyStompedEvent.Create(100, PC.Score));
   end
   else
   begin
      { ── Dano ao jogador ── }
      if PC.InvFrames > 0 then
         Exit; { invulnerável — ignora }

      Dec(PC.Lives);
      PC.InvFrames := 2.0;

      World.EventBus.Publish(TPlayerDamagedEvent.Create(PC.Lives));

      if PC.Lives <= 0 then
      begin
         PC.State := psDead;
         World.EventBus.Publish(TPlayerDiedEvent.Create);
      end;
   end;
end;

{ ── Handler principal ────────────────────────────────────────────────────── }

procedure TGameRulesSystem.OnEntityOverlap(AEvent: TEvent2D);
var
   Ev        : TEntityOverlapEvent;
   Player    : TEntity;
   Other     : TEntity;
   PlayerTag : TColliderTag;
   OtherTag  : TColliderTag;
begin
   Ev := TEntityOverlapEvent(AEvent);

   { Ignora colisões que não envolvem o jogador }
   if not ResolvePlayer(Ev, Player, Other, PlayerTag, OtherTag) then
      Exit;

   case OtherTag of
      ctCoin  : HandleCoinPickup(Player, Other);
      ctEnemy : HandleEnemyCollision(Player, Other);
   end;
end;

end.
