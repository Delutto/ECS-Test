unit Mario.Systems.Player;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, raylib,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.RigidBody,
  P2D.Components.Sprite, P2D.Components.Animation, P2D.Components.Tags;

type
  TPlayerAnimSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorldBase); override;
    procedure Update(ADelta: Single); override;
  end;

implementation

constructor TPlayerAnimSystem.Create(AWorld: TWorldBase);
begin
  inherited Create(AWorld);
  Priority := 7;
  Name     := 'PlayerAnimSystem';
end;

procedure TPlayerAnimSystem.Update(ADelta: Single);
var
  E   : TEntity;
  PC  : TPlayerComponent;
  RB  : TRigidBodyComponent;
  Spr : TSpriteComponent;
  Anim: TAnimationComponent;
begin
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then Continue;
    if not E.HasComponent(TPlayerTag)         then Continue;
    if not E.HasComponent(TPlayerComponent)   then Continue;
    if not E.HasComponent(TRigidBodyComponent) then Continue;
    if not E.HasComponent(TSpriteComponent)   then Continue;
    if not E.HasComponent(TAnimationComponent) then Continue;

    PC   := TPlayerComponent(E.GetComponent(TPlayerComponent));
    RB   := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
    Spr  := TSpriteComponent(E.GetComponent(TSpriteComponent));
    Anim := TAnimationComponent(E.GetComponent(TAnimationComponent));

    // Flip sprite based on direction
    if RB.Velocity.X < -5 then Spr.Flip := flHorizontal
    else if RB.Velocity.X > 5 then Spr.Flip := flNone;

    // Choose animation
    case PC.State of
      psIdle    : Anim.Play('idle');
      psWalking : Anim.Play('walk');
      psRunning : Anim.Play('run');
      psJumping,
      psFalling : Anim.Play('jump');
      psDead    : Anim.Play('dead');
    end;
  end;
end;

end.
