unit P2D.Systems.Lifetime;

{$mode objfpc}{$H+}

interface

uses
   P2D.Core.ComponentRegistry,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Components.Lifetime;

type
  { TLifetimeSystem
    Iterates all entities that carry TLifetimeComponent2D, decrements
    Remaining by ADelta every frame, and destroys the entity when it
    expires.  Runs at priority 2 (before physics) so that the entity is
    marked for destruction before any other system touches it this frame. }
   TLifetimeSystem = class(TSystem2D)
   private
      FLifetimeID: Integer;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
   end;

implementation

constructor TLifetimeSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 2;
   Name := 'LifetimeSystem';
end;

procedure TLifetimeSystem.Init;
begin
   inherited;

   RequireComponent(TLifetimeComponent2D);

   FLifetimeID := ComponentRegistry.GetComponentID(TLifetimeComponent2D);
end;

procedure TLifetimeSystem.Update(ADelta: Single);
var
   E: TEntity;
   LC: TLifetimeComponent2D;
begin
   for E in GetMatchingEntities do
   begin
      LC := TLifetimeComponent2D(E.GetComponentByID(FLifetimeID));
      if LC.Paused then
      begin
         Continue;
      end;

      LC.Remaining := LC.Remaining - ADelta;
      if LC.Remaining <= 0 then
      begin
         LC.Remaining := 0;
         // Fire optional callback BEFORE destruction
         if Assigned(LC.OnExpired) then
         begin
            LC.OnExpired(E.ID);
         end;
         World.DestroyEntity(E.ID);
      end;
   end;
end;

end.
