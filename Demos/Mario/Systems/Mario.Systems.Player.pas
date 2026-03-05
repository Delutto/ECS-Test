unit Mario.Systems.Player;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, raylib,
   P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Components.Transform, P2D.Components.RigidBody,
   P2D.Components.Sprite, P2D.Components.Animation,
   P2D.Components.Tags, P2D.Utils.Math;

const
  { Ponto de spawn do jogador (coordenadas do mundo em pixels).
    O mapa tem 15 linhas × 16px = 240px. Chão sólido começa em Y≈160.
    Y=100 posiciona o Mario no céu, com espaço para a queda inicial. }
   PLAYER_SPAWN_X   : Single = 48.0;
   PLAYER_SPAWN_Y   : Single = 100.0;

   { Kill zone: distância abaixo do mapa para detectar queda fatal. }
   PLAYER_KILL_ZONE : Single = 400.0;

   { Duração da invulnerabilidade concedida após respawn (segundos). }
   RESPAWN_INV_TIME : Single = 2.5;

type
   { -------------------------------------------------------------------------
   TPlayerPhysicsSystem — processa intenções de input em FixedUpdate.

   Prioridade 11: roda após TPhysicsSystem (10) que integra gravidade/posição,
   e antes de TCollisionSystem (20) que corrige colisões.

   Separa claramente:
   TPlayerInputSystem (Update)  → lê hardware, seta flags de intenção
   TPlayerPhysicsSystem (FixedUpdate) → consome flags, aplica a Velocity
   -------------------------------------------------------------------------}

   { TPlayerPhysicsSystem }
   TPlayerPhysicsSystem = class(TSystem2D)
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure FixedUpdate(AFixedDelta: Single); override;
   end;

   { -------------------------------------------------------------------------
   TPlayerAnimSystem — seleciona a animação correta com base no estado.
   -------------------------------------------------------------------------}
   TPlayerAnimSystem = class(TSystem2D)
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
   end;

implementation

{ TPlayerPhysicsSystem }

constructor TPlayerPhysicsSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 9;
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
   { Intencionalmente vazio: toda lógica está em FixedUpdate. }
end;

procedure TPlayerPhysicsSystem.FixedUpdate(AFixedDelta: Single);
var
   E    : TEntity;
   Tr   : TTransformComponent;
   RB   : TRigidBodyComponent;
   PC   : TPlayerComponent;
   Speed: Single;
begin
   for E in GetMatchingEntities do
   begin
      if not E.Alive then
         Continue;

      Tr := TTransformComponent(E.GetComponent(TTransformComponent));
      RB := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
      PC := TPlayerComponent(E.GetComponent(TPlayerComponent));

      if PC.State = psDead then
         Continue;

      { ── Velocidade horizontal base ─────────────────────────────────────── }
      if PC.WantsRun then
         Speed := PC.RunSpeed
      else
         Speed := PC.WalkSpeed;

      { ── Movimento horizontal ───────────────────────────────────────────── }
      if PC.WantsMoveLeft then
      begin
         RB.Velocity.X := ApproachF(RB.Velocity.X, -Speed, 600 * AFixedDelta);
         if PC.WantsRun then
            PC.State := psRunning
         else
            PC.State := psWalking;
      end
      else if PC.WantsMoveRight then
      begin
         RB.Velocity.X := ApproachF(RB.Velocity.X, Speed, 600 * AFixedDelta);
         if PC.WantsRun then
            PC.State := psRunning
         else
            PC.State := psWalking;
      end
      else
      begin
         { Desaceleração por fricção ao não pressionar movimento. }
         RB.Velocity.X := ApproachF(RB.Velocity.X, 0, 400 * AFixedDelta);
         if Abs(RB.Velocity.X) < 1.0 then
         begin
            RB.Velocity.X := 0.0;
            if RB.Grounded then
               PC.State := psIdle;
         end;
      end;

      { ── Pulo: consome WantsJump e aplica UMA única vez ─────────────────── }
      if PC.WantsJump then
      begin
         if RB.Grounded then
         begin
            RB.Velocity.Y := PC.JumpForce;
            RB.Grounded   := False;
            PC.State      := psJumping;

            { Consome a flag APENAS quando o pulo de fato ocorrer. }
            PC.WantsJump := False;
         end;
         { Se ele apertou 1 frame antes de cair no chão, a flag sobrevive e ele pula no frame seguinte automaticamente (Jump Buffer natural). }
      end;

      { ── Corte de pulo: reduz altura ao soltar o botão cedo ─────────────── }
      if PC.WantsJumpCut then
      begin
         if RB.Velocity.Y < -200 then
            RB.Velocity.Y := -200;
         PC.WantsJumpCut := False; { consome a flag }
      end;

      { ── Estado aéreo (atualizado após aplicar intenções) ───────────────── }
      if not RB.Grounded then
      begin
         if RB.Velocity.Y < 0 then
            PC.State := psJumping
         else
            PC.State := psFalling;
      end;

      { ── Kill zone ──────────────────────────────────────────────────────────
      Verificado em FixedUpdate porque Tr.Position.Y é modificado pela física.
      Garante que a detecção acontece no mesmo contexto da simulação. }
      if Tr.Position.Y > PLAYER_KILL_ZONE then
      begin
         Dec(PC.Lives);

         if PC.Lives > 0 then
         begin
            Tr.Position.Create(PLAYER_SPAWN_X, PLAYER_SPAWN_Y);
            RB.Velocity.Create(0.0, 0.0);
            RB.Acceleration.Create(0.0, 0.0);
            RB.Grounded     := False;
            PC.InvFrames    := RESPAWN_INV_TIME;
            PC.State        := psIdle;
            { Limpa flags pendentes para não aplicar input acumulado pós-respawn. }
            PC.WantsJump    := False;
            PC.WantsJumpCut := False;
         end
         else
            PC.State := psDead;
      end;
   end;
end;

{ TPlayerAnimSystem }

constructor TPlayerAnimSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 7;
   Name     := 'PlayerAnimSystem';
end;

procedure TPlayerAnimSystem.Init;
begin
   inherited;

   RequireComponent(TPlayerTag);
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
      if not E.Alive then
         Continue;

      PC   := TPlayerComponent(E.GetComponent(TPlayerComponent));
      RB   := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
      Spr  := TSpriteComponent(E.GetComponent(TSpriteComponent));
      Anim := TAnimationComponent(E.GetComponent(TAnimationComponent));

      if RB.Velocity.X < -5 then
         Spr.Flip := flHorizontal
      else
         if RB.Velocity.X > 5 then
            Spr.Flip := flNone;

      case PC.State of
         psIdle    : Anim.Play('idle');
         psWalking : Anim.Play('walk');
         psRunning : Anim.Play('run');
         psJumping,
         psFalling : Anim.Play('jump');
         psDead    : Anim.Play('dead');
      end;
   end;
end;

end.
