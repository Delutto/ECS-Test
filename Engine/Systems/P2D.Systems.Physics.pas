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
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then
      Continue;
    if not E.HasComponent(TTransformComponent) then
      Continue;
    if not E.HasComponent(TRigidBodyComponent) then
      Continue;

    Tr := TTransformComponent(E.GetComponent(TTransformComponent));
    RB := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));

    if not (Tr.Enabled and RB.Enabled) then
      Continue;

    // 1. Aplica gravidade (apenas se em queda livre)
    if RB.UseGravity and not RB.Grounded then
      RB.Velocity.Y := RB.Velocity.Y + GRAVITY * RB.GravityScale * AFixedDelta;

    // 2. Clamp de velocidade de queda máxima
    if RB.Velocity.Y > RB.MaxFallSpeed then
      RB.Velocity.Y := RB.MaxFallSpeed;

    // 3. Aplica aceleração extra (forças externas)
    RB.Velocity.X := RB.Velocity.X + RB.Acceleration.X * AFixedDelta;
    RB.Velocity.Y := RB.Velocity.Y + RB.Acceleration.Y * AFixedDelta;

    // 4. Integra posição (semi-implícito: usa velocidade já atualizada)
    Tr.Position.X := Tr.Position.X + RB.Velocity.X * AFixedDelta;
    Tr.Position.Y := Tr.Position.Y + RB.Velocity.Y * AFixedDelta;

    // 5. Reseta estado por passo — TCollisionSystem restaura Grounded=True no mesmo FixedUpdate se houver contato com o chão
    RB.Grounded := False;
  end;
end;

end.


