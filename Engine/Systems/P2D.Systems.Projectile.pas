unit P2D.Systems.Projectile;
{$mode objfpc}{$H+}
interface
uses SysUtils,Math,
     P2D.Core.ComponentRegistry,P2D.Core.Types,P2D.Core.Entity,
     P2D.Core.System,P2D.Core.World,
     P2D.Components.Transform,P2D.Components.Collider,P2D.Components.Projectile;
type
  TProjectileSystem2D=class(TSystem2D)
  private FTransformID,FProjectileID,FColliderID:Integer;
  public
    constructor Create(AW:TWorldBase);override;
    procedure Init;override;
    procedure Update(DT:Single);override;
  end;
implementation
constructor TProjectileSystem2D.Create(AW:TWorldBase);
begin inherited Create(AW);Priority:=12;Name:='ProjectileSystem';end;
procedure TProjectileSystem2D.Init;
begin inherited Init;
  RequireComponent(TProjectileComponent2D);RequireComponent(TTransformComponent);
  FTransformID:=ComponentRegistry.GetComponentID(TTransformComponent);
  FProjectileID:=ComponentRegistry.GetComponentID(TProjectileComponent2D);
  FColliderID:=ComponentRegistry.GetComponentID(TColliderComponent);end;
procedure TProjectileSystem2D.Update(DT:Single);
var E:TEntity;PC:TProjectileComponent2D;Tr:TTransformComponent;
    D:Single;Exp:Boolean;
begin
  for E in GetMatchingEntities do begin
    PC:=TProjectileComponent2D(E.GetComponentByID(FProjectileID));
    Tr:=TTransformComponent(E.GetComponentByID(FTransformID));
    if not Assigned(PC)or not Assigned(Tr)then Continue;
    if not PC.Enabled or not Tr.Enabled then Continue;
    Exp:=False;
    if PC.Lifetime>0 then begin
      PC.LifetimeTimer:=PC.LifetimeTimer+DT;
      if PC.LifetimeTimer>=PC.Lifetime then Exp:=True;end;
    if not Exp then begin
      D:=PC.Speed*DT;
      Tr.Position.X:=Tr.Position.X+PC.DirectionX*D;
      Tr.Position.Y:=Tr.Position.Y+PC.DirectionY*D;
      if PC.Gravity<>0 then PC.DirectionY:=PC.DirectionY+PC.Gravity*DT;
      PC.TraveledDistance:=PC.TraveledDistance+D;
      if(PC.MaxRange>0)and(PC.TraveledDistance>=PC.MaxRange)then Exp:=True;end;
    if Exp or(PC.HitsLeft<=0)then World.DestroyEntity(E.ID);end;end;
end.
