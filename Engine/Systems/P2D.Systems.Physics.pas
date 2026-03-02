unit P2D.Systems.Physics;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.RigidBody;

const
  GRAVITY = 980.0; // pixels per second squared

type
  TPhysicsSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorld); override;
    procedure Update(ADelta: Single); override;
  end;

implementation

constructor TPhysicsSystem.Create(AWorld: TWorld);
begin
  inherited Create(AWorld);
  Priority := 10;
  Name     := 'PhysicsSystem';
end;

procedure TPhysicsSystem.Update(ADelta: Single);
var
  E   : TEntity;
  Tr  : TTransformComponent;
  RB  : TRigidBodyComponent;
begin
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then Continue;
    if not E.HasComponent(TTransformComponent) then Continue;
    if not E.HasComponent(TRigidBodyComponent)  then Continue;

    Tr := TTransformComponent(E.GetComponent(TTransformComponent));
    RB := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));

    if not (Tr.Enabled and RB.Enabled) then Continue;

    // Gravity
    if RB.UseGravity and not RB.Grounded then
      RB.Velocity.Y := RB.Velocity.Y + GRAVITY * RB.GravityScale * ADelta;

    // Clamp fall speed
    if RB.Velocity.Y > RB.MaxFallSpeed then
      RB.Velocity.Y := RB.MaxFallSpeed;

    // Apply acceleration
    RB.Velocity.X := RB.Velocity.X + RB.Acceleration.X * ADelta;
    RB.Velocity.Y := RB.Velocity.Y + RB.Acceleration.Y * ADelta;

    // Integrate position
    Tr.Position.X := Tr.Position.X + RB.Velocity.X * ADelta;
    Tr.Position.Y := Tr.Position.Y + RB.Velocity.Y * ADelta;

    // Reset per-frame state
    RB.Grounded := False;
  end;
end;

end.
"""

files['Pascal2D/Engine/Systems/P2D.Systems.Collision.pas'] = r"""unit P2D.Systems.Collision;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.RigidBody,
  P2D.Components.Collider, P2D.Components.TileMap,
  P2D.Components.Tags;

type
  TCollisionSystem = class(TSystem2D)
  private
    procedure SolveTileCollision(ATr: TTransformComponent;
                                 ARB: TRigidBodyComponent;
                                 ACol: TColliderComponent;
                                 AMap: TTileMapComponent;
                                 AMapTr: TTransformComponent);
    procedure SolveEntityCollisions;
  public
    constructor Create(AWorld: TWorld); override;
    procedure Update(ADelta: Single); override;
  end;

implementation

constructor TCollisionSystem.Create(AWorld: TWorld);
begin
  inherited Create(AWorld);
  Priority := 20;
  Name     := 'CollisionSystem';
end;

procedure TCollisionSystem.SolveTileCollision(ATr: TTransformComponent;
  ARB: TRigidBodyComponent; ACol: TColliderComponent;
  AMap: TTileMapComponent; AMapTr: TTransformComponent);
var
  R    : TRectF;
  ColL, ColR, RowT, RowB: Integer;
  C, Row: Integer;
  Tile : TTileData;
  TileR: TRectF;
  OverX, OverY: Single;
begin
  R := ACol.GetWorldRect(ATr.Position);

  ColL := Trunc((R.X - AMapTr.Position.X) / AMap.TileWidth);
  ColR := Trunc((R.Right - AMapTr.Position.X - 1) / AMap.TileWidth);
  RowT := Trunc((R.Y - AMapTr.Position.Y) / AMap.TileHeight);
  RowB := Trunc((R.Bottom - AMapTr.Position.Y - 1) / AMap.TileHeight);

  for Row := RowT to RowB do
    for C := ColL to ColR do
    begin
      Tile := AMap.GetTile(C, Row);
      if not Tile.Solid then Continue;

      TileR := AMap.GetTileWorldRect(C, Row);
      TileR.X := TileR.X + AMapTr.Position.X;
      TileR.Y := TileR.Y + AMapTr.Position.Y;

      if not R.Overlaps(TileR) then Continue;

      OverX := Min(R.Right, TileR.Right) - Max(R.X, TileR.X);
      OverY := Min(R.Bottom, TileR.Bottom) - Max(R.Y, TileR.Y);

      if OverX < OverY then
      begin
        // Horizontal resolve
        if ATr.Position.X < TileR.X then
          ATr.Position.X := ATr.Position.X - OverX
        else
          ATr.Position.X := ATr.Position.X + OverX;
        ARB.Velocity.X := 0;
      end else
      begin
        // Vertical resolve
        if ATr.Position.Y < TileR.Y then
        begin
          ATr.Position.Y := ATr.Position.Y - OverY;
          ARB.Grounded   := True;
          if ARB.Velocity.Y > 0 then ARB.Velocity.Y := 0;
        end else
        begin
          ATr.Position.Y := ATr.Position.Y + OverY;
          if ARB.Velocity.Y < 0 then ARB.Velocity.Y := 0;
        end;
      end;

      // Update R after resolve
      R := ACol.GetWorldRect(ATr.Position);
    end;
end;

procedure TCollisionSystem.SolveEntityCollisions;
var
  EA, EB: TEntity;
  TA, TB: TTransformComponent;
  CA, CB: TColliderComponent;
  RA, RB_: TRectF;
  PlayerComp: TPlayerComponent;
  EntList: array of TEntity;
  I, J: Integer;
  Count: Integer;
begin
  Count := 0;
  SetLength(EntList, World.Entities.GetAll.Count);
  for EA in World.Entities.GetAll do
  begin
    if EA.Alive and EA.HasComponent(TColliderComponent) and
       EA.HasComponent(TTransformComponent) then
    begin
      EntList[Count] := EA;
      Inc(Count);
    end;
  end;

  for I := 0 to Count - 2 do
    for J := I + 1 to Count - 1 do
    begin
      EA := EntList[I]; EB := EntList[J];
      TA := TTransformComponent(EA.GetComponent(TTransformComponent));
      TB := TTransformComponent(EB.GetComponent(TTransformComponent));
      CA := TColliderComponent(EA.GetComponent(TColliderComponent));
      CB := TColliderComponent(EB.GetComponent(TColliderComponent));

      RA := CA.GetWorldRect(TA.Position);
      RB_ := CB.GetWorldRect(TB.Position);
      if not RA.Overlaps(RB_) then Continue;

      // Player picks up coin
      if (CA.Tag = ctPlayer) and (CB.Tag = ctCoin) then
      begin
        if EA.HasComponent(TPlayerComponent) then
        begin
          PlayerComp := TPlayerComponent(EA.GetComponent(TPlayerComponent));
          Inc(PlayerComp.Coins);
          PlayerComp.Score := PlayerComp.Score + 200;
        end;
        World.DestroyEntity(EB.ID);
      end else
      if (CA.Tag = ctCoin) and (CB.Tag = ctPlayer) then
      begin
        if EB.HasComponent(TPlayerComponent) then
        begin
          PlayerComp := TPlayerComponent(EB.GetComponent(TPlayerComponent));
          Inc(PlayerComp.Coins);
          PlayerComp.Score := PlayerComp.Score + 200;
        end;
        World.DestroyEntity(EA.ID);
      end;

      // Player hits enemy
      if (CA.Tag = ctPlayer) and (CB.Tag = ctEnemy) then
      begin
        if EB.HasComponent(TPlayerComponent) then
        begin
          PlayerComp := TPlayerComponent(EB.GetComponent(TPlayerComponent));
          if PlayerComp.InvFrames <= 0 then
          begin
            PlayerComp.Score := PlayerComp.Score - 100;
            PlayerComp.InvFrames := 2.0;
          end;
        end;
      end;
    end;
end;

procedure TCollisionSystem.Update(ADelta: Single);
var
  E     : TEntity;
  Tr    : TTransformComponent;
  RB    : TRigidBodyComponent;
  Col   : TColliderComponent;
  MapE  : TEntity;
  TileM : TTileMapComponent;
  MapTr : TTransformComponent;
begin
  // Find the tilemap entity
  TileM := nil; MapTr := nil;
  for MapE in World.Entities.GetAll do
    if MapE.Alive and MapE.HasComponent(TTileMapComponent) then
    begin
      TileM := TTileMapComponent(MapE.GetComponent(TTileMapComponent));
      MapTr := TTransformComponent(MapE.GetComponent(TTransformComponent));
      Break;
    end;

  // Solve tile collisions for all rigid bodies
  if Assigned(TileM) then
    for E in World.Entities.GetAll do
    begin
      if not E.Alive then Continue;
      if not E.HasComponent(TTransformComponent) then Continue;
      if not E.HasComponent(TRigidBodyComponent)  then Continue;
      if not E.HasComponent(TColliderComponent)   then Continue;

      Tr  := TTransformComponent(E.GetComponent(TTransformComponent));
      RB  := TRigidBodyComponent(E.GetComponent(TRigidBodyComponent));
      Col := TColliderComponent(E.GetComponent(TColliderComponent));

      if Tr.Enabled and RB.Enabled and Col.Enabled then
        SolveTileCollision(Tr, RB, Col, TileM, MapTr);
    end;

  SolveEntityCollisions;
end;

end.
"""

files['Pascal2D/Engine/Systems/P2D.Systems.Animation.pas'] = r"""unit P2D.Systems.Animation;

{$mode objfpc}{$H+}

interface

uses
  P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Sprite, P2D.Components.Animation;

type
  TAnimationSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorld); override;
    procedure Update(ADelta: Single); override;
  end;

implementation

constructor TAnimationSystem.Create(AWorld: TWorld);
begin
  inherited Create(AWorld);
  Priority := 5;
  Name     := 'AnimationSystem';
end;

procedure TAnimationSystem.Update(ADelta: Single);
var
  E   : TEntity;
  Anim: TAnimationComponent;
  Spr : TSpriteComponent;
  Rect: TRectangle;
begin
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then Continue;
    if not E.HasComponent(TAnimationComponent) then Continue;
    if not E.HasComponent(TSpriteComponent)    then Continue;

    Anim := TAnimationComponent(E.GetComponent(TAnimationComponent));
    Spr  := TSpriteComponent(E.GetComponent(TSpriteComponent));

    if Anim.Enabled and Spr.Enabled then
    begin
      Anim.Tick(ADelta, Rect);
      Spr.SourceRect := Rect;
    end;
  end;
end;

end.
"""

files['Pascal2D/Engine/Systems/P2D.Systems.Camera.pas'] = r"""unit P2D.Systems.Camera;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, raylib,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.Camera2D, P2D.Components.Tags;

type
  TCameraSystem = class(TSystem2D)
  private
    FCamEntity: TEntity;
    FTarget   : TEntity;
    FScreenW  : Integer;
    FScreenH  : Integer;
  public
    constructor Create(AWorld: TWorld; AScreenW, AScreenH: Integer); reintroduce;
    procedure Init; override;
    procedure Update(ADelta: Single); override;
    procedure BeginCameraMode;
    procedure EndCameraMode;
    function  GetRaylibCamera: TCamera2D;
  end;

implementation

constructor TCameraSystem.Create(AWorld: TWorld; AScreenW, AScreenH: Integer);
begin
  inherited Create(AWorld);
  Priority := 15;
  Name     := 'CameraSystem';
  FScreenW := AScreenW;
  FScreenH := AScreenH;
end;

procedure TCameraSystem.Init;
begin
  FCamEntity := nil;
  FTarget    := nil;
  for var E in World.Entities.GetAll do
    if E.Alive and E.HasComponent(TCamera2DComponent) then
    begin FCamEntity := E; Break; end;
  for var E in World.Entities.GetAll do
    if E.Alive and E.HasComponent(TPlayerTag) then
    begin FTarget := E; Break; end;
end;

procedure TCameraSystem.Update(ADelta: Single);
var
  Cam    : TCamera2DComponent;
  CamTr  : TTransformComponent;
  TgtTr  : TTransformComponent;
  TargetX: Single;
  TargetY: Single;
  HalfW  : Single;
  HalfH  : Single;
begin
  if not Assigned(FCamEntity) then Exit;
  Cam   := TCamera2DComponent(FCamEntity.GetComponent(TCamera2DComponent));
  CamTr := TTransformComponent(FCamEntity.GetComponent(TTransformComponent));
  if not Assigned(Cam) or not Assigned(CamTr) then Exit;

  HalfW := FScreenW / 2;
  HalfH := FScreenH / 2;

  if Assigned(FTarget) and FTarget.Alive then
  begin
    TgtTr := TTransformComponent(FTarget.GetComponent(TTransformComponent));
    if Assigned(TgtTr) then
    begin
      TargetX := TgtTr.Position.X;
      TargetY := TgtTr.Position.Y;

      // Smooth follow
      CamTr.Position.X := CamTr.Position.X +
        (TargetX - CamTr.Position.X) * Cam.FollowSpeed * ADelta;
      CamTr.Position.Y := CamTr.Position.Y +
        (TargetY - CamTr.Position.Y) * Cam.FollowSpeed * ADelta;
    end;
  end;

  // Clamp camera to world bounds
  if Cam.UseBounds then
  begin
    if CamTr.Position.X < Cam.Bounds.X + HalfW then
      CamTr.Position.X := Cam.Bounds.X + HalfW;
    if CamTr.Position.Y < Cam.Bounds.Y + HalfH then
      CamTr.Position.Y := Cam.Bounds.Y + HalfH;
    if CamTr.Position.X > Cam.Bounds.Right - HalfW then
      CamTr.Position.X := Cam.Bounds.Right - HalfW;
    if CamTr.Position.Y > Cam.Bounds.Bottom - HalfH then
      CamTr.Position.Y := Cam.Bounds.Bottom - HalfH;
  end;

  Cam.RaylibCamera.Target.X := CamTr.Position.X;
  Cam.RaylibCamera.Target.Y := CamTr.Position.Y;
  Cam.RaylibCamera.Offset.X := HalfW;
  Cam.RaylibCamera.Offset.Y := HalfH;
  Cam.RaylibCamera.Zoom     := Cam.Zoom;
end;

procedure TCameraSystem.BeginCameraMode;
var Cam: TCamera2DComponent;
begin
  if not Assigned(FCamEntity) then Exit;
  Cam := TCamera2DComponent(FCamEntity.GetComponent(TCamera2DComponent));
  if Assigned(Cam) then BeginMode2D(Cam.RaylibCamera);
end;

procedure TCameraSystem.EndCameraMode;
begin
  EndMode2D;
end;

function TCameraSystem.GetRaylibCamera: TCamera2D;
var Cam: TCamera2DComponent;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Zoom := 1;
  if not Assigned(FCamEntity) then Exit;
  Cam := TCamera2DComponent(FCamEntity.GetComponent(TCamera2DComponent));
  if Assigned(Cam) then Result := Cam.RaylibCamera;
end;

end.
"""

files['Pascal2D/Engine/Systems/P2D.Systems.TileMap.pas'] = r"""unit P2D.Systems.TileMap;

{$mode objfpc}{$H+}

interface

uses
  raylib,
  P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.TileMap;

type
  TTileMapSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorld); override;
    procedure Update(ADelta: Single); override;
    procedure Render; override;
  end;

implementation

constructor TTileMapSystem.Create(AWorld: TWorld);
begin
  inherited Create(AWorld);
  Priority := 30;
  Name     := 'TileMapSystem';
end;

procedure TTileMapSystem.Update(ADelta: Single);
begin
  // Tilemap is static – nothing to update each frame
end;

procedure TTileMapSystem.Render;
var
  E   : TEntity;
  TM  : TTileMapComponent;
  Tr  : TTransformComponent;
  R, C: Integer;
  Tile: TTileData;
  Src : TRectangle;
  Dst : TRectangle;
begin
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then Continue;
    if not E.HasComponent(TTileMapComponent)  then Continue;
    if not E.HasComponent(TTransformComponent) then Continue;

    TM := TTileMapComponent(E.GetComponent(TTileMapComponent));
    Tr := TTransformComponent(E.GetComponent(TTransformComponent));

    if not (TM.Enabled and Tr.Enabled) then Continue;
    if TM.TileSet.Id = 0 then Continue;

    for R := 0 to TM.MapRows - 1 do
      for C := 0 to TM.MapCols - 1 do
      begin
        Tile := TM.GetTile(C, R);
        if Tile.TileID = TILE_NONE then Continue;

        Src := TM.GetTileRect(Tile.TileID - 1);
        Dst.X      := Tr.Position.X + C * TM.TileWidth;
        Dst.Y      := Tr.Position.Y + R * TM.TileHeight;
        Dst.Width  := TM.TileWidth;
        Dst.Height := TM.TileHeight;

        DrawTexturePro(TM.TileSet, Src, Dst,
                       Vector2(0, 0), 0, WHITE);
      end;
  end;
end;

end.
"""

files['Pascal2D/Engine/Systems/P2D.Systems.Render.pas'] = r"""unit P2D.Systems.Render;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, raylib,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.Sprite;

type
  TRenderSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorld); override;
    procedure Update(ADelta: Single); override;
    procedure Render; override;
  end;

implementation

constructor TRenderSystem.Create(AWorld: TWorld);
begin
  inherited Create(AWorld);
  Priority := 100;
  Name     := 'RenderSystem';
end;

procedure TRenderSystem.Update(ADelta: Single);
begin end;

procedure TRenderSystem.Render;
var
  E   : TEntity;
  Tr  : TTransformComponent;
  Spr : TSpriteComponent;
  Src : TRectangle;
  Dst : TRectangle;
  Org : TVector2;
  ScX : Single;
begin
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then Continue;
    if not E.HasComponent(TSpriteComponent)    then Continue;
    if not E.HasComponent(TTransformComponent) then Continue;

    Spr := TSpriteComponent(E.GetComponent(TSpriteComponent));
    Tr  := TTransformComponent(E.GetComponent(TTransformComponent));

    if not (Spr.Enabled and Tr.Enabled and Spr.Visible) then Continue;
    if Spr.Texture.Id = 0 then Continue;

    Src := Spr.SourceRect;

    // Apply flip
    ScX := 1;
    if Spr.Flip in [flHorizontal, flBoth] then ScX := -1;
    Src.Width := Src.Width * ScX;

    Dst.X      := Tr.Position.X;
    Dst.Y      := Tr.Position.Y;
    Dst.Width  := Abs(Src.Width)  * Tr.Scale.X;
    Dst.Height := Abs(Src.Height) * Tr.Scale.Y;

    Org.X := Spr.Origin.X * Tr.Scale.X;
    Org.Y := Spr.Origin.Y * Tr.Scale.Y;

    DrawTexturePro(Spr.Texture, Src, Dst, Org, Tr.Rotation,
                   RayColor(Spr.Tint.R, Spr.Tint.G, Spr.Tint.B, Spr.Tint.A));
  end;
end;

end.