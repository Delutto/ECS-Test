unit P2D.Components.Transform;

{$mode objfpc}{$H+}

interface

uses P2D.Core.Component, P2D.Core.Types;

type
  TTransformComponent = class(TComponent2D)
  public
    Position : TVector2;
    Scale    : TVector2;
    Rotation : Single;      // degrees
    constructor Create; override;
  end;

implementation

constructor TTransformComponent.Create;
begin
  inherited Create;
  Position.Create(0, 0);
  Scale.Create(1, 1);
  Rotation := 0;
end;

end.
