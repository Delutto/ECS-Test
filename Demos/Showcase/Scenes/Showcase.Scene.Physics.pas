unit Showcase.Scene.Physics;

{$mode objfpc}{$H+}

{ Demo 14 - Physics and Collision (TPhysicsSystem + TCollisionSystem)
  TPhysicsSystem (prio 10):
    Snapshot PrevPosition, decay coyote/jump timers, integrate ForceAccum
    (F=ma), apply gravity (GRAVITY*GravityScale*dt -> VelocityY), apply
    exponential LinearDrag, clamp MaxFallSpeed/MaxSpeedX, integrate position.
  TCollisionSystem (prio 20):
    For each entity with Collider+RigidBody: test AABB against tile grid,
    TILE_SOLID=push-out+zero vel+flags, TILE_SEMI=one-way from above,
    TILE_HAZARD=TEntityHazardEvent. Entity vs entity: overlap events.
  Controls: A/D=move  SPACE=jump  G=gravity  B/N=bounce  R=reset }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.Event, P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.Events,
   P2D.Components.Transform, P2D.Components.RigidBody, P2D.Components.Collider, P2D.Components.TileMap,
   P2D.Systems.Physics, P2D.Systems.Collision, P2D.Common, Showcase.Common;

type
   TPhysicsDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FPlayer: TEntity;
      FTRID, FRBID: Integer;
      FLog: array[0..5] of String;
      FLogN: Integer;
      procedure Spawn;
      procedure Log(const S: String);
      procedure OnHazard(AEvent: TEvent2D);
      function PB: TRigidBodyComponent;
      function PT: TTransformComponent;
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AW, AH: Integer);
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Systems.SceneManager;

const
   LVL: array[0..15] of String = (
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
   SPAWNX: Single = 48;
   SPAWNY: Single = 48;

constructor TPhysicsDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('Physics');
   FScreenW := AW;
   FScreenH := AH;
end;

procedure TPhysicsDemoScene.Log(const S: String);
var
   I: Integer;
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
   { Register in priority order: physics (10) then collision (20) }
   World.AddSystem(TPhysicsSystem.Create(World));
   World.AddSystem(TCollisionSystem.Create(World));
end;

procedure TPhysicsDemoScene.DoEnter;
var
   ME: TEntity;
   TM: TTileMapComponent;
   MT: TTransformComponent;
   PT2: TTransformComponent;
   RB: TRigidBodyComponent;
   PC: TColliderComponent;
   Parts: TStringArray;
   Row, Col, Val, TT: Integer;
begin
   FLogN := 0;
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FRBID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
   { Tilemap entity — TCollisionSystem.Init finds first entity with TTileMapComponent }
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
   { Player entity }
   FPlayer := World.CreateEntity('Player');
   PT2 := TTransformComponent.Create;
   PT2.Position := Vector2Create(SPAWNX, SPAWNY);
   FPlayer.AddComponent(PT2);
   RB := TRigidBodyComponent.Create;
   RB.GravityScale := 1.2;     { heavier than default }
   RB.MaxFallSpeed := 500;
   RB.LinearDragX := 6.0;    { horizontal ground friction }
   RB.CoyoteTime := DEFAULT_COYOTE_TIME;  { 10/60 s grace after ledge }
   RB.JumpBuffer := DEFAULT_JUMP_BUFFER;  { 8/60 s input buffer }
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
end;

procedure TPhysicsDemoScene.Update(ADelta: Single);
var
   RB: TRigidBodyComponent;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   RB := PB;
   { AddForce accumulates forces; TPhysicsSystem applies them as F=ma each fixed step }
   if IsKeyDown(KEY_A) then
      RB.AddForce(Vector2Create(-8000, 0));
   if IsKeyDown(KEY_D) then
      RB.AddForce(Vector2Create(8000, 0));
   if IsKeyPressed(KEY_SPACE) then
   begin
      if RB.Grounded or (RB.CoyoteTimeLeft > 0) then
      begin
         { AddImpulse: instant velocity change, bypasses ForceAccum }
         RB.AddImpulse(Vector2Create(0, -450));
         RB.CoyoteTimeLeft := 0;
         Log('JUMP!');
      end
      else
         { RequestJump: sets JumpBufferLeft; fired on next landing }
         RB.RequestJump;
   end;
   if IsKeyPressed(KEY_G) then
   begin
      RB.UseGravity := not RB.UseGravity;
      Log(IfThen(RB.UseGravity, 'Gravity ON', 'Gravity OFF'));
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
   TMID, TR2: Integer;
   Row, Col: Integer;
   TD: TTileData;
   GX, GY: Integer;
   TC: TColor;
   RB: TRigidBodyComponent;
   Tr: TTransformComponent;
   I: Integer;
begin
   ClearBackground(ColorCreate(18, 18, 28, 255));
   DrawHeader('Demo 14 - Physics and Collision (TPhysicsSystem + TCollisionSystem)');
   DrawFooter('A/D=move  SPACE=jump (coyote+buffer)  G=gravity  B/N=bounce  R=reset');
   TMID := ComponentRegistry.GetComponentID(TTileMapComponent);
   TR2 := ComponentRegistry.GetComponentID(TTransformComponent);
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
            case TD.TileType of
               TILE_SOLID:
                  TC := ColorCreate(80, 80, 100, 255);
               TILE_SEMI:
                  TC := ColorCreate(60, 140, 60, 255);
               TILE_HAZARD:
                  TC := ColorCreate(200, 60, 60, 255);
               else
                  TC := GRAY;
            end;
            DrawRectangle(GX + 1, GY + 1, TS - 2, TS - 2, TC);
         end;
   end;
   RB := PB;
   Tr := PT;
   DrawRectangle(OX + 2 + Round(Tr.Position.X), OY + Round(Tr.Position.Y), 20, 28, IfThen(RB.Grounded, COL_GOOD, COL_ACCENT));
   DrawPanel(SCR_W - 290, DEMO_AREA_Y + 10, 280, 310, 'RigidBody State');
   DrawText(PChar(Format('Vel.X      : %6.1f', [RB.Velocity.X])), SCR_W - 280, DEMO_AREA_Y + 34, 12, COL_TEXT);
   DrawText(PChar(Format('Vel.Y      : %6.1f', [RB.Velocity.Y])), SCR_W - 280, DEMO_AREA_Y + 52, 12, COL_TEXT);
   DrawText(PChar('Grounded   : ' + IfThen(RB.Grounded, 'YES', 'no')), SCR_W - 280, DEMO_AREA_Y + 70, 12, IfThen(RB.Grounded, COL_GOOD, COL_DIMTEXT));
   DrawText(PChar('OnWall     : ' + IfThen(RB.OnWall, 'YES', 'no')), SCR_W - 280, DEMO_AREA_Y + 88, 12, IfThen(RB.OnWall, COL_WARN, COL_DIMTEXT));
   DrawText(PChar('OnCeiling  : ' + IfThen(RB.OnCeiling, 'YES', 'no')), SCR_W - 280, DEMO_AREA_Y + 106, 12, IfThen(RB.OnCeiling, COL_BAD, COL_DIMTEXT));
   DrawText(PChar(Format('CoyoteTime : %.3f s', [RB.CoyoteTimeLeft])), SCR_W - 280, DEMO_AREA_Y + 124, 12, COL_TEXT);
   DrawText(PChar(Format('JumpBuffer : %.3f s', [RB.JumpBufferLeft])), SCR_W - 280, DEMO_AREA_Y + 142, 12, COL_TEXT);
   DrawText(PChar(Format('GravScale  : %.2f', [RB.GravityScale])), SCR_W - 280, DEMO_AREA_Y + 160, 12, COL_TEXT);
   DrawText(PChar(Format('DragX      : %.2f', [RB.LinearDragX])), SCR_W - 280, DEMO_AREA_Y + 178, 12, COL_TEXT);
   DrawText(PChar(Format('Restitution: %.2f', [RB.Restitution])), SCR_W - 280, DEMO_AREA_Y + 196, 12, COL_TEXT);
   DrawText(PChar('UseGravity : ' + IfThen(RB.UseGravity, 'TRUE', 'FALSE')), SCR_W - 280, DEMO_AREA_Y + 214, 12, IfThen(RB.UseGravity, COL_GOOD, COL_BAD));
   DrawPanel(SCR_W - 290, DEMO_AREA_Y + 330, 280, 160, 'Event Log');
   for I := 0 to FLogN - 1 do
      DrawText(PChar(FLog[I]), SCR_W - 280, DEMO_AREA_Y + 354 + I * 22, 10, COL_TEXT);
end;

end.
