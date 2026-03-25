unit P2D.Systems.Interaction;
{$mode objfpc}{$H+}
interface

uses
   SysUtils, Math,
   P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.Entity,
   P2D.Core.System, P2D.Core.World,
   P2D.Components.Transform, P2D.Components.Interactable, P2D.Components.InputMap;

type
   TInteractionSystem2D = class(TSystem2D)
   private
      FTransformID, FInteractableID, FInputMapID: integer;
      FInteractAction: string;
   public
      constructor Create(AW: TWorldBase; const Act: string = 'Interact'); reintroduce;
      procedure Init; override;
      procedure Update(DT: single); override;
   end;

implementation

uses
   P2D.Core.Events, P2D.Core.InputAction, P2D.Core.InputManager;

constructor TInteractionSystem2D.Create(AW: TWorldBase; const Act: string);
begin
   inherited Create(AW);
   Priority := 8;
   Name := 'InteractionSystem';
   FInteractAction := Act;
end;

procedure TInteractionSystem2D.Init;
begin
   inherited Init;
   RequireComponent(TTransformComponent);
   RequireComponent(TInteractableComponent2D);
   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
   FInteractableID := ComponentRegistry.GetComponentID(TInteractableComponent2D);
   FInputMapID := ComponentRegistry.GetComponentID(TInputMapComponent);
end;

procedure TInteractionSystem2D.Update(DT: single);
var
   All: TEntityList;
   Actor, Obj: TEntity;
   ATr, OTr: TTransformComponent;
   IM: TInputMapComponent;
   IC: TInteractableComponent2D;
   DX, DY, D: single;
   I, J: integer;
begin
   All := World.Entities.GetAll;
   for I := 0 to All.Count - 1 do
   begin
      Actor := All[I];
      if not Actor.Alive then
         Continue;
      IM := TInputMapComponent(Actor.GetComponentByID(FInputMapID));
      ATr := TTransformComponent(Actor.GetComponentByID(FTransformID));
      if not Assigned(IM) or not Assigned(ATr) then
         Continue;
      if not IM.IsPressed(FInteractAction) then
         Continue;
      for J := 0 to All.Count - 1 do
      begin
         Obj := All[J];
         if not Obj.Alive or (Obj.ID = Actor.ID) then
            Continue;
         IC := TInteractableComponent2D(Obj.GetComponentByID(FInteractableID));
         OTr := TTransformComponent(Obj.GetComponentByID(FTransformID));
         if not Assigned(IC) or not Assigned(OTr) then
            Continue;
         if IC.Used and IC.OneTimeUse then
            Continue;
         DX := ATr.Position.X - OTr.Position.X;
         DY := ATr.Position.Y - OTr.Position.Y;
         D := Sqrt(DX * DX + DY * DY);
         if D <= IC.Radius then
         begin
            if IC.OneTimeUse then
               IC.Used := True;
            World.EventBus.Publish(TInteractionEvent2D.Create(Actor.ID, Obj.ID, Ord(IC.InteractionType)));
            if Assigned(IC.OnInteract) then
               IC.OnInteract(Actor.ID, Obj.ID);
         end;
      end;
   end;
end;

end.
