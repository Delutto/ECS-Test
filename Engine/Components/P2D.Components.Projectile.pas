unit P2D.Components.Projectile;
{$mode objfpc}{$H+}
interface
uses SysUtils,Math,P2D.Core.Component,P2D.Core.Types;
type
  TProjectileType2D=(ptNone,ptBullet,ptArrow,ptFireball,ptMagic,ptExplosive,ptBeam);
  TProjectileComponent2D=class(TComponent2D)
  public
    SourceEntityID:Cardinal;
    Speed,DirectionX,DirectionY:Single;
    Damage,KnockbackForce:Single;
    ProjectileType:TProjectileType2D;
    MaxRange,TraveledDistance:Single;
    PierceCount,HitsLeft:Integer;
    Lifetime,LifetimeTimer,Gravity:Single;
    IsHitscan:Boolean;
    constructor Create;override;
    procedure SetDirection(AngleDeg:Single);
  end;
implementation
uses P2D.Core.ComponentRegistry,P2D.Common;
constructor TProjectileComponent2D.Create;
begin inherited Create;
  SourceEntityID:=0;Speed:=400;DirectionX:=1;DirectionY:=0;
  Damage:=10;KnockbackForce:=200;ProjectileType:=ptBullet;
  MaxRange:=0;TraveledDistance:=0;PierceCount:=0;HitsLeft:=1;
  Lifetime:=DEFAULT_PROJECTILE_LIFETIME;LifetimeTimer:=0;Gravity:=0;IsHitscan:=False;end;
procedure TProjectileComponent2D.SetDirection(AngleDeg:Single);
var R:Single;
begin R:=AngleDeg*(Pi/180);DirectionX:=Cos(R);DirectionY:=Sin(R);end;
initialization ComponentRegistry.Register(TProjectileComponent2D);
end.
