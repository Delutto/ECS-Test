unit P2D.Components.Collider;

{$mode objfpc}{$H+}

interface

uses P2D.Core.Component, P2D.Core.Types;

type
  TColliderTag = (ctNone, ctPlayer, ctEnemy, ctGround, ctPlatform,
                  ctCoin, ctPowerUp, ctHazard, ctGoal);

  TColliderComponent = class(TComponent2D)
  public
    Offset  : TVector2;     // relative to transform position
    Size    : TVector2;
    Tag     : TColliderTag;
    IsTrigger: Boolean;     // trigger = detect only, no physics response
    constructor Create; override;
    function GetWorldRect(const APosition: TVector2): TRectF;
  end;

implementation

constructor TColliderComponent.Create;
begin
  inherited Create;
  Offset.Create(0, 0);
  Size.Create(16, 16);
  Tag := ctNone;
  IsTrigger := False;
end;

function TColliderComponent.GetWorldRect(const APosition: TVector2): TRectF;
begin
  Result.Create(APosition.X + Offset.X, APosition.Y + Offset.Y, Size.X, Size.Y);
end;

end.
