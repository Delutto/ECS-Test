program mario_demo;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, P2D.Core.Component, P2D.Core.Engine, P2D.Core.Entity,
  P2D.Core.System, P2D.Core.Types, P2D.Core.World, P2D.Components.Animation,
  P2D.Components.Camera2D, P2D.Components.Collider, P2D.Components.RigidBody,
  P2D.Components.Sprite, P2D.Components.Tags, P2D.Components.TileMap,
  P2D.Components.Transform, P2D.Systems.Animation, P2D.Systems.Camera,
  P2D.Systems.Collision, P2D.Systems.Physics, P2D.Systems.Render,
  P2D.Systems.TileMap, P2D.Utils.Logger, P2D.Utils.Math, Mario.Entities,
  Mario.Game, Mario.Level, Mario.ProceduralArt, Mario.Systems.Enemy,
  Mario.Systems.HUD, Mario.Systems.Input, Mario.Systems.Player;

var
  Game: TMarioGame;
begin
  Game := TMarioGame.Create;
  try
    Game.Run;
  finally
    Game.Free;
  end;
end.