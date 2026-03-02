unit P2D.Systems.Physics;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.RigidBody;

const
  GRAVITY = 980.0; // pixels per second squared

type
  TPhysicsSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorld); override;
    procedure Update(ADelta: Single); override;
  end;

implementation

constructor TPhysicsSystem.Create(AWorld: TWorld);
begin
  inherited Create(AWorld);
  Priority := 10;
  Name     := 'PhysicsSystem';
end;

procedure TPhysicsSystem.Update(ADelta: Single);
var
  E   : TEntity;
  Tr  : TTransformComponent;
  RB  : TRigidBodyComponent;
begin
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then Continue;
    if not E.HasComponent(TTransformComponent) then Continue;
    if not E.HasComponent(TRigidBodyComponent)  then Continue;

    Tr := TTransformComponent(E.GetComponent(TTransformComponent));
    RB := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));

    if not (Tr.Enabled and RB.Enabled) then Continue;

    // Gravity
    if RB.UseGravity and not RB.Grounded then
      RB.Velocity.Y := RB.Velocity.Y + GRAVITY * RB.GravityScale * ADelta;

    // Clamp fall speed
    if RB.Velocity.Y > RB.MaxFallSpeed then
      RB.Velocity.Y := RB.MaxFallSpeed;

    // Apply acceleration
    RB.Velocity.X := RB.Velocity.X + RB.Acceleration.X * ADelta;
    RB.Velocity.Y := RB.Velocity.Y + RB.Acceleration.Y * ADelta;

    // Integrate position
    Tr.Position.X := Tr.Position.X + RB.Velocity.X * ADelta;
    Tr.Position.Y := Tr.Position.Y + RB.Velocity.Y * ADelta;

    // Reset per-frame state
    RB.Grounded := False;
  end;
end;

end.


