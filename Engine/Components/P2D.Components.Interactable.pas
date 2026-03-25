unit P2D.Components.Interactable;
{$mode objfpc}{$H+}
interface
uses SysUtils,P2D.Core.Component,P2D.Core.Types;
type
  TInteractionType2D=(iatNone,iatPickup,iatTalk,iatOpenChest,
                      iatUseSwitch,iatCraft,iatWarp,iatCustom);
  TOnInteractProc2D=procedure(ActorID,InterID:Cardinal) of object;
  TInteractableComponent2D=class(TComponent2D)
  public
    InteractionType:TInteractionType2D;
    CustomType:Integer;
    Radius:Single;
    Prompt:String;
    RequiresItem,RequiredItemCount:Integer;
    OneTimeUse,Used:Boolean;
    OnInteract:TOnInteractProc2D;
    constructor Create;override;
  end;
implementation
uses P2D.Core.ComponentRegistry,P2D.Common;
constructor TInteractableComponent2D.Create;
begin inherited Create;
  InteractionType:=iatNone;CustomType:=0;
  Radius:=DEFAULT_INTERACTION_RADIUS;Prompt:='Press [E]';
  RequiresItem:=0;RequiredItemCount:=0;
  OneTimeUse:=False;Used:=False;OnInteract:=nil;end;
initialization ComponentRegistry.Register(TInteractableComponent2D);
end.
