unit Mario.Systems.Input;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, raylib,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.RigidBody,
  P2D.Components.Tags, P2D.Utils.Math;

type
  TPlayerInputSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorld); override;
    procedure Update(ADelta: Single); override;
  end;

implementation

constructor TPlayerInputSystem.Create(AWorld: TWorld);
begin
  inherited Create(AWorld);
  Priority := 1;
  Name     := 'PlayerInputSystem';
end;

procedure TPlayerInputSystem.Update(ADelta: Single);
var
  E   : TEntity;
  Tr  : TTransformComponent;
  RB  : TRigidBodyComponent;
  PC  : TPlayerComponent;
  Speed: Single;
begin
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then Continue;
    if not E.HasComponent(TPlayerTag)       then Continue;
    if not E.HasComponent(TTransformComponent) then Continue;
    if not E.HasComponent(TRigidBodyComponent) then Continue;
    if not E.HasComponent(TPlayerComponent)   then Continue;

    Tr := TTransformComponent(E.GetComponent(TTransformComponent));
    RB := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
    PC := TPlayerComponent(E.GetComponent(TPlayerComponent));

    if PC.State = psDead then Continue;

    // Update invincibility
    if PC.InvFrames > 0 then PC.InvFrames := PC.InvFrames - ADelta;

    // Running modifier
    if IsKeyDown(KEY_LEFT_SHIFT) or IsKeyDown(KEY_Z) then
      Speed := PC.RunSpeed
    else
      Speed := PC.WalkSpeed;

    // Horizontal movement
    if IsKeyDown(KEY_LEFT) or IsKeyDown(KEY_A) then
    begin
      RB.Velocity.X := ApproachF(RB.Velocity.X, -Speed, 600 * ADelta);
      PC.State := psWalking;
    end else
    if IsKeyDown(KEY_RIGHT) or IsKeyDown(KEY_D) then
    begin
      RB.Velocity.X := ApproachF(RB.Velocity.X, Speed, 600 * ADelta);
      PC.State := psWalking;
    end else
    begin
      // Friction
      RB.Velocity.X := ApproachF(RB.Velocity.X, 0, 400 * ADelta);
      if Abs(RB.Velocity.X) < 1 then
      begin
        RB.Velocity.X := 0;
        if RB.Grounded then PC.State := psIdle;
      end;
    end;

    // Jump
    if (IsKeyPressed(KEY_SPACE) or IsKeyPressed(KEY_UP) or IsKeyPressed(KEY_W))
       and RB.Grounded then
    begin
      RB.Velocity.Y := PC.JumpForce;
      RB.Grounded   := False;
      PC.State      := psJumping;
    end;

    // Variable jump height (release early = lower jump)
    if (IsKeyReleased(KEY_SPACE) or IsKeyReleased(KEY_UP)) and
       (RB.Velocity.Y < -200) then
      RB.Velocity.Y := -200;

    if not RB.Grounded then
    begin
      if RB.Velocity.Y < 0 then PC.State := psJumping
      else PC.State := psFalling;
    end;

    // Kill zone (fell off map)
    if Tr.Position.Y > 800 then
    begin
      Dec(PC.Lives);
      if PC.Lives > 0 then
      begin
        Tr.Position := TVector2.Create(48, 400);
        RB.Velocity := TVector2.Create(0, 0);
        PC.State    := psIdle;
      end else
        PC.State := psDead;
    end;
  end;
end;

end.