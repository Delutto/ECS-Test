program P2DGE_Showcase;
{$mode objfpc}{$H+}
uses
   SysUtils,
   Showcase.Game,
   P2D.Components.Health,
   P2D.Components.Tag,
   P2D.Components.Inventory,
   P2D.Components.Projectile,
   P2D.Components.Interactable,
   P2D.Components.LightEmitter,
   P2D.Components.DayNight,
   P2D.Components.Dialog,
   P2D.Components.Pathfinder,
   P2D.Components.Chunk,
   Showcase.Scene.Builder;

var
   Game: TShowcaseGame;
begin
   Game := TShowcaseGame.Create;
   try
      Game.Run;
   finally
      Game.Free;
   end;
end.
