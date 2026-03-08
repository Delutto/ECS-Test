unit Mario.Entities;

{$mode ObjFPC}{$H+}

interface

uses
   Classes, SysUtils, raylib,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.World,
   P2D.Core.ResourceManager,
   P2D.Components.Transform,
   P2D.Components.RigidBody,
   P2D.Components.Sprite,
   P2D.Components.Animation,
   P2D.Components.Collider,
   P2D.Components.Tags,
   P2D.Components.TileMap,
   P2D.Components.Camera2D,
   P2D.Components.InputMap,
   P2D.Components.MusicPlayer,
   Mario.Systems.Enemy,
   Mario.InputSetup;

{ Factories de entidades }
function  CreatePlayer    (AWorld: TWorld; AX, AY: Single): TEntity;
function  CreateGoomba    (AWorld: TWorld; AX, AY: Single): TEntity;
function  CreateCoin      (AWorld: TWorld; AX, AY: Single): TEntity;
function  CreateTileMap   (AWorld: TWorld): TEntity;
function  CreateCamera    (AWorld: TWorld): TEntity;
{ Nova factory: entidade exclusiva de música de fundo }
function  CreateMusicPlayer(AWorld: TWorld; const AFileName: string; AVolume: Single = 1.0; AAutoPlay: Boolean = True): TEntity;

implementation

uses
   Mario.ProceduralArt;

{ ── Helper de frames de animação ─────────────────────────────────────────── }

procedure AddFrame(AAnim: TAnimation; ACol: Integer; ARow: Integer = 0; AFrameW: Integer = 16; AFrameH: Integer = 16; ADur: Single = 0.12);
var
   Rect: TRectangle;
begin
   Rect.X      := ACol * AFrameW;
   Rect.Y      := ARow * AFrameH;
   Rect.Width  := AFrameW;
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
begin
   E := AWorld.CreateEntity('Player');

   Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(AX, AY);
   Tr.Scale    := Vector2Create(1, 1);

   RB              := TRigidBodyComponent(E.AddComponent(TRigidBodyComponent.Create));
   RB.GravityScale := 1.2;

   Spr            := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
   Spr.Texture    := TexPlayer;
   Spr.OwnsTexture := False;
   Spr.SourceRect := RectangleCreate(0, 0, 16, 16);
   Spr.Origin     := Vector2Create(0, 0);

   Col        := TColliderComponent(E.AddComponent(TColliderComponent.Create));
   Col.Tag    := ctPlayer;
   Col.Offset := Vector2Create(1, 0);
   Col.Size   := Vector2Create(14, 16);

   Anim := TAnimationComponent(E.AddComponent(TAnimationComponent.Create));

   Clip := TAnimation.Create('idle', True);
   AddFrame(Clip, 0);
   Anim.AddAnimation(Clip);

   Clip := TAnimation.Create('walk', True);
   AddFrame(Clip, 1); AddFrame(Clip, 2); AddFrame(Clip, 3);
   Anim.AddAnimation(Clip);

   Clip := TAnimation.Create('run', True);
   AddFrame(Clip, 5, 0, 16, 16, 0.08);
   AddFrame(Clip, 6, 0, 16, 16, 0.08);
   Anim.AddAnimation(Clip);

   Clip := TAnimation.Create('jump', False);
   AddFrame(Clip, 4, 0, 16, 16, 0.5);
   Anim.AddAnimation(Clip);

   Clip := TAnimation.Create('dead', False);
   AddFrame(Clip, 7, 0, 16, 16, 0.5);
   Anim.AddAnimation(Clip);

   Anim.Play('idle');

   E.AddComponent(TPlayerTag.Create);
   E.AddComponent(TPlayerComponent.Create);

   IM         := TInputMapComponent(E.AddComponent(TInputMapComponent.Create));
   IM.MapName := PLAYER_MAP;

   Result := E;
end;

{ ── CreateGoomba ─────────────────────────────────────────────────────────── }

function CreateGoomba(AWorld: TWorld; AX, AY: Single): TEntity;
var
   E   : TEntity;
   Tr  : TTransformComponent;
   Spr : TSpriteComponent;
   Col : TColliderComponent;
   G   : TGoombaComponent;
begin
   E := AWorld.CreateEntity('Goomba');

   Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(AX, AY);

   E.AddComponent(TRigidBodyComponent.Create);

   Spr            := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
   Spr.Texture    := TexEnemy;
   Spr.OwnsTexture := False;
   Spr.SourceRect := RectangleCreate(0, 0, 16, 16);

   Col        := TColliderComponent(E.AddComponent(TColliderComponent.Create));
   Col.Tag    := ctEnemy;
   Col.Offset := Vector2Create(1, 0);
   Col.Size   := Vector2Create(14, 16);

   E.AddComponent(TEnemyTag.Create);

   G           := TGoombaComponent(E.AddComponent(TGoombaComponent.Create));
   G.Speed     := 60;
   G.Direction := -1;

   Result := E;
end;

{ ── CreateCoin ───────────────────────────────────────────────────────────── }

function CreateCoin(AWorld: TWorld; AX, AY: Single): TEntity;
var
   E   : TEntity;
   Tr  : TTransformComponent;
   Spr : TSpriteComponent;
   Col : TColliderComponent;
begin
   E := AWorld.CreateEntity('Coin');

   Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(AX, AY);

   Spr            := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
   Spr.Texture    := TexCoin;
   Spr.OwnsTexture := False;
   Spr.SourceRect := RectangleCreate(0, 0, 16, 16);

   Col           := TColliderComponent(E.AddComponent(TColliderComponent.Create));
   Col.Tag       := ctCoin;
   Col.IsTrigger := True;
   Col.Size      := Vector2Create(12, 12);
   Col.Offset    := Vector2Create(2, 2);

   E.AddComponent(TCoinTag.Create);

   Result := E;
end;

{ ── CreateTileMap ────────────────────────────────────────────────────────── }

function CreateTileMap(AWorld: TWorld): TEntity;
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
            '1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1',
            '1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1',
            '1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1');
var
   E    : TEntity;
   Tr   : TTransformComponent;
   TM   : TTileMapComponent;
   R, C : Integer;
   Row  : TStringList;
   Val  : Integer;
   TTyp : Integer;
begin
   E := AWorld.CreateEntity('TileMap');

   Tr          := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(0, 0);

   TM              := TTileMapComponent(E.AddComponent(TTileMapComponent.Create));
   TM.TileWidth    := 16;
   TM.TileHeight   := 16;
   TM.TileSet      := TexTiles;
   TM.OwnsTexture  := False;
   TM.TileSetCols  := 4;
   TM.SetSize(40, 15);

   Row := TStringList.Create;
   try
      Row.Delimiter       := ',';
      Row.StrictDelimiter := True;
      for R := 0 to 14 do
      begin
         Row.DelimitedText := LEVEL_MAP[R];
         for C := 0 to 39 do
         begin
            Val := StrToIntDef(Trim(Row[C]), 0);
            if Val in [1, 2, 3] then
               TTyp := TILE_SOLID
            else
               TTyp := TILE_NONE;

            TM.SetTile(C, R, Val, TTyp);
         end;
      end;
   finally
      Row.Free;
   end;

   Result := E;
end;

{ ── CreateCamera ─────────────────────────────────────────────────────────── }

function CreateCamera(AWorld: TWorld): TEntity;
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

   Result := E;
end;

{ ── CreateMusicPlayer ────────────────────────────────────────────────────── }

function CreateMusicPlayer(AWorld: TWorld; const AFileName: string; AVolume: Single; AAutoPlay: Boolean): TEntity;
var
   E  : TEntity;
   MP : TMusicPlayerComponent;
begin
   E := AWorld.CreateEntity('MusicPlayer');

   MP          := TMusicPlayerComponent(E.AddComponent(TMusicPlayerComponent.Create));
   MP.Music    := TResourceManager2D.Instance.LoadMusic(AFileName);
   MP.Volume   := AVolume;
   MP.AutoPlay := AAutoPlay;
   MP.Loop     := True;

   Result := E;
end;

end.
