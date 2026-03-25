program P2DGE_Showcase;
{$mode objfpc}{$H+}
{ P2DGE Showcase entry point.
  Listing component units here triggers their initialization sections
  (ComponentRegistry.Register calls) before the engine starts. }
uses
  SysUtils,Showcase.Game,
  P2D.Components.Health,P2D.Components.Tag,P2D.Components.Inventory,
  P2D.Components.Projectile,P2D.Components.Interactable,P2D.Components.LightEmitter,
  P2D.Components.DayNight,P2D.Components.Dialog,P2D.Components.Pathfinder,
  P2D.Components.Chunk,P2D.Components.Transform,P2D.Components.Sprite,
  P2D.Components.Animation,P2D.Components.RigidBody,P2D.Components.Collider,
  P2D.Components.Camera2D,P2D.Components.ParallaxLayer,P2D.Components.ParticleEmitter,
  P2D.Components.StateMachine,P2D.Components.Timer,P2D.Components.Tween,
  P2D.Components.Text,P2D.Components.TileMap,P2D.Components.InputMap,
  P2D.Components.MusicPlayer,P2D.Components.Lifetime,
  Showcase.Scene.Builder;
var Game:TShowcaseGame;
begin
  Game:=TShowcaseGame.Create;
  try Game.Run;
  finally Game.Free;end;
end.
