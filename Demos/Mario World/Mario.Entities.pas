unit Mario.Entities;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, raylib,
  P2D.Common,
  P2D.Core.Types,
  P2D.Core.Entity,
  P2D.Core.World,
  P2D.Core.ResourceManager,
  P2D.Components.Transform,
  P2D.Components.RigidBody,
  P2D.Components.Sprite,
  P2D.Components.Animation,
  P2D.Components.Collider,
  P2D.Components.TileMap,
  P2D.Components.Camera2D,
  P2D.Components.InputMap,
  P2D.Components.MusicPlayer,
  P2D.Components.StateMachine,   { TStateMachineComponent2D }
  P2D.Components.Lifetime,       { TLifetimeComponent2D     }
  Mario.Systems.Enemy,
  Mario.Common,
  Mario.Components.Player,
  Mario.Components.Enemy,
  Mario.InputSetup;

function CreatePlayer(AWorld: TWorld; AX, AY: Single): TEntity;
function CreateGoomba(AWorld: TWorld; AX, AY: Single): TEntity;
function CreateCoin(AWorld: TWorld; AX, AY: Single): TEntity;
function CreateTileMap(AWorld: TWorld): TEntity;
function CreateCamera(AWorld: TWorld; Target: TEntity = nil): TEntity;
function CreateMusicPlayer(AWorld: TWorld; const AFileName: string; AAutoPlay: Boolean = True; ALoop: Boolean = True; AVolume: Single  = 1.0): TEntity;

implementation

uses
  Mario.Assets;

{ ── Helper de frames de animação ─────────────────────────────────────────── }
procedure AddFrame(AAnim: TAnimation; ACol, ARow, AFrameW, AFrameH: Integer;
                   ADur: Single);
var
  Rect: TRectangle;
begin
  Rect.X      := ACol * AFrameW;
  Rect.Y      := ARow * AFrameH;
  Rect.Width  := -AFrameW;  { negative = sprite faces left on sheet }
  Rect.Height := AFrameH;
  AAnim.AddFrame(Rect, ADur);
end;

{ ── CreatePlayer ─────────────────────────────────────────────────────────── }
function CreatePlayer(AWorld: TWorld; AX, AY: Single): TEntity;
var
  E    : TEntity;
  Tr   : TTransformComponent;
  RB   : TRigidBodyComponent;
  Spr  : TSpriteComponent;
  Col  : TColliderComponent;
  Anim : TAnimationComponent;
  Clip : TAnimation;
  IM   : TInputMapComponent;
  FSM  : TStateMachineComponent2D;
  Tex  : TTexture2D;
begin
  E := AWorld.CreateEntity('Player');

  Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
  Tr.Position := Vector2Create(AX, AY - (FRAME_H - 16));
  Tr.Scale    := Vector2Create(1, 1);

  RB              := TRigidBodyComponent(E.AddComponent(TRigidBodyComponent.Create));
  RB.GravityScale := 1.2;

  Tex := TResourceManager2D.Instance.LoadTexture(PLAYER_SHEET_PATH);

  Spr             := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
  Spr.Texture     := Tex;
  Spr.OwnsTexture := False;
  Spr.SourceRect  := RectangleCreate(0, 0, -FRAME_W, FRAME_H);
  Spr.Origin      := Vector2Create(0, 0);

  Col        := TColliderComponent(E.AddComponent(TColliderComponent.Create));
  Col.Tag    := ctPlayer;
  Col.Offset := Vector2Create(1, 0);
  Col.Size   := Vector2Create(14, FRAME_H);

  Anim := TAnimationComponent(E.AddComponent(TAnimationComponent.Create));

  { Row 0 }
  Clip := TAnimation.Create('idle', True);
  AddFrame(Clip, 0, 0, FRAME_W, FRAME_H, 5.12);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('duck', True);
  AddFrame(Clip, 1, 0, FRAME_W, FRAME_H, 0.12);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('walk', True);
  AddFrame(Clip, 2, 0, FRAME_W, FRAME_H, 0.05);
  AddFrame(Clip, 3, 0, FRAME_W, FRAME_H, 0.05);
  AddFrame(Clip, 4, 0, FRAME_W, FRAME_H, 0.05);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('run', True);
  AddFrame(Clip, 5, 0, FRAME_W, FRAME_H, 0.02);
  AddFrame(Clip, 6, 0, FRAME_W, FRAME_H, 0.02);
  AddFrame(Clip, 7, 0, FRAME_W, FRAME_H, 0.02);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('skid', True);
  AddFrame(Clip, 8, 0, FRAME_W, FRAME_H, 0.12);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('pipe', True);
  AddFrame(Clip, 9, 0, FRAME_W, FRAME_H, 0.12);
  Anim.AddAnimation(Clip);

  { Row 1 }
  Clip := TAnimation.Create('jump', False);
  AddFrame(Clip, 0, 1, FRAME_W, FRAME_H, 0.5);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('fall', False);
  AddFrame(Clip, 1, 1, FRAME_W, FRAME_H, 0.5);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('run_jump', False);
  AddFrame(Clip, 2, 1, FRAME_W, FRAME_H, 0.5);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('spin', True);
  AddFrame(Clip, 3, 1, FRAME_W, FRAME_H, 0.03);
  AddFrame(Clip, 4, 1, FRAME_W, FRAME_H, 0.03);
  AddFrame(Clip, 5, 1, FRAME_W, FRAME_H, 0.03);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('slide', False);
  AddFrame(Clip, 6, 1, FRAME_W, FRAME_H, 0.8);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('kick', False);
  AddFrame(Clip, 7, 1, FRAME_W, FRAME_H, 0.2);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('victory', True);
  AddFrame(Clip, 8, 1, FRAME_W, FRAME_H, 0.12);
  Anim.AddAnimation(Clip);

  Clip := TAnimation.Create('dead', True);
  AddFrame(Clip, 1, 1, FRAME_W, FRAME_H, 0.5);
  Anim.AddAnimation(Clip);

  Anim.Play('idle');

  E.AddComponent(TPlayerComponent.Create);

  IM         := TInputMapComponent(E.AddComponent(TInputMapComponent.Create));
  IM.MapName := PLAYER_MAP;

  { ── FSM: one state per TPlayerState value ────────────────────────────────
    OnEnter / OnExit callbacks are set by TPlayerPhysicsSystem.Init once the
    system has been registered and the entity already exists.
    SetInitialState stamps the current state without firing any callback. }
  FSM := TStateMachineComponent2D(E.AddComponent(TStateMachineComponent2D.Create));
  FSM.OwnerID := E.ID;
  FSM.SetInitialState(Ord(psIdle));

  Result := E;
end;

{ ── CreateGoomba ─────────────────────────────────────────────────────────── }
function CreateGoomba(AWorld: TWorld; AX, AY: Single): TEntity;
var
  E    : TEntity;
  Tr   : TTransformComponent;
  Spr  : TSpriteComponent;
  Col  : TColliderComponent;
  G    : TGoombaComponent;
  Anim : TAnimationComponent;
  Clip : TAnimation;
  FSM  : TStateMachineComponent2D;
  LT   : TLifetimeComponent2D;
begin
  E := AWorld.CreateEntity('Goomba');

  Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
  Tr.Position := Vector2Create(AX, AY);

  E.AddComponent(TRigidBodyComponent.Create);

  Spr             := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
  Spr.Texture     := TexEnemy;
  Spr.OwnsTexture := False;
  Spr.SourceRect  := RectangleCreate(0, 0, 16, 16);

  Col        := TColliderComponent(E.AddComponent(TColliderComponent.Create));
  Col.Tag    := ctEnemy;
  Col.Offset := Vector2Create(1, 0);
  Col.Size   := Vector2Create(14, 16);

  Anim := TAnimationComponent(E.AddComponent(TAnimationComponent.Create));

  Clip := TAnimation.Create('walk', True);
  AddFrame(Clip, 0, 0, 16, 16, 0.20);
  AddFrame(Clip, 1, 0, 16, 16, 0.20);
  Anim.AddAnimation(Clip);

  { 'stomped' = single flat frame (Col 0 of the enemy sheet, tint will be
    changed by TEnemySystem.OnGoombaEnterStomped to give a visual cue) }
  Clip := TAnimation.Create('stomped', False);
  AddFrame(Clip, 0, 0, 16, 16, 1.0);
  Anim.AddAnimation(Clip);

  Anim.Play('walk');

  E.AddComponent(TEnemyTag.Create);

  G           := TGoombaComponent(E.AddComponent(TGoombaComponent.Create));
  G.Speed     := 60;
  G.Direction := -1;

  { ── FSM: gsWalking (0) or gsStomped (1) ──────────────────────────────────
    Callbacks assigned by TEnemySystem.Init.
    SetInitialState avoids a spurious OnEnter(gsWalking) before callbacks
    are attached. }
  FSM := TStateMachineComponent2D(E.AddComponent(TStateMachineComponent2D.Create));
  FSM.OwnerID := E.ID;
  FSM.SetInitialState(Ord(gsWalking));

  { ── Pre-attached lifetime component (starts paused) ──────────────────────
    The TLifetimeSystem sees this entity from the first frame (cache hit).
    TEnemySystem.OnGoombaEnterStomped unpausages and sets the duration
    when the Goomba is stomped.  Avoids dynamic component addition which
    would require cache invalidation. }
  LT          := TLifetimeComponent2D(E.AddComponent(TLifetimeComponent2D.Create));
  LT.Duration  := 0.45;
  LT.Remaining := 0.45;
  LT.Paused    := True;   { counts down only after stomp }

  Result := E;
end;

{ ── CreateCoin ───────────────────────────────────────────────────────────── }
function CreateCoin(AWorld: TWorld; AX, AY: Single): TEntity;
var
  E   : TEntity;
  Tr  : TTransformComponent;
  Spr : TSpriteComponent;
  Col : TColliderComponent;
  Anim: TAnimationComponent;
  Clip: TAnimation;
begin
  E := AWorld.CreateEntity('Coin');

  Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
  Tr.Position := Vector2Create(AX, AY);

  Spr             := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
  Spr.Texture     := TResourceManager2D.Instance.LoadTexture(COIN_SHEET_PATH);
  Spr.OwnsTexture := False;
  Spr.SourceRect  := RectangleCreate(0, 0, 12, 16);

  Col           := TColliderComponent(E.AddComponent(TColliderComponent.Create));
  Col.Tag       := ctCoin;
  Col.IsTrigger := True;
  Col.Size      := Vector2Create(12, 16);
  Col.Offset    := Vector2Create(0, 0);

  Anim := TAnimationComponent(E.AddComponent(TAnimationComponent.Create));
  Clip := TAnimation.Create('spin', True);
  AddFrame(Clip, 0, 0, 12, 16, 0.14);
  AddFrame(Clip, 1, 0, 12, 16, 0.14);
  AddFrame(Clip, 2, 0, 12, 16, 0.14);
  AddFrame(Clip, 3, 0, 12, 16, 0.14);
  Anim.AddAnimation(Clip);
  Anim.Play('spin');

  E.AddComponent(TCoinTag.Create);
  Result := E;
end;

{ ── CreateTileMap ────────────────────────────────────────────────────────── }
function CreateTileMap(AWorld: TWorld): TEntity;
var
  E   : TEntity;
  TM  : TTileMapComponent;
  Tr  : TTransformComponent;
  Row : TStringList;
  R, C: Integer;
  Val : Integer;
  TTyp: Integer;
begin
  E  := AWorld.CreateEntity('TileMap');
  Tr := TTransformComponent(E.AddComponent(TTransformComponent.Create));
  Tr.Position := Vector2Create(0, 0);

  TM             := TTileMapComponent(E.AddComponent(TTileMapComponent.Create));
  TM.TileWidth   := 16;
  TM.TileHeight  := 16;
  TM.TileSet     := TexTiles;
  TM.OwnsTexture := False;
  TM.TileSetCols := 4;
  TM.SetSize(40, 15);

  Row := TStringList.Create;
  try
    Row.Delimiter       := ',';
    Row.StrictDelimiter := True;
    for R := 0 to 14 do
    begin
      Row.DelimitedText := LEVEL_MAP[R];
      for C := 0 to Row.Count - 1 do
      begin
        if C >= TM.MapCols then Break;
        Val := StrToIntDef(Trim(Row[C]), 0);
        case Val of
          TILE_SOLID : TTyp := TILE_SOLID;
          TILE_SEMI  : TTyp := TILE_SEMI;
        else           TTyp := TILE_NONE;
        end;
        TM.SetTile(C, R, Val, TTyp);
      end;
    end;
  finally
    Row.Free;
  end;
  Result := E;
end;

{ ── CreateCamera ─────────────────────────────────────────────────────────── }
function CreateCamera(AWorld: TWorld; Target: TEntity): TEntity;
var
  E   : TEntity;
  Tr  : TTransformComponent;
  Cam : TCamera2DComponent;
begin
  E := AWorld.CreateEntity('Camera');

  Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
  Tr.Position := Vector2Create(0, 0);

  Cam             := TCamera2DComponent(E.AddComponent(TCamera2DComponent.Create));
  Cam.Zoom        := 3.0;
  Cam.FollowSpeed := 6.0;
  Cam.UseBounds   := True;
  Cam.Bounds      := TRectF.Create(0, 0, 40 * 16, 15 * 16);
  Cam.Target      := Target;

  Result := E;
end;

{ ── CreateMusicPlayer ────────────────────────────────────────────────────── }
function CreateMusicPlayer(AWorld: TWorld; const AFileName: string; AAutoPlay, ALoop: Boolean; AVolume: Single): TEntity;
var
  E  : TEntity;
  MP : TMusicPlayerComponent;
begin
  E  := AWorld.CreateEntity('MusicPlayer');
  MP          := TMusicPlayerComponent(E.AddComponent(TMusicPlayerComponent.Create));
  MP.Music    := TResourceManager2D.Instance.LoadMusic(AFileName);
  MP.Volume   := AVolume;
  MP.AutoPlay := AAutoPlay;
  MP.Loop     := ALoop;
  Result := E;
end;

end.

