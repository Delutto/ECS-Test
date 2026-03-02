unit Mario.Systems.Enemy;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, raylib,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.RigidBody, P2D.Core.Component,
  P2D.Components.Sprite, P2D.Components.Tags, P2D.Utils.Math;

type
  TGoombaComponent = class(TComponent2D)
  public
    Speed    : Single;
    Direction: Single;  // -1 left, +1 right
    constructor Create; override;
  end;

  TEnemySystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorldBase); override;
    procedure Update(ADelta: Single); override;
  end;

implementation

constructor TGoombaComponent.Create;
begin
  inherited Create;
  Speed     := 60;
  Direction := -1;
end;

constructor TEnemySystem.Create(AWorld: TWorldBase);
begin
  inherited Create(AWorld);
  Priority := 3;
  Name     := 'EnemySystem';
end;

procedure TEnemySystem.Update(ADelta: Single);
var
  E   : TEntity;
  Tr  : TTransformComponent;
  RB  : TRigidBodyComponent;
  G   : TGoombaComponent;
  Spr : TSpriteComponent;
begin
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then Continue;
    if not E.HasComponent(TEnemyTag)          then Continue;
    if not E.HasComponent(TTransformComponent) then Continue;
    if not E.HasComponent(TRigidBodyComponent) then Continue;
    if not E.HasComponent(TGoombaComponent)   then Continue;

    Tr  := TTransformComponent(E.GetComponent(TTransformComponent));
    RB  := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
    G   := TGoombaComponent(E.GetComponent(TGoombaComponent));
    Spr := TSpriteComponent(E.GetComponent(TSpriteComponent));

    // Walk
    RB.Velocity.X := G.Speed * G.Direction;

    // Flip direction at edges (simple: detect no-ground ahead is complex;
    // instead reverse when hitting a wall = zero velocity after collision)
    if RB.Grounded and (Abs(RB.Velocity.X) < 1) then
      G.Direction := -G.Direction;

    // Flip sprite
    if Assigned(Spr) then
    begin
      if G.Direction < 0 then Spr.Flip := flHorizontal
      else Spr.Flip := flNone;
    end;

    // Kill if fell off map
    if Tr.Position.Y > 800 then
      World.DestroyEntity(E.ID);
  end;
end;

end.
