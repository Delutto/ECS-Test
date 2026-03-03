unit Mario.Systems.Input;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, raylib,
   P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Components.Transform, P2D.Components.RigidBody,
   P2D.Components.Tags, P2D.Utils.Math;

{ ── Ponto de spawn do jogador no espaço do mundo ─────────────────────────────
  O mapa tem 15 linhas × 16 px = 240 px de altura.
  O chão sólido começa na linha 10 (Y = 160). Spawnar em Y = 100 posiciona o Mario no céu, acima do chão, com espaço suficiente para a queda inicial. }
const
   PLAYER_SPAWN_X   : Single = 48.0;
   PLAYER_SPAWN_Y   : Single = 100.0;

   { Limite de queda: Mario deve ter saído do mapa visível (240 px) com uma margem generosa para não cortar a animação de queda. }
   PLAYER_KILL_ZONE : Single = 400.0;

   { Duração da invulnerabilidade concedida após respawn (segundos).
     Evita que o jogador tome dano imediatamente ao reaparecer. }
   RESPAWN_INV_TIME : Single = 2.5;

type
   TPlayerInputSystem = class(TSystem2D)
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Update(ADelta: Single); override;
   end;

implementation

constructor TPlayerInputSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 1;
   Name     := 'PlayerInputSystem';
end;

procedure TPlayerInputSystem.Update(ADelta: Single);
var
   E    : TEntity;
   Tr   : TTransformComponent;
   RB   : TRigidBodyComponent;
   PC   : TPlayerComponent;
   Speed: Single;
begin
   for E in World.Entities.GetAll do
   begin
      if not E.Alive then
         Continue;
      if not E.HasComponent(TPlayerTag) then
         Continue;
      if not E.HasComponent(TTransformComponent) then
         Continue;
      if not E.HasComponent(TRigidBodyComponent) then
         Continue;
      if not E.HasComponent(TPlayerComponent) then
         Continue;

      Tr := TTransformComponent(E.GetComponent(TTransformComponent));
      RB := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
      PC := TPlayerComponent(E.GetComponent(TPlayerComponent));

      { Jogador morto não recebe input. }
      if PC.State = psDead then
         Continue;

      { ── Invulnerabilidade ─────────────────────────────────────────────── }
      if PC.InvFrames > 0 then
         PC.InvFrames := PC.InvFrames - ADelta;

      { ── Modificador de corrida ───────────────────────────────────────── }
      if IsKeyDown(KEY_LEFT_SHIFT) or IsKeyDown(KEY_Z) then
         Speed := PC.RunSpeed
      else
         Speed := PC.WalkSpeed;

      { ── Movimento horizontal ─────────────────────────────────────────── }
      if IsKeyDown(KEY_LEFT) or IsKeyDown(KEY_A) then
      begin
         RB.Velocity.X := ApproachF(RB.Velocity.X, -Speed, 600 * ADelta);
         PC.State := psWalking;
      end
      else
         if IsKeyDown(KEY_RIGHT) or IsKeyDown(KEY_D) then
         begin
            RB.Velocity.X := ApproachF(RB.Velocity.X, Speed, 600 * ADelta);
            PC.State := psWalking;
         end
         else
         begin
            { Fricção ao soltar as teclas. }
            RB.Velocity.X := ApproachF(RB.Velocity.X, 0, 400 * ADelta);
            if Abs(RB.Velocity.X) < 1.0 then
            begin
               RB.Velocity.X := 0.0;
               if RB.Grounded then
                  PC.State := psIdle;
            end;
         end;

      { ── Pulo ─────────────────────────────────────────────────────────── }
      if (IsKeyPressed(KEY_SPACE) or IsKeyPressed(KEY_UP) or IsKeyPressed(KEY_W)) and RB.Grounded then
      begin
         RB.Velocity.Y := PC.JumpForce;
         RB.Grounded   := False;
         PC.State      := psJumping;
      end;

      { Pulo variável: soltar cedo reduz a altura. }
      if (IsKeyReleased(KEY_SPACE) or IsKeyReleased(KEY_UP)) and (RB.Velocity.Y < -200) then
         RB.Velocity.Y := -200;

      { Atualiza estado aéreo. }
      if not RB.Grounded then
      begin
         if RB.Velocity.Y < 0 then
            PC.State := psJumping
         else
            PC.State := psFalling;
      end;

      { ── Kill zone: Mario saiu do mapa ────────────────────────────────── }
      if Tr.Position.Y > PLAYER_KILL_ZONE then
      begin
         Dec(PC.Lives);

         if PC.Lives > 0 then
         begin
            { CORREÇÃO: posição de respawn dentro do mapa (Y=100, acima do chão). }
            Tr.Position.Create(PLAYER_SPAWN_X, PLAYER_SPAWN_Y);

            { Zera toda a velocidade para evitar que a física acumulada antes da queda seja aplicada no respawn. }
            RB.Velocity.Create(0, 0);
            RB.Acceleration.Create(0, 0);
            RB.Grounded := False; { força re-avaliação de colisão no próximo passo }

            { Concede invulnerabilidade pós-respawn: evita que o jogador tome dano imediatamente ao reaparecer perto de um inimigo. }
            PC.InvFrames := RESPAWN_INV_TIME;
            PC.State     := psIdle;
         end
         else
            PC.State := psDead;
      end;
   end;
end;

end.
