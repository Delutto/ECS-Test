unit Mario.Entities;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, raylib,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.RigidBody,
  P2D.Components.Sprite, P2D.Components.Animation,
  P2D.Components.Collider, P2D.Components.Tags,
  P2D.Components.TileMap, P2D.Components.Camera2D,
  Mario.ProceduralArt, Mario.Systems.Enemy;

// Entity factories
function CreatePlayer(AWorld: TWorld; AX, AY: Single): TEntity;
function CreateGoomba(AWorld: TWorld; AX, AY: Single): TEntity;
function CreateCoin(AWorld: TWorld; AX, AY: Single): TEntity;
function CreateTileMap(AWorld: TWorld): TEntity;
function CreateCamera(AWorld: TWorld): TEntity;

implementation

// ---------------------------------------------------------------------------
// Helper – adds a frame rectangle to an animation (columns-based spritesheet)
// ---------------------------------------------------------------------------
procedure AddFrame(AAnim: TAnimation; ACol: Integer; ARow: Integer = 0;
  AFrameW: Integer = 16; AFrameH: Integer = 16; ADur: Single = 0.12);
var R: TRectangle;
begin
  R.X := ACol * AFrameW;
  R.Y := ARow * AFrameH;
  R.Width  := AFrameW;
  R.Height := AFrameH;
  AAnim.AddFrame(R, ADur);
end;

// ---------------------------------------------------------------------------
function CreatePlayer(AWorld: TWorld; AX, AY: Single): TEntity;
var
  E   : TEntity;
  Tr  : TTransformComponent;
  RB  : TRigidBodyComponent;
  Spr : TSpriteComponent;
  Anim: TAnimationComponent;
  Col : TColliderComponent;
  A   : TAnimation;
begin
  E := AWorld.CreateEntity('Player');

  Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
  Tr.Position.Create(AX, AY);
  Tr.Scale.Create(1, 1);

  RB := TRigidBodyComponent(E.AddComponent(TRigidBodyComponent.Create));
  RB.GravityScale := 1.2;

  Spr := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
  Spr.Texture    := TexPlayer;
  Spr.SourceRect := RectangleCreate(0, 0, 16, 16);
  Spr.Origin.Create(0, 0);

  // Collider
  Col        := TColliderComponent(E.AddComponent(TColliderComponent.Create));
  Col.Tag    := ctPlayer;
  Col.Offset.Create(1, 0);
  Col.Size.Create(14, 16);

  // Animations (row 0 = small Mario)
  Anim := TAnimationComponent(E.AddComponent(TAnimationComponent.Create));

  A := TAnimation.Create('idle'); AddFrame(A, 0); Anim.AddAnimation(A);
  A := TAnimation.Create('walk'); AddFrame(A,1); AddFrame(A,2); AddFrame(A,3); Anim.AddAnimation(A);
  A := TAnimation.Create('run');  AddFrame(A,5,0,16,16,0.08); AddFrame(A,6,0,16,16,0.08); Anim.AddAnimation(A);
  A := TAnimation.Create('jump',False); AddFrame(A,4,0,16,16,0.5); Anim.AddAnimation(A);
  A := TAnimation.Create('dead',False); AddFrame(A,7,0,16,16,0.5); Anim.AddAnimation(A);
  Anim.Play('idle');

  E.AddComponent(TPlayerTag.Create);
  E.AddComponent(TPlayerComponent.Create);

  Result := E;
end;

// ---------------------------------------------------------------------------
function CreateGoomba(AWorld: TWorld; AX, AY: Single): TEntity;
var
  E   : TEntity;
  Tr  : TTransformComponent;
  RB  : TRigidBodyComponent;
  Spr : TSpriteComponent;
  Col : TColliderComponent;
  G   : TGoombaComponent;
begin
  E := AWorld.CreateEntity('Goomba');

  Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
  Tr.Position.Create(AX, AY);

  RB := TRigidBodyComponent(E.AddComponent(TRigidBodyComponent.Create));

  Spr := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
  Spr.Texture    := TexEnemy;
  Spr.SourceRect := RectangleCreate(0, 0, 16, 16);

  Col        := TColliderComponent(E.AddComponent(TColliderComponent.Create));
  Col.Tag    := ctEnemy;
  Col.Offset.Create(1, 0);
  Col.Size .Create(14, 16);

  E.AddComponent(TEnemyTag.Create);
  G := TGoombaComponent.Create;
  G.Speed     := 60;
  G.Direction := -1;

  E.AddComponent(G);

  Result := E;
end;

// ---------------------------------------------------------------------------
function CreateCoin(AWorld: TWorld; AX, AY: Single): TEntity;
var
  E   : TEntity;
  Tr  : TTransformComponent;
  Spr : TSpriteComponent;
  Col : TColliderComponent;
begin
  E := AWorld.CreateEntity('Coin');

  Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
  Tr.Position.Create(AX, AY);

  Spr := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
  Spr.Texture    := TexCoin;
  Spr.SourceRect := RectangleCreate(0, 0, 16, 16);

  Col           := TColliderComponent(E.AddComponent(TColliderComponent.Create));
  Col.Tag       := ctCoin;
  Col.IsTrigger := True;
  Col.Size.Create(12, 12);
  Col.Offset.Create(2, 2);

  E.AddComponent(TCoinTag.Create);
  Result := E;
end;

// ---------------------------------------------------------------------------
// Level map – 40 columns x 15 rows, 16x16 tiles
// Tile values: 0=air, 1=ground, 2=brick, 3=question-block, 4=coin-tile
// ---------------------------------------------------------------------------
const
  LEVEL_MAP: array[0..14] of string = (
  '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
  '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
  '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
  '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
  '0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,0,0,0',
  '0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
  '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0',
  '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
  '0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
  '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
  '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
  '1,1,1,1,1,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1',
  '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
  '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
  '1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1'
  );

function CreateTileMap(AWorld: TWorld): TEntity;
var
  E  : TEntity;
  TM : TTileMapComponent;
  Tr : TTransformComponent;
  R, C: Integer;
  Parts: TStringArray;
  Val, TTyp: Integer;
begin
  E := AWorld.CreateEntity('TileMap');

  Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
  Tr.Position.Create(0, 0);

  TM := TTileMapComponent(E.AddComponent(TTileMapComponent.Create));
  TM.TileWidth   := 16;
  TM.TileHeight  := 16;
  TM.TileSet     := TexTiles;
  TM.TileSetCols := 4;
  TM.SetSize(40, 15);

  for R := 0 to 14 do
  begin
    Parts := LEVEL_MAP[R].Split([',']);
    for C := 0 to High(Parts) do
    begin
      if C >= 40 then Break;
      Val := StrToIntDef(Trim(Parts[C]), 0);
      case Val of
        1: TTyp := TILE_SOLID;
        2: TTyp := TILE_SOLID;
        3: TTyp := TILE_SOLID;
        else TTyp := TILE_NONE;
      end;
      TM.SetTile(C, R, Val, TTyp);
    end;
  end;

  Result := E;
end;

// ---------------------------------------------------------------------------
function CreateCamera(AWorld: TWorld): TEntity;
var
  E   : TEntity;
  Tr  : TTransformComponent;
  Cam : TCamera2DComponent;
begin
  E := AWorld.CreateEntity('Camera');

  Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
  Tr.Position.Create(0, 0);

  Cam             := TCamera2DComponent(E.AddComponent(TCamera2DComponent.Create));
  Cam.Zoom        := 3.0;   // pixel-perfect scale for 16px tiles on 800px screen
  Cam.FollowSpeed := 6.0;
  Cam.UseBounds   := True;
  Cam.Bounds      := TRectF.Create(0, 0, 40*16, 15*16);

  Result := E;
end;

end.
