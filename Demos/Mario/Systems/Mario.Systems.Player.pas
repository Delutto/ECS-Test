unit Mario.Systems.Player;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, raylib,
   P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Components.Transform, P2D.Components.RigidBody,
   P2D.Components.Sprite, P2D.Components.Animation,
   P2D.Components.Tags, P2D.Components.InputMap,
   P2D.Components.Collider, P2D.Components.TileMap,
   P2D.Utils.Math;

const
   PLAYER_SPAWN_X   : Single = 48.0;
   PLAYER_SPAWN_Y   : Single = 100.0;
   PLAYER_KILL_ZONE : Single = 400.0;
   RESPAWN_INV_TIME : Single = 2.5;

type
   TPlayerPhysicsSystem = class(TSystem2D)
   private
      FTileMap: TTileMapComponent;
      FTileMapTr: TTransformComponent;
      function IsGrounded(RB: TRigidBodyComponent; Tr: TTransformComponent; Col: TColliderComponent): Boolean;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure FixedUpdate(AFixedDelta: Single); override;
   end;

   TPlayerAnimSystem = class(TSystem2D)
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
   end;

implementation

uses
   Mario.Events, P2D.Core.InputManager;

{ TPlayerPhysicsSystem }

constructor TPlayerPhysicsSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);
   Priority := 9;
   Name     := 'PlayerPhysicsSystem';
end;

procedure TPlayerPhysicsSystem.Init;
var
  E: TEntity;
begin
   inherited;
   RequireComponent(TPlayerTag);
   RequireComponent(TTransformComponent);
   RequireComponent(TRigidBodyComponent);
   RequireComponent(TPlayerComponent);
   RequireComponent(TInputMapComponent);
   RequireComponent(TColliderComponent);

   // Encontrar o tilemap
   for E in World.Entities.GetAll do
     if E.Alive and E.HasComponent(TTileMapComponent) then
     begin
       FTileMap := TTileMapComponent(E.GetComponent(TTileMapComponent));
       FTileMapTr := TTransformComponent(E.GetComponent(TTransformComponent));
       Break;
     end;
end;

function TPlayerPhysicsSystem.IsGrounded(RB: TRigidBodyComponent; Tr: TTransformComponent; Col: TColliderComponent): Boolean;
const
  CHECK_DIST = 2.0;
var
  R: TRectF;
  TileX, TileY: Integer;
  Tile: TTileData;
  WorldY: Single;
begin
  if RB.Grounded then
    Exit(True);

  if not Assigned(FTileMap) or not Assigned(FTileMapTr) then
    Exit(False);

  R := Col.GetWorldRect(Tr.Position);
  TileX := Trunc((R.X + R.W / 2 - FTileMapTr.Position.X) / FTileMap.TileWidth);
  TileY := Trunc((R.Y + R.H - FTileMapTr.Position.Y) / FTileMap.TileHeight);

  Tile := FTileMap.GetTile(TileX, TileY);
  if Tile.Solid then
  begin
    WorldY := FTileMapTr.Position.Y + TileY * FTileMap.TileHeight;
    if Abs(R.Y + R.H - WorldY) < CHECK_DIST then
      Exit(True);
  end;
  Result := False;
end;

procedure TPlayerPhysicsSystem.Update(ADelta: Single);
begin
   // Vazio
end;

procedure TPlayerPhysicsSystem.FixedUpdate(AFixedDelta: Single);
var
   E    : TEntity;
   Tr   : TTransformComponent;
   RB   : TRigidBodyComponent;
   PC   : TPlayerComponent;
   IM   : TInputMapComponent;
   Col  : TColliderComponent;
   Speed: Single;
   JumpPressed: Boolean;
begin
   for E in GetMatchingEntities do
   begin
      if not E.Alive then Continue;

      Tr  := TTransformComponent(E.GetComponent(TTransformComponent));
      RB  := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
      PC  := TPlayerComponent(E.GetComponent(TPlayerComponent));
      IM  := TInputMapComponent(E.GetComponent(TInputMapComponent));
      Col := TColliderComponent(E.GetComponent(TColliderComponent));

      if PC.State = psDead then Continue;

      // --- Leitura direta do input ---
      PC.WantsRun       := IM.IsDown('Run');
      PC.WantsMoveLeft  := IM.IsDown('MoveLeft');
      PC.WantsMoveRight := IM.IsDown('MoveRight');
      JumpPressed       := IM.IsPressed('Jump');
      PC.WantsJumpCut   := IM.IsReleased('Jump');

      // --- Velocidade horizontal ---
      if PC.WantsRun then
         Speed := PC.RunSpeed
      else
         Speed := PC.WalkSpeed;

      if PC.WantsMoveLeft then
      begin
         RB.Velocity.X := ApproachF(RB.Velocity.X, -Speed, 600 * AFixedDelta);
         if PC.WantsRun then PC.State := psRunning else PC.State := psWalking;
      end
      else if PC.WantsMoveRight then
      begin
         RB.Velocity.X := ApproachF(RB.Velocity.X, Speed, 600 * AFixedDelta);
         if PC.WantsRun then PC.State := psRunning else PC.State := psWalking;
      end
      else
      begin
         RB.Velocity.X := ApproachF(RB.Velocity.X, 0, 400 * AFixedDelta);
         if Abs(RB.Velocity.X) < 1.0 then
         begin
            RB.Velocity.X := 0.0;
            if RB.Grounded then PC.State := psIdle;
         end;
      end;

      // --- Pulo: só se estiver no chão (física ou verificação direta) ---
      if JumpPressed and IsGrounded(RB, Tr, Col) then
      begin
         RB.Velocity.Y := PC.JumpForce;
         RB.Grounded   := False;
         PC.State      := psJumping;
         World.EventBus.Publish(TPlayerJumpEvent.Create);
      end;

      // --- Corte de pulo ---
      if PC.WantsJumpCut then
      begin
         if RB.Velocity.Y < -200 then RB.Velocity.Y := -200;
         PC.WantsJumpCut := False;
      end;

      // --- Estado aéreo ---
      if not RB.Grounded then
      begin
         if RB.Velocity.Y < 0 then PC.State := psJumping
         else PC.State := psFalling;
      end;

      // --- Kill zone ---
      if Tr.Position.Y > PLAYER_KILL_ZONE then
      begin
         Dec(PC.Lives);
         if PC.Lives > 0 then
         begin
            Tr.Position := Vector2Create(PLAYER_SPAWN_X, PLAYER_SPAWN_Y);
            RB.Velocity := Vector2Create(0, 0);
            RB.Acceleration := Vector2Create(0, 0);
            RB.Grounded := False;
            PC.InvFrames := RESPAWN_INV_TIME;
            PC.State := psIdle;
         end
         else
            PC.State := psDead;
      end;
   end;
end;

{ TPlayerAnimSystem }

constructor TPlayerAnimSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);
   Priority := 7;
   Name     := 'PlayerAnimSystem';
end;

procedure TPlayerAnimSystem.Init;
begin
   inherited;
   RequireComponent(TPlayerTag);
   RequireComponent(TPlayerComponent);
   RequireComponent(TRigidBodyComponent);
   RequireComponent(TSpriteComponent);
   RequireComponent(TAnimationComponent);
end;

procedure TPlayerAnimSystem.Update(ADelta: Single);
var
   E   : TEntity;
   PC  : TPlayerComponent;
   RB  : TRigidBodyComponent;
   Spr : TSpriteComponent;
   Anim: TAnimationComponent;
begin
   for E in GetMatchingEntities do
   begin
      if not E.Alive then Continue;
      PC   := TPlayerComponent(E.GetComponent(TPlayerComponent));
      RB   := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
      Spr  := TSpriteComponent(E.GetComponent(TSpriteComponent));
      Anim := TAnimationComponent(E.GetComponent(TAnimationComponent));

      if RB.Velocity.X < -5 then
         Spr.Flip := flHorizontal
      else if RB.Velocity.X > 5 then
         Spr.Flip := flNone;

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
