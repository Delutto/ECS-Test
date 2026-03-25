unit Mario.Entities;

{$mode ObjFPC}{$H+}

interface

uses
   Classes,
   SysUtils,
   raylib,
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
   P2D.Components.StateMachine,
   P2D.Components.Lifetime,
   P2D.Components.ParallaxLayer,
   Mario.Systems.Enemy,
   Mario.Common,
   Mario.Components.Player,
   Mario.Components.Enemy,
   Mario.Components.Swimmer,
   Mario.Components.Fish,
   Mario.InputSetup;

function CreatePlayer(AWorld: TWorld; AX, AY: single): TEntity;
function CreateUnderwaterPlayer(AWorld: TWorld; AX, AY: single): TEntity;
function CreateGoomba(AWorld: TWorld; AX, AY: single): TEntity;
function CreateFish(AWorld: TWorld; AX, AY: single; ASpeed: single; ADir: single; AOscFreq: single): TEntity;
function CreateCoin(AWorld: TWorld; AX, AY: single): TEntity;
function CreateGoal(AWorld: TWorld; AX, AY: single): TEntity;
function CreateTileMap(AWorld: TWorld): TEntity;
function CreateUnderwaterTileMap(AWorld: TWorld): TEntity;
function CreateCamera(AWorld: TWorld; Target: TEntity = nil): TEntity;
function CreateMusicPlayer(AWorld: TWorld; const AFileName: string; AAutoPlay: boolean = True; ALoop: boolean = True; AVolume: single = 1.0): TEntity;
{ Creates a parallax background entity.
  ATexture     — the background texture (shared, not owned by the entity).
  AScrollX/Y   — scroll factors: 0.0=fixed, 1.0=moves with camera.
  AScale       — uniform texture draw scale (e.g. 2.0 → pixel-doubled).
  AScreenY     — screen-space Y anchor for the top of the layer.
  AZOrder      — draw order among parallax layers (lower = further away).
  ATileH/TileV — whether to tile horizontally / vertically. }
function CreateParallaxBackground(AWorld: TWorld; ATexture: TTexture2D; AScrollX: single; AScrollY: single = 0.0; AScale: single = 1.0; AScreenY: single = 0.0; AZOrder: integer = 0; ATileH: boolean = True; ATileV: boolean = False): TEntity;

implementation

uses
   Mario.Assets;

{ ── Animation Frames Helper ─────────────────────────────────────────── }
procedure AddFrame(AAnim: TAnimation; ACol, ARow, AFrameW, AFrameH: integer; ADur: single);
var
   Rect: TRectangle;
begin
   Rect.X := ACol * AFrameW;
   Rect.Y := ARow * AFrameH;
   Rect.Width := -AFrameW;
   Rect.Height := AFrameH;

   AAnim.AddFrame(Rect, ADur);
end;

{ ── CreateParallaxBackground ─────────────────────────────────────────────── }
function CreateParallaxBackground(AWorld: TWorld; ATexture: TTexture2D; AScrollX, AScrollY, AScale, AScreenY: single; AZOrder: integer; ATileH, ATileV: boolean): TEntity;
var
   E: TEntity;
   Tr: TTransformComponent;
   PL: TParallaxLayerComponent2D;
begin
   E := AWorld.CreateEntity('ParallaxBG');

   Tr := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(0, AScreenY);
   Tr.Scale := Vector2Create(AScale, AScale);

   PL := TParallaxLayerComponent2D(E.AddComponent(TParallaxLayerComponent2D.Create));
   PL.Texture := ATexture;
   PL.Tint := WHITE;
   PL.ScrollFactorX := AScrollX;
   PL.ScrollFactorY := AScrollY;
   PL.TileH := ATileH;
   PL.TileV := ATileV;
   PL.ZOrder := AZOrder;

   Result := E;
end;

{ ── CreatePlayer (overworld) ─────────────────────────────────────────────── }
function CreatePlayer(AWorld: TWorld; AX, AY: single): TEntity;
var
   E: TEntity;
   Tr: TTransformComponent;
   RB: TRigidBodyComponent;
   Spr: TSpriteComponent;
   Col: TColliderComponent;
   Anim: TAnimationComponent;
   Clip: TAnimation;
   IM: TInputMapComponent;
   FSM: TStateMachineComponent2D;
   Tex: TTexture2D;
begin
   E := AWorld.CreateEntity('Player');

   Tr := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(AX, AY - (FRAME_H - 16));
   Tr.Scale := Vector2Create(1, 1);

   RB := TRigidBodyComponent(E.AddComponent(TRigidBodyComponent.Create));
   RB.GravityScale := 1.2;

   Tex := TResourceManager2D.Instance.LoadTexture(PLAYER_SHEET_PATH);
   Spr := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
   Spr.Texture := Tex;
   Spr.OwnsTexture := False;
   Spr.SourceRect := RectangleCreate(0, 0, -FRAME_W, FRAME_H);

   Col := TColliderComponent(E.AddComponent(TColliderComponent.Create));
   Col.Tag := ctPlayer;
   Col.Offset := Vector2Create(1, 0);
   Col.Size := Vector2Create(14, FRAME_H);

   Anim := TAnimationComponent(E.AddComponent(TAnimationComponent.Create));
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
   AddFrame(Clip, 6, 1, FRAME_W, FRAME_H, 0.03);
   Anim.AddAnimation(Clip);

   Clip := TAnimation.Create('slide', False);
   AddFrame(Clip, 7, 1, FRAME_W, FRAME_H, 0.8);
   Anim.AddAnimation(Clip);

   Clip := TAnimation.Create('kick', False);
   AddFrame(Clip, 8, 1, FRAME_W, FRAME_H, 0.2);
   Anim.AddAnimation(Clip);

   Clip := TAnimation.Create('victory', True);
   AddFrame(Clip, 9, 1, FRAME_W, FRAME_H, 0.12);
   Anim.AddAnimation(Clip);

   Clip := TAnimation.Create('dead', True);
   AddFrame(Clip, 10, 1, FRAME_W, FRAME_H, 0.5);
   Anim.AddAnimation(Clip);

   { Underwater animation clips — reuse existing frames }
   Clip := TAnimation.Create('swim_idle', True);
   AddFrame(Clip, 10, 0, FRAME_W, FRAME_H, 0.5);
   Anim.AddAnimation(Clip);

   Clip := TAnimation.Create('swimming', True);
   AddFrame(Clip, 10, 0, FRAME_W, FRAME_H, 0.08);
   AddFrame(Clip, 11, 0, FRAME_W, FRAME_H, 0.08);
   AddFrame(Clip, 12, 0, FRAME_W, FRAME_H, 0.08);
   Anim.AddAnimation(Clip);

   Anim.Play('idle');

   E.AddComponent(TPlayerComponent.Create);

   IM := TInputMapComponent(E.AddComponent(TInputMapComponent.Create));
   IM.MapName := PLAYER_MAP;

   FSM := TStateMachineComponent2D(E.AddComponent(TStateMachineComponent2D.Create));
   FSM.OwnerID := E.ID;
   FSM.SetInitialState(Ord(psIdle));

   Result := E;
end;

{ ── CreateUnderwaterPlayer ───────────────────────────────────────────────── }
function CreateUnderwaterPlayer(AWorld: TWorld; AX, AY: single): TEntity;
var
   E: TEntity;
   SW: TSwimmerComponent;
   FSM: TStateMachineComponent2D;
   PC: TPlayerComponent;
begin
   { Reuse CreatePlayer for all base components (sprite, anim, collider…) }
   E := CreatePlayer(AWorld, AX, AY);
   E.Name := 'Player';   { keep same name so scene lookups still work }

   { Attach swimmer component — TSwimSystem.Init reads it and applies overrides }
   SW := TSwimmerComponent(E.AddComponent(TSwimmerComponent.Create));
   { Custom tuning for this level (defaults in TSwimmerComponent.Create are fine) }
   SW.UnderwaterGravityScale := 0.15;   { barely any sinking }
   SW.UnderwaterDragX := 5.5;    { noticeable resistance }
   SW.UnderwaterDragY := 4.0;
   SW.UnderwaterMaxFallSpeed := 90.0;
   SW.UnderwaterMaxSpeedX := 85.0;
   SW.SwimUpForce := -7000.0; { strong enough to overcome gravity }

   { Start in underwater idle state }
   FSM := TStateMachineComponent2D(E.GetComponent(TStateMachineComponent2D));
   if Assigned(FSM) then
   begin
      FSM.SetInitialState(Ord(psSwimIdle));
   end;

   PC := TPlayerComponent(E.GetComponent(TPlayerComponent));
   if Assigned(PC) then
   begin
      PC.State := psSwimIdle;
   end;

   Result := E;
end;

{ ── CreateGoomba ─────────────────────────────────────────────────────────── }
function CreateGoomba(AWorld: TWorld; AX, AY: single): TEntity;
var
   E: TEntity;
   Tr: TTransformComponent;
   Spr: TSpriteComponent;
   Col: TColliderComponent;
   G: TGoombaComponent;
   Anim: TAnimationComponent;
   Clip: TAnimation;
   FSM: TStateMachineComponent2D;
   LT: TLifetimeComponent2D;
begin
   E := AWorld.CreateEntity('Goomba');

   Tr := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(AX, AY);

   E.AddComponent(TRigidBodyComponent.Create);

   Spr := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
   Spr.Texture := TexEnemy;
   Spr.OwnsTexture := False;
   Spr.SourceRect := RectangleCreate(0, 0, 16, 16);

   Col := TColliderComponent(E.AddComponent(TColliderComponent.Create));
   Col.Tag := ctEnemy;
   Col.Offset := Vector2Create(1, 0);
   Col.Size := Vector2Create(14, 16);
   Col.IsTrigger := True;

   Anim := TAnimationComponent(E.AddComponent(TAnimationComponent.Create));

   Clip := TAnimation.Create('walk', True);
   AddFrame(Clip, 0, 0, 16, 16, 0.20);
   AddFrame(Clip, 1, 0, 16, 16, 0.20);
   Anim.AddAnimation(Clip);

   Clip := TAnimation.Create('stomped', False);
   AddFrame(Clip, 0, 0, 16, 16, 1.0);
   Anim.AddAnimation(Clip);
   Anim.Play('walk');

   E.AddComponent(TEnemyTag.Create);

   G := TGoombaComponent(E.AddComponent(TGoombaComponent.Create));
   G.Speed := 60;
   G.Direction := -1;

   FSM := TStateMachineComponent2D(E.AddComponent(TStateMachineComponent2D.Create));
   FSM.OwnerID := E.ID;
   FSM.SetInitialState(Ord(gsWalking));

   LT := TLifetimeComponent2D(E.AddComponent(TLifetimeComponent2D.Create));
   LT.Duration := 0.45;
   LT.Remaining := 0.45;
   LT.Paused := True;

   Result := E;
end;

{ ── CreateFish ───────────────────────────────────────────────────────────── }
function CreateFish(AWorld: TWorld; AX, AY: single; ASpeed: single; ADir: single; AOscFreq: single): TEntity;
var
   E: TEntity;
   Tr: TTransformComponent;
   RB: TRigidBodyComponent;
   Spr: TSpriteComponent;
   Col: TColliderComponent;
   Anim: TAnimationComponent;
   Clip: TAnimation;
   F: TFishComponent;
begin
   E := AWorld.CreateEntity('Fish');

   Tr := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(AX, AY);

   RB := TRigidBodyComponent(E.AddComponent(TRigidBodyComponent.Create));
   RB.UseGravity := False;   { fish are neutrally buoyant }
   RB.LinearDragX := 0.3;    { light horizontal drag       }
   RB.LinearDragY := 6.0;    { strong vertical damping     }
   RB.MaxFallSpeed := 80.0;

   Spr := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
   Spr.Texture := TexFish;
   Spr.OwnsTexture := False;
   Spr.SourceRect := RectangleCreate(0, 0, 16, 16);

   Col := TColliderComponent(E.AddComponent(TColliderComponent.Create));
   Col.Tag := ctEnemy;
   Col.Offset := Vector2Create(1, 2);
   Col.Size := Vector2Create(14, 12);
   Col.IsTrigger := True;

   Anim := TAnimationComponent(E.AddComponent(TAnimationComponent.Create));

   Clip := TAnimation.Create('swim', True);
   AddFrame(Clip, 0, 0, 16, 16, 0.18);
   AddFrame(Clip, 1, 0, 16, 16, 0.18);
   Anim.AddAnimation(Clip);

   Anim.Play('swim');

   E.AddComponent(TEnemyTag.Create);
   F := TFishComponent(E.AddComponent(TFishComponent.Create));
   F.Speed := ASpeed;
   F.Direction := ADir;
   F.OscFrequency := AOscFreq;
   F.OscTimer := AX * 0.03; { Randomize timer so fish don't all oscillate in sync }

   Result := E;
end;

{ ── CreateGoal ───────────────────────────────────────────────────────────── }
function CreateGoal(AWorld: TWorld; AX, AY: single): TEntity;
var
   E: TEntity;
   Tr: TTransformComponent;
   Col: TColliderComponent;
   Spr: TSpriteComponent;
begin
   E := AWorld.CreateEntity('Goal');

   Tr := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(AX, AY);

   { Visual: use the gold coin tile as a placeholder star/flag }
   Spr := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
   Spr.Texture := TexTiles;
   Spr.OwnsTexture := False;
   Spr.SourceRect := RectangleCreate(48, 0, 16, 16);  { coin tile col 3 }
   Spr.Tint := ColorCreate(255, 220, 0, 255);
   Spr.ZOrder := 5;

   Col := TColliderComponent(E.AddComponent(TColliderComponent.Create));
   Col.Tag := ctGoal;
   Col.IsTrigger := True;
   Col.Size := Vector2Create(16, 32);
   Col.Offset := Vector2Create(0, 0);

   E.AddComponent(TGoalTag.Create);

   Result := E;
end;

{ ── CreateCoin ───────────────────────────────────────────────────────────── }
function CreateCoin(AWorld: TWorld; AX, AY: single): TEntity;
var
   E: TEntity;
   Tr: TTransformComponent;
   Spr: TSpriteComponent;
   Col: TColliderComponent;
   Anim: TAnimationComponent;
   Clip: TAnimation;
begin
   E := AWorld.CreateEntity('Coin');

   Tr := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(AX, AY);

   Spr := TSpriteComponent(E.AddComponent(TSpriteComponent.Create));
   Spr.Texture := TResourceManager2D.Instance.LoadTexture(COIN_SHEET_PATH);
   Spr.OwnsTexture := False;
   Spr.SourceRect := RectangleCreate(0, 0, 12, 16);

   Col := TColliderComponent(E.AddComponent(TColliderComponent.Create));
   Col.Tag := ctCoin;
   Col.IsTrigger := True;
   Col.Size := Vector2Create(12, 16);

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

{ ── CreateTileMap (overworld) ────────────────────────────────────────────── }
function CreateTileMap(AWorld: TWorld): TEntity;
var
   E: TEntity;
   TM: TTileMapComponent;
   Tr: TTransformComponent;
   Row: TStringList;
   R, C, Val, TTyp: integer;
begin
   E := AWorld.CreateEntity('TileMap');

   Tr := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(0, 0);

   TM := TTileMapComponent(E.AddComponent(TTileMapComponent.Create));
   TM.TileWidth := 16;
   TM.TileHeight := 16;
   TM.TileSet := TexTiles;
   TM.OwnsTexture := False;
   TM.TileSetCols := 4;
   TM.SetSize(40, 15);

   Row := TStringList.Create;
   try
      Row.Delimiter := ',';
      Row.StrictDelimiter := True;
      for R := 0 to 14 do
      begin
         Row.DelimitedText := LEVEL_MAP[R];
         for C := 0 to Row.Count - 1 do
         begin
            if C >= TM.MapCols then
            begin
               Break;
            end;
            Val := StrToIntDef(Trim(Row[C]), 0);
            case Val of
               TILE_SOLID:
               begin
                  TTyp := TILE_SOLID;
               end;
               TILE_SEMI:
               begin
                  TTyp := TILE_SEMI;
               end;
               else
               begin
                  TTyp := TILE_NONE;
               end;
            end;
            TM.SetTile(C, R, Val, TTyp);
         end;
      end;
   finally
      Row.Free;
   end;

   Result := E;
end;

{ ── CreateUnderwaterTileMap ──────────────────────────────────────────────── }
function CreateUnderwaterTileMap(AWorld: TWorld): TEntity;
var
   E: TEntity;
   TM: TTileMapComponent;
   Tr: TTransformComponent;
   Row: TStringList;
   R, C, Val, TTyp: integer;
begin
   E := AWorld.CreateEntity('TileMap');

   Tr := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(0, 0);

   TM := TTileMapComponent(E.AddComponent(TTileMapComponent.Create));
   TM.TileWidth := 16;
   TM.TileHeight := 16;
   TM.TileSet := TexCoralTiles;
   TM.OwnsTexture := False;
   TM.TileSetCols := 4;
   TM.SetSize(40, 15);

   Row := TStringList.Create;
   try
      Row.Delimiter := ',';
      Row.StrictDelimiter := True;
      for R := 0 to 14 do
      begin
         Row.DelimitedText := LEVEL2_MAP[R];
         for C := 0 to Row.Count - 1 do
         begin
            if C >= TM.MapCols then
            begin
               Break;
            end;
            Val := StrToIntDef(Trim(Row[C]), 0);
            case Val of
               TILE_SOLID:
               begin
                  TTyp := TILE_SOLID;
               end;
               TILE_SEMI:
               begin
                  TTyp := TILE_SEMI;
               end;
               else
               begin
                  TTyp := TILE_NONE;
               end;
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
   E: TEntity;
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
begin
   E := AWorld.CreateEntity('Camera');

   Tr := TTransformComponent(E.AddComponent(TTransformComponent.Create));
   Tr.Position := Vector2Create(0, 0);

   Cam := TCamera2DComponent(E.AddComponent(TCamera2DComponent.Create));
   Cam.Zoom := 3.0;
   Cam.FollowSpeed := 6.0;
   Cam.UseBounds := True;
   Cam.Bounds := TRectF.Create(0, 0, 40 * 16, 15 * 16);
   Cam.Target := Target;

   Result := E;
end;

{ ── CreateMusicPlayer ────────────────────────────────────────────────────── }
function CreateMusicPlayer(AWorld: TWorld; const AFileName: string; AAutoPlay, ALoop: boolean; AVolume: single): TEntity;
var
   E: TEntity;
   MP: TMusicPlayerComponent;
begin
   E := AWorld.CreateEntity('MusicPlayer');

   MP := TMusicPlayerComponent(E.AddComponent(TMusicPlayerComponent.Create));
   MP.Music := TResourceManager2D.Instance.LoadMusic(AFileName);
   MP.Volume := AVolume;
   MP.AutoPlay := AAutoPlay;
   MP.Loop := ALoop;

   Result := E;
end;

end.
