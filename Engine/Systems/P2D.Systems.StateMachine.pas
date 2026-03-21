unit P2D.Systems.StateMachine;

{$mode objfpc}{$H+}

interface

uses
  P2D.Core.ComponentRegistry,
  P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.StateMachine;

type
  { TStateMachineSystem2D
    Drives all TStateMachineComponent2D instances every frame.
    Priority 6 — after TimerSystem (1) and LifetimeSystem (2),
    before physics (10) so that state-driven physics flags are set
    before TPhysicsSystem reads them. }
  TStateMachineSystem2D = class(TSystem2D)
  private
    FFSMID: Integer;
  public
    constructor Create(AWorld: TWorldBase); override;
    procedure Init; override;
    procedure Update(ADelta: Single); override;
  end;

implementation

constructor TStateMachineSystem2D.Create(AWorld: TWorldBase);
begin
  inherited Create(AWorld);
  
  Priority := 6;
  Name     := 'StateMachineSystem';
end;

procedure TStateMachineSystem2D.Init;
begin
  inherited;
  
  RequireComponent(TStateMachineComponent2D);
  FFSMID := ComponentRegistry.GetComponentID(TStateMachineComponent2D);
end;

procedure TStateMachineSystem2D.Update(ADelta: Single);
var
  E  : TEntity;
  FSM: TStateMachineComponent2D;
begin
  for E in GetMatchingEntities do
  begin
    FSM := TStateMachineComponent2D(E.GetComponentByID(FFSMID));
    FSM.Tick(ADelta);
  end;
end;

end.
