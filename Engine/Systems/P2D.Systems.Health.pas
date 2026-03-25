unit P2D.Systems.Health;
{$mode objfpc}{$H+}
interface
uses SysUtils,Math,
     P2D.Core.ComponentRegistry,P2D.Core.Entity,
     P2D.Core.System,P2D.Core.World,P2D.Components.Health;
type
  THealthSystem2D=class(TSystem2D)
  private FHealthID:Integer;
  public
    constructor Create(AW:TWorldBase);override;
    procedure Init;override;
    procedure Update(DT:Single);override;
  end;
implementation
uses P2D.Core.Events,P2D.Core.Types;
constructor THealthSystem2D.Create(AW:TWorldBase);
begin inherited Create(AW);Priority:=4;Name:='HealthSystem';end;
procedure THealthSystem2D.Init;
begin inherited Init;
  RequireComponent(THealthComponent2D);
  FHealthID:=ComponentRegistry.GetComponentID(THealthComponent2D);end;
procedure THealthSystem2D.Update(DT:Single);
var E:TEntity;HC:THealthComponent2D;Old:Single;
begin
  for E in GetMatchingEntities do begin
    HC:=THealthComponent2D(E.GetComponentByID(FHealthID));
    if not Assigned(HC)or not HC.Enabled or HC.Dead then Continue;
    if HC.InvincibilityTimer>0 then HC.InvincibilityTimer:=Max(0,HC.InvincibilityTimer-DT);
    if HC.RegenRate>0 then begin
      if HC.HP<HC.MaxHP then begin
        HC.RegenTimer:=HC.RegenTimer+DT;
        if HC.RegenTimer>=HC.RegenDelay then begin
          Old:=HC.HP;HC.HP:=Min(HC.MaxHP,HC.HP+HC.RegenRate*DT);
          if HC.HP<>Old then begin
            HC.Regenerating:=True;
            World.EventBus.Publish(
              THealthChangedEvent2D.Create(E.ID,Old,HC.HP,HC.MaxHP));end;end;
      end else begin HC.RegenTimer:=0;HC.Regenerating:=False;end;
    end;end;end;
end.
