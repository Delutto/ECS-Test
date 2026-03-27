unit Showcase.Scene.Pathfinding;
{$mode objfpc}{$H+}

{ Demo 9 - Pathfinding }

interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
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
      FTexFloor, FTexWall, FTexPath, FTexGoal, FTexAgent: TTexture2D;
      procedure GenTileTextures;
      procedure FreeTileTextures;
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

function IfS(B: boolean; const T, F: string): string;
begin
   if B then
      Result := T
   else
      Result := F;
end;

constructor TPathfindingDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Pathfinding');
   FScreenW := AW;
   FScreenH := AH;
end;

procedure TPathfindingDemoScene.GenTileTextures;
var
   Img: TImage;
   S: integer;
begin
   S := CELL;
   Img := GenImageColor(S, S, ColorCreate(36, 38, 54, 255));
   ImageDrawRectangle(@Img, 1, 1, S - 2, S - 2, ColorCreate(44, 46, 64, 255));
   ImageDrawRectangle(@Img, 2, 2, 4, 4, ColorCreate(56, 60, 82, 180));
   ImageDrawRectangle(@Img, S - 6, 2, 4, 4, ColorCreate(56, 60, 82, 180));
   ImageDrawRectangle(@Img, 2, S - 6, 4, 4, ColorCreate(56, 60, 82, 180));
   ImageDrawRectangle(@Img, S - 6, S - 6, 4, 4, ColorCreate(56, 60, 82, 180));
   FTexFloor := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(S, S, ColorCreate(68, 58, 48, 255));
   ImageDrawRectangle(@Img, 1, 1, S - 2, S - 2, ColorCreate(82, 72, 58, 255));
   ImageDrawRectangle(@Img, 0, S div 2, S, 2, ColorCreate(48, 42, 34, 255));
   ImageDrawRectangle(@Img, S div 2, 0, 2, S div 2, ColorCreate(48, 42, 34, 255));
   ImageDrawRectangle(@Img, 1, 1, S - 2, 3, ColorCreate(104, 92, 74, 200));
   FTexWall := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(S, S, ColorCreate(18, 56, 76, 210));
   ImageDrawRectangle(@Img, 5, 5, S - 10, S - 10, ColorCreate(56, 172, 216, 160));
   ImageDrawRectangle(@Img, 9, 9, S - 18, S - 18, ColorCreate(80, 220, 255, 90));
   FTexPath := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(S, S, ColorCreate(76, 56, 8, 255));
   ImageDrawRectangle(@Img, 1, 1, S - 2, S - 2, ColorCreate(196, 158, 18, 255));
   ImageDrawRectangle(@Img, S div 2 - 3, 4, 6, S - 8, ColorCreate(252, 218, 40, 255));
   ImageDrawRectangle(@Img, 4, S div 2 - 3, S - 8, 6, ColorCreate(252, 218, 40, 255));
   ImageDrawRectangle(@Img, S div 2 - 5, S div 2 - 5, 10, 10, ColorCreate(255, 248, 120, 255));
   FTexGoal := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(S, S, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, S div 4, 4, S div 2, S - 8, ColorCreate(58, 218, 96, 255));
   ImageDrawRectangle(@Img, 4, S div 4, S - 8, S div 2, ColorCreate(58, 218, 96, 255));
   ImageDrawRectangle(@Img, S div 4 + 2, S div 4 + 2, S div 2 - 4, S div 2 - 4, ColorCreate(118, 255, 158, 255));
   ImageDrawRectangle(@Img, S div 2 - 3, S div 2 - 3, 6, 6, ColorCreate(255, 255, 255, 240));
   FTexAgent := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TPathfindingDemoScene.FreeTileTextures;

   procedure U(var T: TTexture2D);
   begin
      if T.Id > 0 then
      begin
         UnloadTexture(T);
         T.Id := 0;
      end;
   end;

begin
   U(FTexFloor);
   U(FTexWall);
   U(FTexPath);
   U(FTexGoal);
   U(FTexAgent);
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
   GenTileTextures;
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
   FreeTileTextures;
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
   Tr: TTransformComponent;
   A, B: TPathPoint2D;
   Dst: TRectangle;
   PathSet: array of boolean;
   PLen: integer;
begin
   ClearBackground(ColorCreate(18, 18, 30, 255));
   DrawHeader('Demo 9 - A* Pathfinding (TAStarGrid2D + TPathfinderComponent2D)');
   DrawFooter('LMB=set goal   RMB=toggle wall   1=diagonal  2=cardinal  R=rand  C=clear');
   PLen := Length(FPath);
   SetLength(PathSet, GCOLS * GROWS);
   for I := 0 to GCOLS * GROWS - 1 do
      PathSet[I] := False;
   for I := 0 to PLen - 1 do
      PathSet[FPath[I].Row * GCOLS + FPath[I].Col] := True;
   for R := 0 to GROWS - 1 do
      for C := 0 to GCOLS - 1 do
      begin
         GX := GOFF_X + C * CELL;
         GY := GOFF_Y + R * CELL;
         Dst := RectangleCreate(GX, GY, CELL, CELL);
         if not FGrid.IsWalkable(C, R) then
            DrawTexturePro(FTexWall, RectangleCreate(0, 0, CELL, CELL), Dst, Vector2Create(0, 0), 0, WHITE)
         else
         begin
            DrawTexturePro(FTexFloor, RectangleCreate(0, 0, CELL, CELL), Dst, Vector2Create(0, 0), 0, WHITE);
            if PathSet[R * GCOLS + C] then
               DrawTexturePro(FTexPath, RectangleCreate(0, 0, CELL, CELL), Dst, Vector2Create(0, 0), 0, ColorCreate(255, 255, 255, 190));
         end;
      end;
   if PLen > 1 then
      for I := 0 to PLen - 2 do
      begin
         A := FPath[I];
         B := FPath[I + 1];
         DrawLineEx(Vector2Create(GOFF_X + A.Col * CELL + CELL div 2, GOFF_Y + A.Row * CELL + CELL div 2),
            Vector2Create(GOFF_X + B.Col * CELL + CELL div 2, GOFF_Y + B.Row * CELL + CELL div 2), 2, ColorCreate(80, 220, 255, 210));
      end;
   GX := GOFF_X + FGoalC * CELL;
   GY := GOFF_Y + FGoalR * CELL;
   DrawTexturePro(FTexGoal, RectangleCreate(0, 0, CELL, CELL), RectangleCreate(GX, GY, CELL, CELL), Vector2Create(0, 0), 0, WHITE);
   Tr := ATr;
   DrawTexturePro(FTexAgent, RectangleCreate(0, 0, CELL, CELL),
      RectangleCreate(Round(Tr.Position.X) - CELL div 2, Round(Tr.Position.Y) - CELL div 2, CELL, CELL), Vector2Create(0, 0), 0, WHITE);
   DrawPanel(SCR_W - 226, DEMO_AREA_Y + 10, 216, 150, 'Config');
   DrawText(PChar('Mode  : ' + IfS(FUseDiag, 'Diagonal', 'Cardinal')), SCR_W - 216, DEMO_AREA_Y + 34, 12, COL_TEXT);
   DrawText(PChar('Steps : ' + IntToStr(PLen)), SCR_W - 216, DEMO_AREA_Y + 52, 12, COL_TEXT);
   DrawText('Start : (0,0)', SCR_W - 216, DEMO_AREA_Y + 70, 11, COL_DIMTEXT);
   DrawText(PChar(Format('Goal  : (%d,%d)', [FGoalC, FGoalR])), SCR_W - 216, DEMO_AREA_Y + 88, 11, COL_DIMTEXT);
   DrawPanel(SCR_W - 226, DEMO_AREA_Y + 170, 216, 150, 'Legend');
   DrawTexturePro(FTexFloor, RectangleCreate(0, 0, CELL, CELL), RectangleCreate(SCR_W - 214, DEMO_AREA_Y + 190, 18, 18), Vector2Create(0, 0), 0, WHITE);
   DrawText('Floor', SCR_W - 192, DEMO_AREA_Y + 193, 10, COL_DIMTEXT);
   DrawTexturePro(FTexWall, RectangleCreate(0, 0, CELL, CELL), RectangleCreate(SCR_W - 214, DEMO_AREA_Y + 212, 18, 18), Vector2Create(0, 0), 0, WHITE);
   DrawText('Wall', SCR_W - 192, DEMO_AREA_Y + 215, 10, COL_DIMTEXT);
   DrawTexturePro(FTexPath, RectangleCreate(0, 0, CELL, CELL), RectangleCreate(SCR_W - 214, DEMO_AREA_Y + 234, 18, 18), Vector2Create(0, 0), 0, WHITE);
   DrawText('Path', SCR_W - 192, DEMO_AREA_Y + 237, 10, COL_DIMTEXT);
   DrawTexturePro(FTexGoal, RectangleCreate(0, 0, CELL, CELL), RectangleCreate(SCR_W - 214, DEMO_AREA_Y + 256, 18, 18), Vector2Create(0, 0), 0, WHITE);
   DrawText('Goal', SCR_W - 192, DEMO_AREA_Y + 259, 10, COL_DIMTEXT);
   DrawTexturePro(FTexAgent, RectangleCreate(0, 0, CELL, CELL), RectangleCreate(SCR_W - 214, DEMO_AREA_Y + 278, 18, 18), Vector2Create(0, 0), 0, WHITE);
   DrawText('Agent', SCR_W - 192, DEMO_AREA_Y + 281, 10, COL_DIMTEXT);
end;

end.
