unit Terraria.Scene.World;

{$mode objfpc}{$H+}

{ TWorldScene — the procedural terrain demo scene.

  Systems registered (in priority order):
    TCameraSystem      (prio 15) – smooth camera, bounds
    TMapRenderSystem   (prio  5) – two-pass tile renderer

  CONTROLS
  ─────────
    WASD / Arrow keys – pan camera
    Mouse wheel       – zoom in / out
    +/-               – zoom in / out (keyboard)
    R                 – re-generate world with a new random seed
    BACKSPACE         – return to demo menu (if this is a showcase scene)
    F1                – toggle HUD overlay }

interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene,
   P2D.Core.World,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.ComponentRegistry,
   P2D.Core.Types,
   P2D.Components.Transform,
   P2D.Components.Camera2D,
   P2D.Systems.Camera,
   Terraria.Common,
   Terraria.Map,
   Terraria.Generator,
   Terraria.Systems.MapRender;

type
   TWorldScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FMap: TGameMap;
      FGenerator: TTerrainGenerator;
      FCamSys: TCameraSystem;
      FCamE: TEntity;
      FMapRender: TMapRenderSystem;
      FTRID: Integer;
      FShowHUD: boolean;
      FGenerating: boolean;
      FGenMsg: string;

      procedure RegenerateMap;
      function CamTr: TTransformComponent;
      procedure DrawHUD;
      procedure DrawBiomeLegend(AX, AY: Integer);
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AScrW, AScrH: Integer);
      destructor Destroy; override;
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

implementation

constructor TWorldScene.Create(AScrW, AScrH: Integer);
begin
   inherited Create('TerrainWorld');

   FScreenW := AScrW;
   FScreenH := AScrH;
   FShowHUD := True;
   FGenerating := False;
   FMap := TGameMap.Create;
   FGenerator := TTerrainGenerator.Create(0); { 0 = random seed each time }
end;

destructor TWorldScene.Destroy;
begin
   FMap.Free;
   FGenerator.Free;

   inherited;
end;

{ ── Helpers ─────────────────────────────────────────────────────────────── }

function TWorldScene.CamTr: TTransformComponent;
begin
   Result := TTransformComponent(FCamE.GetComponentByID(FTRID));
end;

procedure TWorldScene.RegenerateMap;
begin
   FGenerating := True;
   FGenMsg := 'Generating...';
   { Assign a fresh random seed and re-run the full pipeline }
   FGenerator.Seed := Trunc(Now * 86400000) mod $7FFFFF + 1;
   FGenerator.Generate(FMap);
   FGenMsg := Format('Seed %d — %d×%d tiles', [FGenerator.Seed, MAP_WIDTH, MAP_HEIGHT]);
   FGenerating := False;
   { Invalidate system caches so the render loop picks up fresh data }
   if Assigned(FCamSys) then
      FCamSys.InvalidateCache;
end;

{ ── Scene lifecycle ─────────────────────────────────────────────────────── }

procedure TWorldScene.DoLoad;
var
   MapRender: TMapRenderSystem;
begin
   { Camera system — created with screen size, zoom handled internally }
   FCamSys := TCameraSystem(World.AddSystem(TCameraSystem.Create(World, FScreenW, FScreenH)));

   { Map render system }
   MapRender := TMapRenderSystem.Create(World, FMap, FScreenW, FScreenH);
   FMapRender := MapRender;
   World.AddSystem(MapRender);
end;

procedure TWorldScene.DoEnter;
var
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
   WorldCX, WorldCY: Single;
begin
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);

   { Centre the camera on the middle of the map }
   WorldCX := (MAP_WIDTH * TILE_SIZE) / 2.0;
   WorldCY := (MAP_HEIGHT * TILE_SIZE) / 2.0;

   FCamE := World.CreateEntity('TerrainCamera');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(WorldCX, WorldCY);
   FCamE.AddComponent(Tr);

   Cam := TCamera2DComponent.Create;
   Cam.Zoom := DEMO_ZOOM_WIDE;
   Cam.FollowSpeed := 99999;   { snap — no smoothing for free pan }
   Cam.UseBounds := True;
   Cam.Bounds := TRectF.Create(0, 0, MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE);
   Cam.Target := FCamE;       { camera tracks the camera entity itself }
   FCamE.AddComponent(Cam);

   World.Init;

   { Generate the first terrain (blocks until done) }
   RegenerateMap;
end;

procedure TWorldScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FCamE := nil;
   FCamSys := nil;
end;

{ ── Update ──────────────────────────────────────────────────────────────── }

procedure TWorldScene.Update(ADelta: Single);
var
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
   Spd: Single;
   Wheel: Single;
begin
   { ── Input ── }
   Tr := CamTr;
   Cam := TCamera2DComponent(FCamE.GetComponentByID(ComponentRegistry.GetComponentID(TCamera2DComponent)));

   { Camera speed: faster when zoomed out }
   Spd := DEMO_SCROLL_SPD / Cam.Zoom * ADelta;

   if IsKeyDown(KEY_W) or IsKeyDown(KEY_UP) then
      Tr.Position.Y := Tr.Position.Y - Spd;
   if IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN) then
      Tr.Position.Y := Tr.Position.Y + Spd;
   if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT) then
      Tr.Position.X := Tr.Position.X - Spd;
   if IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT) then
      Tr.Position.X := Tr.Position.X + Spd;

   { Zoom via keyboard }
   if IsKeyDown(KEY_EQUAL) then
      Cam.Zoom := Min(DEMO_ZOOM_MAX, Cam.Zoom + 0.4 * ADelta);
   if IsKeyDown(KEY_MINUS) then
      Cam.Zoom := Max(DEMO_ZOOM_MIN, Cam.Zoom - 0.4 * ADelta);

   { Zoom via mouse wheel }
   Wheel := GetMouseWheelMove;
   if Wheel <> 0 then
      Cam.Zoom := Max(DEMO_ZOOM_MIN, Min(DEMO_ZOOM_MAX, Cam.Zoom + Wheel * 0.04));

   { Regenerate }
   if IsKeyPressed(KEY_R) then
      RegenerateMap;

   { Toggle HUD }
   if IsKeyPressed(KEY_F1) then
      FShowHUD := not FShowHUD;

   World.Update(ADelta);
end;

{ ── Render ──────────────────────────────────────────────────────────────── }

procedure TWorldScene.DrawBiomeLegend(AX, AY: Integer);
const
   SW = 14;
   SH = 14;
   LABELS: array[0..2] of string = ('Plains', 'Desert', 'Forest');
   COLS: array[0..2] of TColor = ((R: 56; G: 140; B: 36; A: 255), (R: 196; G: 174; B: 112; A: 255), (R: 28; G: 96; B: 24; A: 255));
var
   I: Integer;
begin
   for I := 0 to 2 do
   begin
      DrawRectangle(AX, AY + I * 20, SW, SH, COLS[I]);
      DrawRectangleLinesEx(RectangleCreate(AX, AY + I * 20, SW, SH), 1, ColorCreate(255, 255, 255, 60));
      DrawText(PChar(LABELS[I]), AX + SW + 6, AY + I * 20 + 2, 11, ColorCreate(220, 220, 220, 255));
   end;
end;

procedure TWorldScene.DrawHUD;
var
   Cam: TCamera2DComponent;
   Tr: TTransformComponent;
   PX, PY: Integer;
   TX, TY: Integer;
   TileType: byte;
   MX, MY: Integer;
   WX, WY: Single;
   RayC: TCamera2D;
   WP: TVector2;
begin
   if not FShowHUD then
      Exit;

   Cam := TCamera2DComponent(FCamE.GetComponentByID(ComponentRegistry.GetComponentID(TCamera2DComponent)));
   Tr := CamTr;

   { ── Top info bar }
   DrawRectangle(0, 0, FScreenW, 30, ColorCreate(0, 0, 0, 160));

   DrawText('TERRARIA DEMO — Procedural Map Generation', 10, 7, 14, ColorCreate(255, 220, 60, 255));
   DrawText(PChar(Format('Zoom: %.2f  |  F1=toggle HUD  R=regenerate  WASD/wheel=navigate', [Cam.Zoom])), 10, 22, 10, ColorCreate(200, 200, 200, 180));

   { Seed / size label (bottom-left) }
   DrawRectangle(0, FScreenH - 22, FScreenW, 22, ColorCreate(0, 0, 0, 140));
   DrawText(PChar(FGenMsg), 10, FScreenH - 17, 12, ColorCreate(220, 220, 180, 255));

   { FPS (bottom-right) }
   DrawText('FPS: ', FScreenW - 70, FScreenH - 20, 18, GREEN);
   DrawFPS(FScreenW - 25, FScreenH - 20);

   { ── Side panel }
   DrawRectangle(FScreenW - 200, 32, 200, 200, ColorCreate(0, 0, 0, 160));
   DrawText('Stats', FScreenW - 190, 36, 12, ColorCreate(255, 220, 60, 255));
   DrawText(PChar(Format('Map:  %d × %d tiles', [MAP_WIDTH, MAP_HEIGHT])), FScreenW - 190, 54, 11, ColorCreate(200, 200, 200, 255));
   DrawText(PChar(Format('Tile: %d px', [TILE_SIZE])), FScreenW - 190, 70, 11, ColorCreate(200, 200, 200, 255));
   DrawText(PChar(Format('World: %d × %d px', [MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE])), FScreenW - 190, 86, 11, ColorCreate(200, 200, 200, 255));

   { Camera world pos }
   DrawText(PChar(Format('Cam:  (%.0f, %.0f)', [Tr.Position.X, Tr.Position.Y])), FScreenW - 190, 104, 11, ColorCreate(180, 200, 255, 255));

   { Mouse → world → tile coords }
   MX := GetMouseX;
   MY := GetMouseY;
   RayC := FCamSys.GetRaylibCamera;
   WP := GetScreenToWorld2D(Vector2Create(MX, MY), RayC);
   TX := Trunc(WP.X / TILE_SIZE);
   TY := Trunc(WP.Y / TILE_SIZE);
   if (TX >= 0) and (TX < MAP_WIDTH) and (TY >= 0) and (TY < MAP_HEIGHT) then
   begin
      TileType := FMap.GetFG(TX, TY);
      DrawText(PChar(Format('Tile: (%d,%d) id=%d', [TX, TY, TileType])), FScreenW - 190, 122, 11, ColorCreate(200, 200, 200, 255));
      DrawText(PChar(Format('Surf: row %d  biome %d', [FMap.GetSurfaceY(TX), FMap.GetBiome(TX)])), FScreenW - 190, 138, 11, ColorCreate(200, 200, 200, 255));
   end;

   { Biome colour legend }
   DrawText('Biomes:', FScreenW - 190, 158, 11, ColorCreate(255, 220, 60, 255));
   DrawBiomeLegend(FScreenW - 190, 173);

   { ── Depth guide (right side vertical bar) ── }
   { Small vertical minimap-like ruler showing depth zones }
   PX := FScreenW - 14;
   DrawRectangle(PX - 2, 30, 12, FScreenH - 52, ColorCreate(0, 0, 0, 120));
   { Sky }
   DrawRectangle(PX, 32, 8, Round((BASE_SURFACE * TILE_SIZE / (MAP_HEIGHT * TILE_SIZE)) * (FScreenH - 54)), ColorCreate(80, 140, 220, 180));
   { Surface zone }
   PY := 32 + Round((BASE_SURFACE * TILE_SIZE / (MAP_HEIGHT * TILE_SIZE)) * (FScreenH - 54));
   DrawRectangle(PX, PY, 8, Round(((DEPTH_DIRT_STONE * TILE_SIZE) / (MAP_HEIGHT * TILE_SIZE)) * (FScreenH - 54)), ColorCreate(130, 90, 55, 200));
   { Stone zone }
   DrawRectangle(PX, PY + Round(((DEPTH_DIRT_STONE * TILE_SIZE) / (MAP_HEIGHT * TILE_SIZE)) * (FScreenH - 54)), 8, FScreenH - 54 - PY + 32 - Round(((DEPTH_DIRT_STONE * TILE_SIZE) / (MAP_HEIGHT * TILE_SIZE)) * (FScreenH - 54)), ColorCreate(118, 118, 118, 200));
end;

procedure TWorldScene.Render;
begin
   { Sky gradient background — drawn before any world-space content }
   DrawRectangleGradientV(0, 0, FScreenW, FScreenH, ColorCreate(82, 148, 226, 255), ColorCreate(42, 88, 160, 255));

   { Camera mode wraps the map render system }
   if Assigned(FCamSys) then
   begin
      FCamSys.BeginCameraMode;
      World.RenderByLayer(rlWorld);
      FCamSys.EndCameraMode;
   end;

   { HUD is drawn in screen space (outside BeginMode2D) }
   DrawHUD;
end;

end.
