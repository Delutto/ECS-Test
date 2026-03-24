unit P2D.Systems.Tween;

{$mode objfpc}
{$H+}

interface

uses
   P2D.Core.ComponentRegistry,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Components.Tween;

type
  { TTweenSystem2D
    Drives all tween tracks each frame. Priority 3 — after Lifetime/Timer,
    before physics, so tweened values (position, scale, alpha) are up to
    date when systems read them. }
   TTweenSystem2D = class(TSystem2D)
   private
      FTweenID: Integer;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
   end;

implementation

constructor TTweenSystem2D.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 3;
   Name := 'TweenSystem';
end;

procedure TTweenSystem2D.Init;
begin
   inherited;

   RequireComponent(TTweenComponent2D);
   FTweenID := ComponentRegistry.GetComponentID(TTweenComponent2D);
end;

procedure TTweenSystem2D.Update(ADelta: Single);
var
   E: TEntity;
   TC: TTweenComponent2D;
begin
   for E In GetMatchingEntities do
   begin
      TC := TTweenComponent2D(E.GetComponentByID(FTweenID));
      TC.Tick(ADelta, E.ID);
   end;
end;

end.
