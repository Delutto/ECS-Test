unit P2D.Systems.DayNight;
{$mode objfpc}{$H+}
interface
uses SysUtils,Math,raylib,
     P2D.Core.ComponentRegistry,P2D.Core.Entity,
     P2D.Core.System,P2D.Core.World,P2D.Components.DayNight;
type
  TDayNightSystem2D=class(TSystem2D)
  private
    FDNID:Integer;
    function Blend(const A,B:TColor;T:Single):TColor;
    function Phase(T:Single):TDayPhase2D;
    function Ambient(T:Single):Single;
  public
    constructor Create(AW:TWorldBase);override;
    procedure Init;override;
    procedure Update(DT:Single);override;
  end;
implementation
uses P2D.Core.Events;
constructor TDayNightSystem2D.Create(AW:TWorldBase);
begin inherited Create(AW);Priority:=2;Name:='DayNightSystem';end;
procedure TDayNightSystem2D.Init;
begin inherited Init;RequireComponent(TDayNightComponent2D);
  FDNID:=ComponentRegistry.GetComponentID(TDayNightComponent2D);end;
function TDayNightSystem2D.Blend(const A,B:TColor;T:Single):TColor;
begin Result:=ColorCreate(Round(A.R+(B.R-A.R)*T),Round(A.G+(B.G-A.G)*T),
                           Round(A.B+(B.B-A.B)*T),255);end;
function TDayNightSystem2D.Phase(T:Single):TDayPhase2D;
begin if T<0.2 then Result:=dpNight
  else if T<0.3 then Result:=dpDawn
  else if T<0.7 then Result:=dpDay
  else if T<0.8 then Result:=dpDusk
  else Result:=dpEveningNight;end;
function TDayNightSystem2D.Ambient(T:Single):Single;
begin Result:=0.1+0.9*Sin(T*Pi);end;
procedure TDayNightSystem2D.Update(DT:Single);
var E:TEntity;DN:TDayNightComponent2D;Old:TDayPhase2D;T:Single;
begin
  for E in GetMatchingEntities do begin
    DN:=TDayNightComponent2D(E.GetComponentByID(FDNID));
    if not Assigned(DN)or not DN.Enabled then Continue;
    Old:=DN.CurrentPhase;DN.Tick(DT);
    DN.AmbientLight:=Ambient(DN.TimeOfDay);DN.CurrentPhase:=Phase(DN.TimeOfDay);
    T:=DN.TimeOfDay;
    if T<0.25 then DN.CurrentSkyColor:=Blend(DN.SkyColorNight,DN.SkyColorDawn,T/0.25)
    else if T<0.5 then DN.CurrentSkyColor:=Blend(DN.SkyColorDawn,DN.SkyColorDay,(T-0.25)/0.25)
    else if T<0.75 then DN.CurrentSkyColor:=Blend(DN.SkyColorDay,DN.SkyColorDusk,(T-0.5)/0.25)
    else DN.CurrentSkyColor:=Blend(DN.SkyColorDusk,DN.SkyColorNight,(T-0.75)/0.25);
    if DN.CurrentPhase<>Old then
      World.EventBus.Publish(TDayNightPhaseEvent2D.Create(Ord(DN.CurrentPhase),DN.TimeOfDay));
  end;end;
end.
