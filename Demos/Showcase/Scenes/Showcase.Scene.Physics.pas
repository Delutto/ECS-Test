unit Showcase.Scene.Physics;

{$mode objfpc}{$H+}

{ Demo 14 - Physics  NEW: textured stone/semi/hazard tiles + player sprite. }
interface

uses
   SysUtils, StrUtils, Math, raylib, P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.Event, P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.Events,
   P2D.Components.Transform, P2D.Components.RigidBody,
   P2D.Components.Collider, P2D.Components.TileMap,
   P2D.Systems.Physics, P2D.Systems.Collision,
   P2D.Common, Showcase.Common;

type
   TPhysicsDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FPlayer: TEntity;
      FTRID, FRBID: integer;
      FLog: array[0..5] of string;
      FLogN: integer;
      FTexSolid, FTexSemi, FTexHazard, FTexPlayer: TTexture2D;
      procedure GenTileTextures;
      procedure FreeTileTextures;
      procedure Spawn;
      procedure Log(const S: string);
      procedure OnHazard(AEvent: TEvent2D);
      function PB: TRigidBodyComponent;
      function PT: TTransformComponent;
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AW, AH: integer);
      procedure Update(ADelta: single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Systems.SceneManager;

const
   LVL: array[0..15] of string = (
      '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
      '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
      '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
      '0,0,0,0,0,0,0,0,0,2,2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
      '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0,0,0',
      '0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
      '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0',
      '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
      '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
      '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0',
      '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
      '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
      '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
      '1,1,1,1,1,1,1,1,1,1,1,1,3,3,3,3,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1',
      '1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1',
      '1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1');
   TS = 24;
   SPAWNX: single = 48;
   SPAWNY: single = 48;

function IfStr(B: boolean; const T, F: string): string;
begin
   if B then
      Result := T
   else
      Result := F;
end;

function IfCol(B: boolean; const T, F: TColor): TColor;
begin
   if B then
      Result := T
   else
      Result := F;
end;

constructor TPhysicsDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Physics');
   FScreenW := AW;
   FScreenH := AH;
end;

procedure TPhysicsDemoScene.GenTileTextures;
var
   Img: TImage;
   S: integer;
begin
   S := TS;
   Img := GenImageColor(S, S, ColorCreate(66, 62, 54, 255));
   ImageDrawRectangle(@Img, 1, 1, S - 2, S - 2, ColorCreate(80, 76, 66, 255));
   ImageDrawRectangle(@Img, 0, S div 2, S, 2, ColorCreate(52, 48, 42, 255));
   ImageDrawRectangle(@Img, S div 2, 0, 2, S div 2, ColorCreate(52, 48, 42, 255));
   ImageDrawRectangle(@Img, 1, 1, S - 2, 2, ColorCreate(100, 96, 82, 200));
   FTexSolid := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(S, S, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 0, 0, S, S div 3, ColorCreate(50, 160, 70, 220));
   ImageDrawRectangle(@Img, 0, 0, S, 3, ColorCreate(80, 210, 110, 255));
   ImageDrawRectangle(@Img, 2, 3, S - 4, 3, ColorCreate(60, 180, 85, 200));
   FTexSemi := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(S, S, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 0, S - 6, S, 6, ColorCreate(150, 35, 35, 255));
   ImageDrawRectangle(@Img, 1, S div 2, 4, S div 2, ColorCreate(210, 50, 50, 255));
   ImageDrawRectangle(@Img, S div 2 - 2, S div 2 - 2, 4, S div 2 + 2, ColorCreate(210, 50, 50, 255));
   ImageDrawRectangle(@Img, S - 5, S div 2, 4, S div 2, ColorCreate(210, 50, 50, 255));
   FTexHazard := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(20, 28, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 4, 0, 12, 10, ColorCreate(220, 190, 160, 255));
   ImageDrawRectangle(@Img, 0, 10, 20, 12, ColorCreate(80, 140, 210, 255));
   ImageDrawRectangle(@Img, 2, 10, 4, 12, ColorCreate(255, 255, 255, 80));
   ImageDrawRectangle(@Img, 1, 22, 8, 6, ColorCreate(60, 100, 50, 255));
   ImageDrawRectangle(@Img, 11, 22, 8, 6, ColorCreate(60, 100, 50, 255));
   FTexPlayer := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TPhysicsDemoScene.FreeTileTextures;

   procedure U(var T: TTexture2D);
   begin
      if T.Id > 0 then
      begin
         UnloadTexture(T);
         T.Id := 0;
      end;
   end;

begin
   U(FTexSolid);
   U(FTexSemi);
   U(FTexHazard);
   U(FTexPlayer);
end;

procedure TPhysicsDemoScene.Log(const S: string);
var
   I: integer;
begin
   if FLogN < 6 then
   begin
      FLog[FLogN] := S;
      Inc(FLogN);
   end
   else
   begin
      for I := 0 to 4 do
         FLog[I] := FLog[I + 1];
      FLog[5] := S;
   end;
end;

procedure TPhysicsDemoScene.OnHazard(AEvent: TEvent2D);
var
   Ev: TEntityHazardEvent;
begin
   Ev := TEntityHazardEvent(AEvent);
   Log(Format('[HAZARD] spike at tile (%d,%d)', [Ev.TileCol, Ev.TileRow]));
end;

function TPhysicsDemoScene.PB: TRigidBodyComponent;
begin
   Result := TRigidBodyComponent(FPlayer.GetComponentByID(FRBID));
end;

function TPhysicsDemoScene.PT: TTransformComponent;
begin
   Result := TTransformComponent(FPlayer.GetComponentByID(FTRID));
end;

procedure TPhysicsDemoScene.Spawn;
var
   Tr: TTransformComponent;
   RB: TRigidBodyComponent;
begin
   Tr := PT;
   RB := PB;
   Tr.Position.X := SPAWNX;
   Tr.Position.Y := SPAWNY;
   RB.Velocity.X := 0;
   RB.Velocity.Y := 0;
   RB.ForceAccum.X := 0;
   RB.ForceAccum.Y := 0;
   Log('Respawned.');
end;

procedure TPhysicsDemoScene.DoLoad;
begin
   World.AddSystem(TPhysicsSystem.Create(World));
   World.AddSystem(TCollisionSystem.Create(World));
end;

procedure TPhysicsDemoScene.DoEnter;
var
   ME: TEntity;
   TM: TTileMapComponent;
   MT, PT2: TTransformComponent;
   RB: TRigidBodyComponent;
   PC: TColliderComponent;
   Parts: TStringArray;
   Row, Col, Val, TT: integer;
begin
   FLogN := 0;
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FRBID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
   GenTileTextures;
   ME := World.CreateEntity('TileMap');
   MT := TTransformComponent.Create;
   MT.Position := Vector2Create(0, 0);
   ME.AddComponent(MT);
   TM := TTileMapComponent.Create;
   TM.TileWidth := TS;
   TM.TileHeight := TS;
   TM.SetSize(32, 16);
   for Row := 0 to 15 do
   begin
      Parts := LVL[Row].Split(',');
      for Col := 0 to Min(31, Length(Parts) - 1) do
      begin
         Val := StrToIntDef(Trim(Parts[Col]), 0);
         case Val of
            TILE_SOLID:
               TT := TILE_SOLID;
            TILE_SEMI:
               TT := TILE_SEMI;
            TILE_HAZARD:
               TT := TILE_HAZARD;
            else
               TT := TILE_NONE;
         end;
         TM.SetTile(Col, Row, Val, TT);
      end;
   end;
   ME.AddComponent(TM);
   FPlayer := World.CreateEntity('Player');
   PT2 := TTransformComponent.Create;
   PT2.Position := Vector2Create(SPAWNX, SPAWNY);
   FPlayer.AddComponent(PT2);
   RB := TRigidBodyComponent.Create;
   RB.GravityScale := 1.2;
   RB.MaxFallSpeed := 500;
   RB.LinearDragX := 6.0;
   RB.CoyoteTime := DEFAULT_COYOTE_TIME;
   RB.JumpBuffer := DEFAULT_JUMP_BUFFER;
   RB.Restitution := 0.0;
   FPlayer.AddComponent(RB);
   PC := TColliderComponent.Create;
   PC.Tag := ctPlayer;
   PC.Size := Vector2Create(20, 28);
   PC.Offset := Vector2Create(2, 0);
   FPlayer.AddComponent(PC);
   World.Init;
   World.EventBus.Subscribe(TEntityHazardEvent, @OnHazard);
   Log('A/D=move  SPACE=jump (coyote+buffer)  G=gravity  B/N=bounce  R=reset');
end;

procedure TPhysicsDemoScene.DoExit;
begin
   World.EventBus.Unsubscribe(TEntityHazardEvent, @OnHazard);
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FreeTileTextures;
end;

procedure TPhysicsDemoScene.Update(ADelta: single);
var
   RB: TRigidBodyComponent;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   RB := PB;
   if IsKeyDown(KEY_A) then
      RB.AddForce(Vector2Create(-8000, 0));
   if IsKeyDown(KEY_D) then
      RB.AddForce(Vector2Create(8000, 0));
   if IsKeyPressed(KEY_SPACE) then
   begin
      if RB.Grounded or (RB.CoyoteTimeLeft > 0) then
      begin
         RB.AddImpulse(Vector2Create(0, -450));
         RB.CoyoteTimeLeft := 0;
         Log('JUMP!');
      end
      else
         RB.RequestJump;
   end;
   if IsKeyPressed(KEY_G) then
   begin
      RB.UseGravity := not RB.UseGravity;
      Log(IfStr(RB.UseGravity, 'Gravity ON', 'Gravity OFF'));
   end;
   if IsKeyPressed(KEY_B) then
   begin
      RB.Restitution := Min(1, RB.Restitution + 0.1);
      Log(Format('Restitution=%.1f', [RB.Restitution]));
   end;
   if IsKeyPressed(KEY_N) then
   begin
      RB.Restitution := Max(0, RB.Restitution - 0.1);
      Log(Format('Restitution=%.1f', [RB.Restitution]));
   end;
   if IsKeyPressed(KEY_R) then
      Spawn;
   World.Update(ADelta);
end;

procedure TPhysicsDemoScene.Render;
const
   OX = 30;
   OY = DEMO_AREA_Y + 20;
var
   E: TEntity;
   TM: TTileMapComponent;
   TMID, Row, Col: integer;
   TD: TTileData;
   GX, GY: integer;
   RB: TRigidBodyComponent;
   Tr: TTransformComponent;
   I: integer;
   Dst: TRectangle;
begin
   ClearBackground(ColorCreate(16, 16, 26, 255));
   DrawHeader('Demo 14 - Physics and Collision (TPhysicsSystem + TCollisionSystem)');
   DrawFooter('A/D=move  SPACE=jump (coyote+buffer)  G=gravity  B/N=bounce  R=reset');
   TMID := ComponentRegistry.GetComponentID(TTileMapComponent);
   for E in World.Entities.GetAll do
   begin
      if not E.Alive then
         Continue;
      TM := TTileMapComponent(E.GetComponentByID(TMID));
      if not Assigned(TM) then
         Continue;
      for Row := 0 to TM.MapRows - 1 do
         for Col := 0 to TM.MapCols - 1 do
         begin
            TD := TM.GetTile(Col, Row);
            if TD.TileType = TILE_NONE then
               Continue;
            GX := OX + Col * TS;
            GY := OY + Row * TS;
            Dst := RectangleCreate(GX, GY, TS, TS);
            case TD.TileType of
               TILE_SOLID:
                  if FTexSolid.Id > 0 then
                     DrawTexturePro(FTexSolid, RectangleCreate(0, 0, TS, TS), Dst, Vector2Create(0, 0), 0, WHITE)
                  else
                     DrawRectangle(GX + 1, GY + 1, TS - 2, TS - 2, ColorCreate(80, 80, 100, 255));
               TILE_SEMI:
                  if FTexSemi.Id > 0 then
                     DrawTexturePro(FTexSemi, RectangleCreate(0, 0, TS, TS), Dst, Vector2Create(0, 0), 0, WHITE)
                  else
                     DrawRectangle(GX + 1, GY + 1, TS - 2, TS - 2, ColorCreate(60, 140, 60, 255));
               TILE_HAZARD:
                  if FTexHazard.Id > 0 then
                     DrawTexturePro(FTexHazard, RectangleCreate(0, 0, TS, TS), Dst, Vector2Create(0, 0), 0, WHITE)
                  else
                     DrawRectangle(GX + 1, GY + 1, TS - 2, TS - 2, ColorCreate(200, 60, 60, 255));
            end;
         end;
   end;
   RB := PB;
   Tr := PT;
   if FTexPlayer.Id > 0 then
      DrawTexturePro(FTexPlayer, RectangleCreate(0, 0, 20, 28),
         RectangleCreate(OX + 2 + Round(Tr.Position.X), OY + Round(Tr.Position.Y), 20, 28),
         Vector2Create(0, 0), 0, IfCol(RB.Grounded, COL_GOOD, WHITE))
   else
      DrawRectangle(OX + 2 + Round(Tr.Position.X), OY + Round(Tr.Position.Y), 20, 28, IfCol(RB.Grounded, COL_GOOD, COL_ACCENT));
   DrawPanel(SCR_W - 292, DEMO_AREA_Y + 10, 282, 310, 'RigidBody State');
   DrawText(PChar(Format('Vel.X      : %6.1f', [RB.Velocity.X])), SCR_W - 282, DEMO_AREA_Y + 34, 12, COL_TEXT);
   DrawText(PChar(Format('Vel.Y      : %6.1f', [RB.Velocity.Y])), SCR_W - 282, DEMO_AREA_Y + 52, 12, COL_TEXT);
   DrawText(PChar('Grounded   : ' + IfStr(RB.Grounded, 'YES', 'no')), SCR_W - 282, DEMO_AREA_Y + 70, 12, IfCol(RB.Grounded, COL_GOOD, COL_DIMTEXT));
   DrawText(PChar('OnWall     : ' + IfStr(RB.OnWall, 'YES', 'no')), SCR_W - 282, DEMO_AREA_Y + 88, 12, IfCol(RB.OnWall, COL_WARN, COL_DIMTEXT));
   DrawText(PChar('OnCeiling  : ' + IfStr(RB.OnCeiling, 'YES', 'no')), SCR_W - 282, DEMO_AREA_Y + 106, 12, IfCol(RB.OnCeiling, COL_BAD, COL_DIMTEXT));
   DrawText(PChar(Format('CoyoteTime : %.3f s', [RB.CoyoteTimeLeft])), SCR_W - 282, DEMO_AREA_Y + 124, 12, COL_TEXT);
   DrawText(PChar(Format('JumpBuffer : %.3f s', [RB.JumpBufferLeft])), SCR_W - 282, DEMO_AREA_Y + 142, 12, COL_TEXT);
   DrawText(PChar(Format('GravScale  : %.2f', [RB.GravityScale])), SCR_W - 282, DEMO_AREA_Y + 160, 12, COL_TEXT);
   DrawText(PChar(Format('DragX      : %.2f', [RB.LinearDragX])), SCR_W - 282, DEMO_AREA_Y + 178, 12, COL_TEXT);
   DrawText(PChar(Format('Restitution: %.2f', [RB.Restitution])), SCR_W - 282, DEMO_AREA_Y + 196, 12, COL_TEXT);
   DrawText(PChar('UseGravity : ' + IfStr(RB.UseGravity, 'TRUE', 'FALSE')), SCR_W - 282, DEMO_AREA_Y + 214, 12, IfCol(RB.UseGravity, COL_GOOD, COL_BAD));
   DrawPanel(SCR_W - 292, DEMO_AREA_Y + 330, 282, 160, 'Event Log');
   for I := 0 to FLogN - 1 do
      DrawText(PChar(FLog[I]), SCR_W - 282, DEMO_AREA_Y + 354 + I * 22, 10, COL_TEXT);
end;

end.
