unit P2D.Components.RigidBody;

{$mode objfpc}{$H+}

interface

uses P2D.Core.Component, P2D.Core.Types;

type
  TRigidBodyComponent = class(TComponent2D)
  public
    Velocity    : TVector2;
    Acceleration: TVector2;
    Mass        : Single;
    GravityScale: Single;
    MaxFallSpeed: Single;
    Grounded    : Boolean;
    OnWall      : Boolean;
    UseGravity  : Boolean;
    constructor Create; override;
  end;

implementation

constructor TRigidBodyComponent.Create;
begin
  inherited Create;
  Velocity.Create(0, 0);
  Acceleration.Create(0, 0);
  Mass         := 1.0;
  GravityScale := 1.0;
  MaxFallSpeed := 600.0;
  Grounded     := False;
  OnWall       := False;
  UseGravity   := True;
end;

end.
