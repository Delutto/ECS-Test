unit P2D.Systems.Dialog;
{$mode objfpc}{$H+}
interface
uses SysUtils,
     P2D.Core.ComponentRegistry,P2D.Core.Event,P2D.Core.Entity,
     P2D.Core.System,P2D.Core.World,
     P2D.Components.Dialog,P2D.Components.Interactable;
type
  TDialogSystem2D=class(TSystem2D)
  private
    FDialogID:Integer;
    procedure OnInteraction(AEvent:TEvent2D);
  public
    constructor Create(AW:TWorldBase);override;
    procedure Init;override;
    procedure Update(DT:Single);override;
    procedure Shutdown;override;
  end;
implementation
uses P2D.Core.Events;
constructor TDialogSystem2D.Create(AW:TWorldBase);
begin inherited Create(AW);Priority:=9;Name:='DialogSystem';end;
procedure TDialogSystem2D.Init;
begin inherited Init;RequireComponent(TDialogComponent2D);
  FDialogID:=ComponentRegistry.GetComponentID(TDialogComponent2D);
  World.EventBus.Subscribe(TInteractionEvent2D,@OnInteraction);end;
procedure TDialogSystem2D.Shutdown;
begin World.EventBus.Unsubscribe(TInteractionEvent2D,@OnInteraction);inherited Shutdown;end;
procedure TDialogSystem2D.OnInteraction(AEvent:TEvent2D);
var Ev:TInteractionEvent2D;Ow:TEntity;DC:TDialogComponent2D;
begin Ev:=TInteractionEvent2D(AEvent);if Ev.InteractionType<>Ord(iatTalk)then Exit;
  Ow:=World.GetEntity(Ev.InteractableID);
  if not Assigned(Ow)or not Ow.Alive then Exit;
  DC:=TDialogComponent2D(Ow.GetComponentByID(FDialogID));if not Assigned(DC)then Exit;
  DC.StartDialog;
  World.EventBus.Publish(TDialogStartedEvent2D.Create(Ev.ActorID,Ev.InteractableID));end;
procedure TDialogSystem2D.Update(DT:Single);
var E:TEntity;DC:TDialogComponent2D;
begin
  for E in GetMatchingEntities do begin
    DC:=TDialogComponent2D(E.GetComponentByID(FDialogID));
    if not Assigned(DC)or not DC.Enabled or not DC.Active then Continue;
    DC.Tick(DT);
    if not DC.Active then
      World.EventBus.Publish(TDialogEndedEvent2D.Create(0,E.ID,-1));end;end;
end.
