unit P2D.Systems.Physics;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World, P2D.Components.Transform, P2D.Components.RigidBody;

const
  GRAVITY = 980.0; // pixels per second squared

type

  { TPhysicsSystem }

  TPhysicsSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorldBase); override;
    procedure Init; override;
    procedure Update(ADelta: Single); override;
    procedure FixedUpdate(AFixedDelta: Single); override;
  end;

implementation

constructor TPhysicsSystem.Create(AWorld: TWorldBase);
begin
  inherited Create(AWorld);
  Priority := 10;
  Name     := 'PhysicsSystem';
end;

procedure TPhysicsSystem.Init;
begin
   inherited;

 { Cache cobre todas as entidades colidíveis (player, inimigos, moedas).
   O loop de tile collision filtra adicionalmente por TRigidBodyComponent. }
   RequireComponent(TTransformComponent);
   RequireComponent(TRigidBodyComponent);
end;

{ Update é vazio: toda a integração física acontece em FixedUpdate, garantindo que o comportamento seja independente do frame rate. }
procedure TPhysicsSystem.Update(ADelta: Single);
begin

end;

{ FixedUpdate é chamado com AFixedDelta constante (1/60s por padrão).
  Integração semi-implícita de Euler:
    1. Aplica gravidade/aceleração → atualiza velocidade
    2. Clamp de velocidade de queda
    3. Integra posição com a velocidade JÁ atualizada (semi-implícito)
    4. Reseta Grounded — será restaurado pelo TCollisionSystem no mesmo passo. }
procedure TPhysicsSystem.FixedUpdate(AFixedDelta: Single);
var
   E : TEntity;
   Tr: TTransformComponent;
   RB: TRigidBodyComponent;
begin
   for E in GetMatchingEntities do
   begin
      //if not E.Alive then
      //   Continue;

      Tr := TTransformComponent(E.GetComponent(TTransformComponent));
      RB := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));

      if not (Tr.Enabled and RB.Enabled) then
         Continue;

      // 1. Reset ground/wall contact state BEFORE any integration.
      //    TCollisionSystem (priority 20) runs after this system and will
      //    restore Grounded := True if the entity overlaps a solid tile.
      RB.Grounded := False;
      RB.OnWall   := False;

      // 2. Apply gravity unconditionally (no 'not RB.Grounded' guard).
      //    This guarantees the entity always penetrates the tile surface by
      //    a small amount each step, so TCollisionSystem always detects the
      //    overlap and sets Grounded := True + zeroes Velocity.Y.
      if RB.UseGravity then
         RB.Velocity.Y := RB.Velocity.Y + GRAVITY * RB.GravityScale * AFixedDelta;

      // 3. Clamp max fall speed.
      if RB.Velocity.Y > RB.MaxFallSpeed then
         RB.Velocity.Y := RB.MaxFallSpeed;

      // 4. Apply external acceleration forces.
      RB.Velocity.X := RB.Velocity.X + RB.Acceleration.X * AFixedDelta;
      RB.Velocity.Y := RB.Velocity.Y + RB.Acceleration.Y * AFixedDelta;

      // 5. Integrate position (semi-implicit Euler).
      Tr.Position.X := Tr.Position.X + RB.Velocity.X * AFixedDelta;
      Tr.Position.Y := Tr.Position.Y + RB.Velocity.Y * AFixedDelta;
   end;
end;

end.
