unit Mario.Systems.Enemy;

{$mode objfpc}
{$H+}

{ ── Goomba system with FSM integration ──────────────────────────────────────
  State machine (TStateMachineComponent2D):
    gsWalking (0) — normal patrol; reversed on wall contact.
    gsStomped (1) — frozen, flattened sprite, countdown to despawn.

  Transition flow:
    TGameRulesSystem.HandleEnemyCollision
        → FSM.RequestTransition(Ord(gsStomped))
    Next TStateMachineSystem2D.Update
        → FSM.Tick → OnExit(gsWalking) + OnEnter(gsStomped)
        → TEnemySystem.OnGoombaEnterStomped:
              freeze velocity, flatten scale, grey tint, unpause lifetime
    TLifetimeSystem (0.45 s later)
        → World.DestroyEntity(Goomba)
  ─────────────────────────────────────────────────────────────────────────── }

interface

uses
   SysUtils,
   raylib,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Core.ComponentRegistry,
   P2D.Components.Transform,
   P2D.Components.RigidBody,
   P2D.Components.Sprite,
   P2D.Components.Animation,
   P2D.Components.StateMachine,
   P2D.Components.Lifetime,
   P2D.Utils.Math,
   Mario.Common,
   Mario.Components.Player,
   Mario.Components.Enemy;

type
   TEnemySystem = class(TSystem2D)
   private
      FTransformID: Integer;
      FRigidBodyID: Integer;
      FGoombaID: Integer;
      FSpriteID: Integer;
      FAnimID: Integer;
      FFSMID: Integer;
      FLifetimeID: Integer;

    { ── FSM callbacks (bound to all Goomba entities in Init) ── }
      procedure OnGoombaEnterState(AEntityID: Cardinal; AStateID: TStateID);
      procedure OnGoombaExitState(AEntityID: Cardinal; AStateID: TStateID);
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
   end;

implementation

{ TEnemySystem }

constructor TEnemySystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);
   Priority := 3;
   Name := 'EnemySystem';
end;

procedure TEnemySystem.Init;
var
   E: TEntity;
   FSM: TStateMachineComponent2D;
begin
   inherited;

   RequireComponent(TEnemyTag);
   RequireComponent(TTransformComponent);
   RequireComponent(TRigidBodyComponent);
   RequireComponent(TGoombaComponent);
   RequireComponent(TStateMachineComponent2D);

   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
   FRigidBodyID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
   FGoombaID := ComponentRegistry.GetComponentID(TGoombaComponent);
   FSpriteID := ComponentRegistry.GetComponentID(TSpriteComponent);
   FAnimID := ComponentRegistry.GetComponentID(TAnimationComponent);
   FFSMID := ComponentRegistry.GetComponentID(TStateMachineComponent2D);
   FLifetimeID := ComponentRegistry.GetComponentID(TLifetimeComponent2D);

   { Attach this system's callbacks to every Goomba entity that already
   exists (created by LoadLevel before World.Init ran). }
   for E In GetMatchingEntities do
   begin
      FSM := TStateMachineComponent2D(E.GetComponentByID(FFSMID));
      if Not Assigned(FSM) then
      begin
         Continue
      end;
      FSM.OnEnter := @OnGoombaEnterState;
      FSM.OnExit := @OnGoombaExitState;
   end;
end;

{ ── FSM callback: fires when the Goomba ENTERS a new state ─────────────── }
procedure TEnemySystem.OnGoombaEnterState(AEntityID: Cardinal; AStateID: TStateID);
var
   E: TEntity;
   RB: TRigidBodyComponent;
   Spr: TSpriteComponent;
   Anim: TAnimationComponent;
   Tr: TTransformComponent;
   LT: TLifetimeComponent2D;
begin
   E := World.GetEntity(AEntityID);
   if Not Assigned(E) Or Not E.Alive then
   begin
      Exit
   end;

   case TGoombaState(AStateID) of
      gsWalking:
{ Nothing special — entity starts here via SetInitialState. } begin
      end;
      gsStomped:
      begin
         { 1. Freeze horizontal movement; disable gravity so it stays put. }
         RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
         if Assigned(RB) then
         begin
            RB.Velocity.X := 0;
            RB.Velocity.Y := 0;
            RB.UseGravity := False;
         end;

         { 2. Visually flatten: squash Y scale to 30% to mimic a stomped sprite.
         Disable the collider tag implicitly — GameRules checks entity alive. }
         Spr := TSpriteComponent(E.GetComponentByID(FSpriteID));
         if Assigned(Spr) then
         begin
            Spr.Tint := ColorCreate(180, 120, 80, 255)
         end;   { brownish death tint }

         Anim := TAnimationComponent(E.GetComponentByID(FAnimID));
         if Assigned(Anim) then
         begin
            Anim.Play('stomped')
         end;

         { 3. Transform: squash the sprite vertically at the bottom of the tile. }
         Tr := TTransformComponent(E.GetComponentByID(FTransformID));
         if Assigned(Tr) then
         begin
            Tr.Position.Y := Tr.Position.Y + 11; { shift down so feet stay on ground }
            Tr.Scale.Y := 0.30;               { flatten to 30% height             }
         end;

         { 4. Unpause the pre-attached lifetime counter so TLifetimeSystem will destroy this entity after 0.45 s. }
         LT := TLifetimeComponent2D(E.GetComponentByID(FLifetimeID));
         if Assigned(LT) then
         begin
            LT.Duration := 0.45;
            LT.Remaining := 0.45;
            LT.Paused := False;
         end;
      end;
   end;
end;

{ ── FSM callback: fires when the Goomba EXITS a state ──────────────────── }
procedure TEnemySystem.OnGoombaExitState(AEntityID: Cardinal; AStateID: TStateID);
begin
  { Nothing needed for this demo — extend here for future states. }
end;

{ ── Update: only drives walking-state logic ─────────────────────────────── }
procedure TEnemySystem.Update(ADelta: Single);
var
   E: TEntity;
   Tr: TTransformComponent;
   RB: TRigidBodyComponent;
   G: TGoombaComponent;
   Spr: TSpriteComponent;
   FSM: TStateMachineComponent2D;
begin
   for E In GetMatchingEntities do
   begin
      FSM := TStateMachineComponent2D(E.GetComponentByID(FFSMID));
      if Not Assigned(FSM) then
      begin
         Continue
      end;

    { Skip all walking logic while the Goomba is stomped — it just waits
      for TLifetimeSystem to destroy it. }
      if TGoombaState(FSM.CurrentState) = gsStomped then
      begin
         Continue
      end;

      Tr := TTransformComponent(E.GetComponentByID(FTransformID));
      RB := TRigidBodyComponent(E.GetComponentByID(FRigidBodyID));
      G := TGoombaComponent(E.GetComponentByID(FGoombaID));
      Spr := TSpriteComponent(E.GetComponentByID(FSpriteID));

      if G.WallCooldown > 0 then
      begin
         G.WallCooldown := G.WallCooldown - ADelta
      end;

      if RB.OnWall And (G.WallCooldown <= 0) then
      begin
         G.Direction := -G.Direction;
         G.WallCooldown := GOOMBA_WALL_COOLDOWN;
      end;

      RB.Velocity.X := G.Speed * G.Direction;

      if Assigned(Spr) then
      begin
         if G.Direction < 0 then
         begin
            Spr.Flip := flHorizontal
         end
         else
         begin
            Spr.Flip := flNone
         end;
      end;

      if Tr.Position.Y > PLAYER_KILL_ZONE then
      begin
         World.DestroyEntity(E.ID)
      end;
   end;
end;

end.
