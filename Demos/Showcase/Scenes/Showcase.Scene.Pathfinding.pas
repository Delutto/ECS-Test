unit Showcase.Scene.Pathfinding;

{$mode objfpc}{$H+}

{ Demo 9 - A* Pathfinding
  LMB=set goal  RMB=toggle wall  1=diagonal  2=cardinal  R=rand  C=clear }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.RigidBody, P2D.Components.Pathfinder,
   P2D.Core.Pathfinding, P2D.Systems.Pathfinding, Showcase.Common;

const
   GCOLS = 24;
   GROWS = 14;
   GOFF_X = 30;
   GOFF_Y = DEMO_AREA_Y + 40;
   CELL = 38;

type
   TPathfindingDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FGrid: TAStarGrid2D;
      FAgent: TEntity;
      FPathSys: TPathfindingSystem2D;
      FGoalC, FGoalR: integer;
      FUseDiag: boolean;
      FTRID, FPFID: integer;
      FPath: TPathArray2D;
      procedure RandWalls;
      procedure ReqPath;
      function ATr: TTransformComponent;
      function APF: TPathfinderComponent2D;
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

constructor TPathfindingDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Pathfinding');
   FScreenW := AW;
   FScreenH := AH;
end;

function TPathfindingDemoScene.ATr: TTransformComponent;
begin
   Result := TTransformComponent(FAgent.GetComponentByID(FTRID));
end;

function TPathfindingDemoScene.APF: TPathfinderComponent2D;
begin
   Result := TPathfinderComponent2D(FAgent.GetComponentByID(FPFID));
end;

procedure TPathfindingDemoScene.RandWalls;
var
   C, R: integer;
begin
   FGrid.Clear;
   Randomize;
   for R := 0 to GROWS - 1 do
      for C := 0 to GCOLS - 1 do
         if Random(4) = 0 then
            FGrid.SetWalkable(C, R, False);
   FGrid.SetWalkable(0, 0, True);
   FGrid.SetWalkable(FGoalC, FGoalR, True);
end;

procedure TPathfindingDemoScene.ReqPath;
var
   PF: TPathfinderComponent2D;
begin
   PF := APF;
   PF.TargetX := GOFF_X + FGoalC * CELL + CELL div 2;
   PF.TargetY := GOFF_Y + FGoalR * CELL + CELL div 2;
   PF.PathDirty := True;
   PF.Stopped := False;
   PF.Arrived := False;
   FGrid.FindPath(0, 0, FGoalC, FGoalR, FPath, FUseDiag);
end;

procedure TPathfindingDemoScene.DoLoad;
begin
   FGrid := TAStarGrid2D.Create(GCOLS, GROWS);
   FPathSys := TPathfindingSystem2D(World.AddSystem(TPathfindingSystem2D.Create(World)));
end;

procedure TPathfindingDemoScene.DoEnter;
var
   Tr: TTransformComponent;
   PF: TPathfinderComponent2D;
begin
   FUseDiag := False;
   FGoalC := GCOLS - 2;
   FGoalR := GROWS - 2;
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FPFID := ComponentRegistry.GetComponentID(TPathfinderComponent2D);
   FGrid.SetSize(GCOLS, GROWS);
   RandWalls;
   FAgent := World.CreateEntity('Agent');
   Tr := TTransformComponent.Create;
   Tr.Position.X := GOFF_X + CELL div 2;
   Tr.Position.Y := GOFF_Y + CELL div 2;
   FAgent.AddComponent(Tr);
   FAgent.AddComponent(TRigidBodyComponent.Create);
   PF := TPathfinderComponent2D.Create;
   PF.GridRef := FGrid;
   PF.TileSize := CELL;
   PF.GridOffsetX := GOFF_X;
   PF.GridOffsetY := GOFF_Y;
   PF.MoveSpeed := 180;
   PF.FollowMode := pfmStop;
   FAgent.AddComponent(PF);
   World.Init;
   ReqPath;
end;

procedure TPathfindingDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FreeAndNil(FGrid);
end;

procedure TPathfindingDemoScene.Update(ADelta: single);
var
   MX, MY, C, R: integer;
   PF: TPathfinderComponent2D;
   RB: TRigidBodyComponent;
   Tr: TTransformComponent;
   RBID: integer;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_ONE) then
   begin
      FUseDiag := True;
      ReqPath;
   end;
   if IsKeyPressed(KEY_TWO) then
   begin
      FUseDiag := False;
      ReqPath;
   end;
   if IsKeyPressed(KEY_R) then
   begin
      RandWalls;
      ReqPath;
   end;
   if IsKeyPressed(KEY_C) then
   begin
      FGrid.Clear;
      ReqPath;
   end;
   MX := GetMouseX;
   MY := GetMouseY;
   C := (MX - GOFF_X) div CELL;
   R := (MY - GOFF_Y) div CELL;
   if (C >= 0) and (C < GCOLS) and (R >= 0) and (R < GROWS) then
   begin
      if IsMouseButtonPressed(MOUSE_BUTTON_LEFT) then
      begin
         FGoalC := C;
         FGoalR := R;
         FGrid.SetWalkable(C, R, True);
         ReqPath;
      end;
      if IsMouseButtonPressed(MOUSE_BUTTON_RIGHT) then
      begin
         FGrid.SetWalkable(C, R, not FGrid.IsWalkable(C, R));
         ReqPath;
      end;
   end;
   PF := APF;
   if PF.Arrived or PF.Stopped then
   begin
      Tr := ATr;
      Tr.Position.X := GOFF_X + CELL div 2;
      Tr.Position.Y := GOFF_Y + CELL div 2;
      RBID := ComponentRegistry.GetComponentID(TRigidBodyComponent);
      RB := TRigidBodyComponent(FAgent.GetComponentByID(RBID));
      if Assigned(RB) then
      begin
         RB.Velocity.X := 0;
         RB.Velocity.Y := 0;
      end;
      ReqPath;
   end;
   World.Update(ADelta);
end;

procedure TPathfindingDemoScene.Render;
var
   C, R, GX, GY, I: integer;
   Cl: TColor;
   Tr: TTransformComponent;
   A, B: TPathPoint2D;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 9 - A* Pathfinding (TAStarGrid2D + TPathfinderComponent2D)');
   DrawFooter('LMB=set goal   RMB=toggle wall   1=diagonal  2=cardinal  R=rand  C=clear');
   for R := 0 to GROWS - 1 do
      for C := 0 to GCOLS - 1 do
      begin
         GX := GOFF_X + C * CELL;
         GY := GOFF_Y + R * CELL;
         if not FGrid.IsWalkable(C, R) then
            Cl := ColorCreate(80, 60, 50, 255)
         else
            Cl := ColorCreate(40, 40, 55, 255);
         DrawRectangle(GX + 1, GY + 1, CELL - 2, CELL - 2, Cl);
      end;
   if Length(FPath) > 1 then
      for I := 0 to Length(FPath) - 2 do
      begin
         A := FPath[I];
         B := FPath[I + 1];
         DrawLineEx(
            Vector2Create(GOFF_X + A.Col * CELL + CELL div 2, GOFF_Y + A.Row * CELL + CELL div 2),
            Vector2Create(GOFF_X + B.Col * CELL + CELL div 2, GOFF_Y + B.Row * CELL + CELL div 2),
            3, COL_ACCENT);
      end;
   GX := GOFF_X + FGoalC * CELL;
   GY := GOFF_Y + FGoalR * CELL;
   DrawRectangle(GX + 4, GY + 4, CELL - 8, CELL - 8, COL_WARN);
   DrawText('G', GX + CELL div 2 - 5, GY + CELL div 2 - 7, 14, COL_BG);
   Tr := ATr;
   DrawCircle(Round(Tr.Position.X), Round(Tr.Position.Y), 10, COL_GOOD);
   DrawPanel(SCR_W - 220, DEMO_AREA_Y + 10, 210, 120, 'Config');
   DrawText(PChar('Mode: ' + IfThen(FUseDiag, 'Diagonal', 'Cardinal')),
      SCR_W - 210, DEMO_AREA_Y + 34, 12, COL_TEXT);
   DrawText(PChar('Steps: ' + IntToStr(Length(FPath))), SCR_W - 210, DEMO_AREA_Y + 54, 12, COL_TEXT);
   DrawText('Start: (0,0)', SCR_W - 210, DEMO_AREA_Y + 74, 11, COL_DIMTEXT);
   DrawText(PChar(Format('Goal: (%d,%d)', [FGoalC, FGoalR])), SCR_W - 210, DEMO_AREA_Y + 90, 11, COL_DIMTEXT);
end;

end.
