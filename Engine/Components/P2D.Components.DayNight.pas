unit P2D.Components.DayNight;
{$mode objfpc}{$H+}
interface
uses SysUtils,Math,raylib,P2D.Core.Component,P2D.Core.Types;
type
  TDayPhase2D=(dpNight,dpDawn,dpDay,dpDusk,dpEveningNight);
  TDayNightComponent2D=class(TComponent2D)
  public
    TimeOfDay,CycleDuration:Single;
    Paused:Boolean;
    CurrentPhase:TDayPhase2D;
    SkyColorNight,SkyColorDawn,SkyColorDay,SkyColorDusk:TColor;
    CurrentSkyColor:TColor;
    AmbientLight:Single;
    constructor Create;override;
    procedure Tick(ADelta:Single);
  end;
implementation
uses P2D.Core.ComponentRegistry,P2D.Common;
constructor TDayNightComponent2D.Create;
begin inherited Create;
  TimeOfDay:=0.3;CycleDuration:=DEFAULT_DAY_DURATION;Paused:=False;
  CurrentPhase:=dpDay;
  SkyColorNight:=ColorCreate(10,10,30,255);
  SkyColorDawn:=ColorCreate(255,140,80,255);
  SkyColorDay:=ColorCreate(92,148,252,255);
  SkyColorDusk:=ColorCreate(220,90,60,255);
  CurrentSkyColor:=SkyColorDay;AmbientLight:=1;end;
procedure TDayNightComponent2D.Tick(ADelta:Single);
begin if Paused then Exit;
  if CycleDuration>0 then TimeOfDay:=TimeOfDay+ADelta/CycleDuration;
  while TimeOfDay>=1 do TimeOfDay:=TimeOfDay-1;end;
initialization ComponentRegistry.Register(TDayNightComponent2D);
end.
