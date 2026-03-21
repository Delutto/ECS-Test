unit P2D.Systems.Timer;

{$mode objfpc}{$H+}

interface

uses
  P2D.Core.ComponentRegistry,
  P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Timer;

type
  TTimerSystem2D = class(TSystem2D)
  private
    FTimerID: Integer;
  public
    constructor Create(AWorld: TWorldBase); override;
    procedure Init; override;
    procedure Update(ADelta: Single); override;
  end;

implementation

constructor TTimerSystem2D.Create(AWorld: TWorldBase);
begin
  inherited Create(AWorld);
  
  Priority := 1;   // first system to run — timers tick before any game logic
  Name     := 'TimerSystem';
end;

procedure TTimerSystem2D.Init;
begin
  inherited;
  
  RequireComponent(TTimerComponent2D);
  FTimerID := ComponentRegistry.GetComponentID(TTimerComponent2D);
end;

procedure TTimerSystem2D.Update(ADelta: Single);
var
  E : TEntity;
  TC: TTimerComponent2D;
begin
  for E in GetMatchingEntities do
  begin
    TC := TTimerComponent2D(E.GetComponentByID(FTimerID));
    TC.Tick(ADelta);
  end;
end;

end.
