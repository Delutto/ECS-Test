unit Terraria.Scene.World;

{$mode objfpc}{$H+}

{ TWorldScene — infinite procedural terrain + generation properties editor.

  GENERATION PROPERTIES EDITOR
  ─────────────────────────────
  Press TAB to show/hide the right-side editor panel (TGenEditor).
  Every change to a parameter is applied immediately to FGenerator.Params.
  Click "REGENERATE WORLD" (or press R) to wipe all loaded chunks and
  re-generate the world with the new settings. }

interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.System, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Camera2D,
   P2D.Systems.Camera,
   Terraria.Common,
   Terraria.WorldChunk,
   Terraria.ChunkManager,
   Terraria.GenParams,
   Terraria.ChunkGenerator,
   Terraria.Systems.ChunkRender,
   Terraria.UI.GenEditor;

type
   TWorldScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FManager: TChunkManager;
      FGenerator: TChunkGenerator;
      FCamSys: TCameraSystem;
      FCamE: TEntity;
      FChunkRender: TChunkRenderSystem;
      FTRID: Integer;
      FShowHUD: boolean;
      FShowEditor: boolean;
      FGenMsg: string;
      FSeed: longint;
      FEditor: TGenEditor;

      procedure ApplySeed(ASeed: longint);
      procedure RebuildWorld;
      function CamTr: TTransformComponent;
      function CamChunkX: Integer;
      function CamChunkY: Integer;
      procedure DrawHUD;
      procedure DrawChunkOverlay;
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

{ ── Constructor / Destructor ─────────────────────────────────────────── }

constructor TWorldScene.Create(AScrW, AScrH: Integer);
begin
   inherited Create('TerrainWorld');
   FScreenW := AScrW;
   FScreenH := AScrH;
   FShowHUD := True;
   FShowEditor := True;
   FSeed := 0;

   FManager := TChunkManager.Create(0);
   FGenerator := TChunkGenerator.Create(FManager, 0);
   FManager.OnGenerate := @FGenerator.GenerateChunk;

   { Editor panel — positioned right side of screen, leaving room for HUD }
   FEditor := TGenEditor.Create(AScrW - EDIT_W - 4, 34, @FGenerator.Params);
end;

destructor TWorldScene.Destroy;
begin
   FEditor.Free;
   FManager.Free;
   FGenerator.Free;
   inherited;
end;

{ ── World management ─────────────────────────────────────────────────── }

procedure TWorldScene.ApplySeed(ASeed: longint);
begin
   FSeed := ASeed;

   FGenerator.Params.SetSeed(ASeed);

   FGenerator.ApplyParams;
   FGenMsg := Format('Seed %d  |  chunk %dx%d  |  infinite world', [ASeed, CHUNK_TILES_W, CHUNK_TILES_H]);
end;

procedure TWorldScene.RebuildWorld;
begin
   { Destroy old manager/generator, create fresh ones }
   FManager.Free;
   FGenerator.Free;
   FManager := TChunkManager.Create(FSeed);
   FGenerator := TChunkGenerator.Create(FManager, FSeed);
   FManager.OnGenerate := @FGenerator.GenerateChunk;

   { Let the editor pointer follow the new params record }
   FEditor.Params := @FGenerator.Params;

   { Re-wire render system }
   if Assigned(FChunkRender) then
      FChunkRender.Manager := FManager;

   //{ Pre-stream initial viewport }
   //if Assigned(FCamE) then
   //   FManager.UpdateStreaming(CamChunkX, CamChunkY);
end;

{ ── Helpers ─────────────────────────────────────────────────────────── }

function TWorldScene.CamTr: TTransformComponent;
begin
   Result := TTransformComponent(FCamE.GetComponentByID(FTRID));
end;

function TWorldScene.CamChunkX: Integer;
begin
   Result := TChunkManager.TileToChunkX(Trunc(CamTr.Position.X / TILE_SIZE));
end;

function TWorldScene.CamChunkY: Integer;
begin
   Result := TChunkManager.TileToChunkY(Trunc(CamTr.Position.Y / TILE_SIZE));
end;

{ ── Scene lifecycle ──────────────────────────────────────────────────── }

procedure TWorldScene.DoLoad;
var
   CRend: TChunkRenderSystem;
begin
   FCamSys := TCameraSystem(World.AddSystem(TCameraSystem.Create(World, FScreenW, FScreenH)));

   CRend := TChunkRenderSystem.Create(World, FManager, FScreenW, FScreenH);
   FChunkRender := CRend;
   World.AddSystem(CRend);
end;

procedure TWorldScene.DoEnter;
var
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
   InitSeed: longint;
begin
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   InitSeed := Trunc(Now * 86400000) mod $7FFFFF + 1;
   ApplySeed(InitSeed);

   FCamE := World.CreateEntity('TerrainCamera');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(0, BASE_SURFACE * TILE_SIZE);
   FCamE.AddComponent(Tr);

   Cam := TCamera2DComponent.Create;
   Cam.Zoom := DEMO_ZOOM_WIDE;
   Cam.FollowSpeed := 99999;
   Cam.UseBounds := False;
   Cam.Target := FCamE;
   FCamE.AddComponent(Cam);

   World.Init;

   FChunkRender := TChunkRenderSystem((World as TWorld).GetSystem(TChunkRenderSystem));
   if Assigned(FChunkRender) then
      FChunkRender.Manager := FManager;

   FManager.UpdateStreaming(CamChunkX, CamChunkY);
end;

procedure TWorldScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FCamE := nil;
   FCamSys := nil;
   FChunkRender := nil;
end;

{ ── Update ───────────────────────────────────────────────────────────── }

procedure TWorldScene.Update(ADelta: Single);
var
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
   Spd: Single;
   Wheel: Single;
   CCX, CCY, MX, MY: Integer;
   EditorHovered: boolean;
   OldSeed: longint;
   SavedParams: TGenParams;
   VMX, VMY: Integer;   { virtual-canvas mouse coords }
   PhysW, PhysH: Integer;
   Sc, OX, OY: Single;
begin
   Tr := CamTr;
   Cam := TCamera2DComponent(FCamE.GetComponentByID(ComponentRegistry.GetComponentID(TCamera2DComponent)));

   Spd := DEMO_SCROLL_SPD / Cam.Zoom * ADelta;

   { Camera pan — only when not hovering the editor }
   PhysW := GetScreenWidth;
   PhysH := GetScreenHeight;
   if (PhysW > 0) and (PhysH > 0) then
   begin
      Sc := Min(PhysW / 1280.0, PhysH / 720.0);
      OX := (PhysW - 1280.0 * Sc) * 0.5;
      OY := (PhysH - 720.0 * Sc) * 0.5;
      VMX := Round((GetMouseX - OX) / Sc);
      VMY := Round((GetMouseY - OY) / Sc);
   end
   else
   begin
      VMX := GetMouseX;
      VMY := GetMouseY;
   end;
   EditorHovered := FShowEditor and (VMX >= FEditor.PX) and (VMX < FEditor.PX + EDIT_W) and (VMY >= FEditor.PY) and (VMY < FEditor.PY + EDIT_H);


   if IsKeyDown(KEY_W) or IsKeyDown(KEY_UP) then
      Tr.Position.Y := Tr.Position.Y - Spd;
   if IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN) then
      Tr.Position.Y := Tr.Position.Y + Spd;
   if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT) then
      Tr.Position.X := Tr.Position.X - Spd;
   if IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT) then
      Tr.Position.X := Tr.Position.X + Spd;

   if IsKeyDown(KEY_EQUAL) then
      Cam.Zoom := Min(DEMO_ZOOM_MAX, Cam.Zoom + 0.4 * ADelta);
   if IsKeyDown(KEY_MINUS) then
      Cam.Zoom := Max(DEMO_ZOOM_MIN, Cam.Zoom - 0.4 * ADelta);

   if not EditorHovered then
   begin
      Wheel := GetMouseWheelMove;
      if Wheel <> 0 then
         Cam.Zoom := Max(DEMO_ZOOM_MIN, Min(DEMO_ZOOM_MAX, Cam.Zoom + Wheel * 0.04));
   end;

   { Quick reseed }
   if IsKeyPressed(KEY_R) then
   begin
      ApplySeed(Trunc(Now * 86400000) mod $7FFFFF + 1);
      RebuildWorld;
      FManager.UpdateStreaming(CamChunkX, CamChunkY);
   end;

   { Toggle HUD }
   if IsKeyPressed(KEY_F1) then
      FShowHUD := not FShowHUD;

   { Toggle editor }
   if IsKeyPressed(KEY_TAB) then
      FShowEditor := not FShowEditor;

   { ── Editor update ── }
   if FShowEditor then
   begin
      if FEditor.ResetPressed then
      begin
         OldSeed := FGenerator.Params.Seed;
         FGenerator.Params := DefaultGenParams;
         FGenerator.Params.SetSeed(OldSeed);
      end;

      if FEditor.RegeneratePressed then
      begin
         { 1. Capture user's current params BEFORE the rebuild wipes them }
         SavedParams := FGenerator.Params;
         ClampGenParams(SavedParams);

         { 2. Resolve seed }
         FSeed := SavedParams.Seed;
         if FSeed = 0 then
            FSeed := Trunc(Now * 86400000) mod $7FFFFF + 1;
         SavedParams.Seed := FSeed;

         { 3. Rebuild (creates a new FGenerator with DefaultGenParams internally) }
         RebuildWorld;

         { 4. Overwrite the new generator's defaults with the user's saved params }
         FGenerator.Params := SavedParams;
         FGenerator.ApplyParams;

         { 5. Re-point the editor at the new generator's params field }
         FEditor.Params := @FGenerator.Params;
         FManager.UpdateStreaming(CamChunkX, CamChunkY);

         FGenMsg := Format('Seed %d  |  chunk %dx%d  |  infinite world', [FSeed, CHUNK_TILES_W, CHUNK_TILES_H]);
      end;

      FEditor.Update(ADelta);
   end;

   { ── Chunk streaming ── }
   CCX := CamChunkX;
   CCY := CamChunkY;
   FManager.UpdateStreaming(CCX, CCY);

   World.Update(ADelta);
end;

{ ── HUD ──────────────────────────────────────────────────────────────── }

procedure TWorldScene.DrawBiomeLegend(AX, AY: Integer);
const
   LABELS: array[0..2] of string = ('Plains', 'Desert', 'Forest');
   COLS: array[0..2] of TColor = ((R: 56; G: 140; B: 36; A: 255), (R: 196; G: 174; B: 112; A: 255), (R: 28; G: 96; B: 24; A: 255));
var
   I: Integer;
begin
   for I := 0 to 2 do
   begin
      DrawRectangle(AX, AY + I * 20, 14, 14, COLS[I]);
      DrawRectangleLinesEx(RectangleCreate(AX, AY + I * 20, 14, 14),
         1, ColorCreate(255, 255, 255, 60));
      DrawText(PChar(LABELS[I]), AX + 20, AY + I * 20 + 2, 11,
         ColorCreate(220, 220, 220, 255));
   end;
end;

procedure TWorldScene.DrawChunkOverlay;
var
   Cam: TCamera2D;
   TL, BR: TVector2;
   CX0, CY0, CX1, CY1, N, I: Integer;
   Visible: array[0..511] of TWorldChunk;
   C: TWorldChunk;
   WX, WY: Single;
begin
   if not Assigned(FCamSys) then
      Exit;
   Cam := FCamSys.GetRaylibCamera;
   TL := GetScreenToWorld2D(Vector2Create(0, 0), Cam);
   BR := GetScreenToWorld2D(Vector2Create(FScreenW, FScreenH), Cam);
   CX0 := TChunkManager.TileToChunkX(Trunc(TL.X / TILE_SIZE) - 1);
   CY0 := TChunkManager.TileToChunkY(Trunc(TL.Y / TILE_SIZE) - 1);
   CX1 := TChunkManager.TileToChunkX(Trunc(BR.X / TILE_SIZE) + 1);
   CY1 := TChunkManager.TileToChunkY(Trunc(BR.Y / TILE_SIZE) + 1);
   N := FManager.GetLoadedInRange(CX0, CY0, CX1, CY1, Visible, 512);
   for I := 0 to N - 1 do
   begin
      C := Visible[I];
      WX := C.CX * CHUNK_PIXEL_W;
      WY := C.CY * CHUNK_PIXEL_H;
      DrawRectangleLinesEx(RectangleCreate(WX, WY, CHUNK_PIXEL_W, CHUNK_PIXEL_H), 1, ColorCreate(255, 255, 255, 25));
      DrawText(PChar(Format('%d,%d', [C.CX, C.CY])), Round(WX) + 2, Round(WY) + 2, 7, ColorCreate(255, 255, 255, 90));
   end;
end;

procedure TWorldScene.DrawHUD;
var
   Cam: TCamera2DComponent;
   Tr: TTransformComponent;
   TX, TY, MX, MY: Integer;
   RayC: TCamera2D;
   WP: TVector2;
   CCX, CCY: Integer;
   TileType: byte;
   Ch: TWorldChunk;
begin
   if not FShowHUD then
      Exit;

   Cam := TCamera2DComponent(FCamE.GetComponentByID(ComponentRegistry.GetComponentID(TCamera2DComponent)));
   Tr := CamTr;

   DrawRectangle(0, 0, FScreenW, 30, ColorCreate(0, 0, 0, 160));
   DrawText('TERRARIA DEMO — Infinite Chunk World  (TAB=editor  F1=HUD  R=reseed)', 10, 7, 13, ColorCreate(255, 220, 60, 255));
   DrawText(PChar(Format('Zoom: %.2f  |  Editor: %s', [Cam.Zoom, IfThen(FShowEditor, 'ON', 'OFF')])), 10, 22, 10, ColorCreate(200, 200, 200, 180));

   DrawRectangle(0, FScreenH - 22, FScreenW, 22, ColorCreate(0, 0, 0, 140));
   DrawText(PChar(FGenMsg), 10, FScreenH - 17, 12, ColorCreate(220, 220, 180, 255));
   DrawText('FPS: ', FScreenW - 70, FScreenH - 20, 18, GREEN);
   DrawFPS(FScreenW - 25, FScreenH - 20);

   { Compact chunk panel — only when editor is closed }
   if not FShowEditor then
   begin
      DrawRectangle(FScreenW - 210, 32, 210, 230, ColorCreate(0, 0, 0, 160));
      DrawText('Chunk System', FScreenW - 200, 36, 12, ColorCreate(255, 220, 60, 255));
      CCX := CamChunkX;
      CCY := CamChunkY;
      DrawText(PChar(Format('Loaded  : %d', [FManager.LoadedCount])), FScreenW - 200, 54, 11, ColorCreate(100, 220, 100, 255));
      DrawText(PChar(Format('Created : %d', [FManager.TotalCreated])), FScreenW - 200, 70, 11, ColorCreate(200, 200, 200, 255));
      DrawText(PChar(Format('Cam chunk: (%d,%d)', [CCX, CCY])), FScreenW - 200, 90, 11, ColorCreate(180, 200, 255, 255));
      DrawText(PChar(Format('Cam world: (%.0f,%.0f)', [Tr.Position.X, Tr.Position.Y])), FScreenW - 200, 106, 11, ColorCreate(180, 200, 255, 255));
      MX := GetMouseX;
      MY := GetMouseY;
      RayC := FCamSys.GetRaylibCamera;
      WP := GetScreenToWorld2D(Vector2Create(MX, MY), RayC);
      TX := Trunc(WP.X / TILE_SIZE);
      TY := Trunc(WP.Y / TILE_SIZE);
      DrawText(PChar(Format('Mouse tile: (%d,%d)', [TX, TY])), FScreenW - 200, 122, 11, ColorCreate(200, 200, 200, 255));
      if (Abs(TChunkManager.TileToChunkX(TX) - CCX) <= VIEW_RADIUS) and (TChunkManager.TileToChunkY(TY) >= WORLD_MIN_CY) and (TChunkManager.TileToChunkY(TY) <= WORLD_MAX_CY) then
      begin
         Ch := FManager.FindLoaded(TChunkManager.TileToChunkX(TX), TChunkManager.TileToChunkY(TY));
         if Assigned(Ch) then
         begin
            TileType := Ch.GetFG(TChunkManager.TileToLocalX(TX), TChunkManager.TileToLocalY(TY));
            DrawText(PChar(Format('Tile: %d  biome %d', [TileType, FManager.GetBiome(TX)])), FScreenW - 200, 138, 11, ColorCreate(200, 200, 200, 255));
         end;
      end;
      DrawText('Biomes:', FScreenW - 200, 162, 11, ColorCreate(255, 220, 60, 255));
      DrawBiomeLegend(FScreenW - 200, 178);
   end;
end;

{ ── Render ───────────────────────────────────────────────────────────── }

procedure TWorldScene.Render;
begin
   DrawRectangleGradientV(0, 0, FScreenW, FScreenH, ColorCreate(82, 148, 226, 255), ColorCreate(42, 88, 160, 255));

   if Assigned(FCamSys) then
   begin
      FCamSys.BeginCameraMode;
      World.RenderByLayer(rlWorld);
      DrawChunkOverlay;
      FCamSys.EndCameraMode;
   end;

   DrawHUD;

   { Generation properties editor }
   if FShowEditor then
      FEditor.Draw;
end;

end.
