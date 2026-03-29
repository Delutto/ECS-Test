unit Terraria.Scene.World;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math,
   raylib,
   P2D.Core.Scene,
   P2D.Core.Entity,
   P2D.Core.World,
   P2D.Core.ComponentRegistry,
   P2D.Components.Transform,
   P2D.Components.Camera2D,
   P2D.Systems.Camera,
   Terraria.Common,
   Terraria.GenParams,
   Terraria.ChunkManager,
   Terraria.ChunkGenerator,
   Terraria.Lighting,
   Terraria.Systems.ChunkRender,
   Terraria.UI.GenEditor;

const
   EDIT_W = 260;
   EDIT_H = 720;

type
   TWorldScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FManager: TChunkManager;
      FGenerator: TChunkGenerator;
      FLightMap: TLightMap;
      FCamSys: TCameraSystem;
      FCamE: TEntity;
      FChunkRender: TChunkRenderSystem;
      FTRID: Integer;
      FShowHUD: boolean;
      FShowEditor: boolean;
      FGenMsg: string;
      FSeed: longint;
      FEditor: TGenEditor;
      FLastLoadedCount: Integer;

      function CamTr: TTransformComponent;
      function CamChunkX: Integer;
      function CamChunkY: Integer;
      procedure ApplySeed(ASeed: longint);
      procedure RebuildWorld;
      procedure DrawChunkOverlay;
      procedure DrawBiomeLegend;

   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
      procedure DoUnload; override;
   public
      constructor Create(AScreenW, AScreenH: Integer);
      destructor Destroy; override;
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Core.System,
   P2D.Utils.RayLib,
   Terraria.WorldChunk;

{ ---------------------------------------------------------------------------
  Constructor / Destructor
--------------------------------------------------------------------------- }

constructor TWorldScene.Create(AScreenW, AScreenH: Integer);
begin
   inherited Create('TerrainWorld');
   FScreenW := AScreenW;
   FScreenH := AScreenH;
   FShowHUD := True;
   FShowEditor := False;
   FSeed := 0;
   FLastLoadedCount := 0;

   FManager := TChunkManager.Create(FSeed);
   FGenerator := TChunkGenerator.Create(FManager, FSeed);
   FManager.OnGenerate := @FGenerator.GenerateChunk;
   FLightMap := TLightMap.Create(FManager);

   FEditor := TGenEditor.Create(FScreenW - EDIT_W, 0, @FGenerator.Params, @FLightMap.Settings);
end;

destructor TWorldScene.Destroy;
begin
   FEditor.Free;
   FLightMap.Free;
   FGenerator.Free;
   FManager.Free;
   inherited;
end;

{ ---------------------------------------------------------------------------
  ECS world setup
--------------------------------------------------------------------------- }

procedure TWorldScene.DoLoad;
begin
   FCamSys := TCameraSystem(World.AddSystem(TCameraSystem.Create(World, FScreenW, FScreenH)));
   FCamSys.Priority := 15;

   FChunkRender := TChunkRenderSystem(World.AddSystem(TChunkRenderSystem.Create(World, FManager, FScreenW, FScreenH)));
   FChunkRender.Priority := 30;
   FChunkRender.LightMap := FLightMap;
end;

procedure TWorldScene.DoEnter;
begin
   if FSeed = 0 then
      FSeed := Trunc(Now * 86400000) mod $7FFFFF + 1;
   ApplySeed(FSeed);

   FCamE := World.CreateEntity('Camera');
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FCamE.AddComponent(TTransformComponent.Create);
   with TTransformComponent(FCamE.GetComponentByID(FTRID)) do
   begin
      Position.X := 0;
      Position.Y := FManager.GetSurfaceY(0) * TILE_SIZE;
   end;
   with TCamera2DComponent(FCamE.AddComponent(TCamera2DComponent.Create)) do
   begin
      Zoom := DEMO_ZOOM_WIDE;
      UseBounds := False;
   end;

   World.Init;

   FChunkRender.Manager := FManager;
   FChunkRender.LightMap := FLightMap;
   FManager.UpdateStreaming(CamChunkX, CamChunkY);

   FLightMap.ComputeLighting;
   FLastLoadedCount := FManager.LoadedCount;

   FGenMsg := Format('Seed %d  |  chunk %dx%d  |  infinite world', [FSeed, CHUNK_TILES_W, CHUNK_TILES_H]);
end;

procedure TWorldScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FCamE := nil;
end;

procedure TWorldScene.DoUnload;
begin
end;

{ ---------------------------------------------------------------------------
  Private helpers
--------------------------------------------------------------------------- }

function TWorldScene.CamTr: TTransformComponent;
begin
   Result := nil;
   if Assigned(FCamE) then
      Result := TTransformComponent(FCamE.GetComponentByID(FTRID));
end;

function TWorldScene.CamChunkX: Integer;
var
   Tr: TTransformComponent;
begin
   Result := 0;
   Tr := CamTr;
   if Assigned(Tr) then
      Result := TChunkManager.TileToChunkX(Round(Tr.Position.X / TILE_SIZE));
end;

function TWorldScene.CamChunkY: Integer;
var
   Tr: TTransformComponent;
begin
   Result := 0;
   Tr := CamTr;
   if Assigned(Tr) then
      Result := TChunkManager.TileToChunkY(Round(Tr.Position.Y / TILE_SIZE));
end;

procedure TWorldScene.ApplySeed(ASeed: longint);
begin
   FSeed := ASeed;
   FGenerator.Params.SetSeed(ASeed);
   FGenerator.ApplyParams;
   FGenMsg := Format('Seed %d  |  chunk %dx%d  |  infinite world', [ASeed, CHUNK_TILES_W, CHUNK_TILES_H]);
end;

procedure TWorldScene.RebuildWorld;
begin
   FLightMap.Free;
   FManager.Free;
   FGenerator.Free;

   FManager := TChunkManager.Create(FSeed);
   FGenerator := TChunkGenerator.Create(FManager, FSeed);
   FManager.OnGenerate := @FGenerator.GenerateChunk;
   FLightMap := TLightMap.Create(FManager);

   FEditor.Params := @FGenerator.Params;
   FEditor.Lighting := @FLightMap.Settings;

   if Assigned(FChunkRender) then
   begin
      FChunkRender.Manager := FManager;
      FChunkRender.LightMap := FLightMap;
   end;
   FLastLoadedCount := 0;
end;

{ ---------------------------------------------------------------------------
  Update
--------------------------------------------------------------------------- }

procedure TWorldScene.Update(ADelta: Single);
var
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
   Spd, Wheel: Single;
   CCX, CCY: Integer;
   EditorHovered: boolean;
   OldSeed: longint;
   SavedParams: TGenParams;
   VMX, VMY: Integer;
   PhysW, PhysH: Integer;
   Sc, OX, OY: Single;
   CamID: Integer;
begin
   Tr := CamTr;
   CamID := ComponentRegistry.GetComponentID(TCamera2DComponent);
   Cam := TCamera2DComponent(FCamE.GetComponentByID(CamID));
   Spd := DEMO_SCROLL_SPD / Cam.Zoom * ADelta;

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

   { Camera pan }
   if IsKeyDown(KEY_W) or IsKeyDown(KEY_UP) then
      Tr.Position.Y := Tr.Position.Y - Spd;
   if IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN) then
      Tr.Position.Y := Tr.Position.Y + Spd;
   if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT) then
      Tr.Position.X := Tr.Position.X - Spd;
   if IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT) then
      Tr.Position.X := Tr.Position.X + Spd;

   { Zoom }
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
      FLightMap.ComputeLighting;
      FLastLoadedCount := FManager.LoadedCount;
   end;

   if IsKeyPressed(KEY_F1) then
      FShowHUD := not FShowHUD;
   if IsKeyPressed(KEY_TAB) then
      FShowEditor := not FShowEditor;

   { Editor interaction }
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
         SavedParams := FGenerator.Params;
         ClampGenParams(SavedParams);
         FSeed := SavedParams.Seed;
         if FSeed = 0 then
            FSeed := Trunc(Now * 86400000) mod $7FFFFF + 1;
         SavedParams.Seed := FSeed;
         RebuildWorld;
         FGenerator.Params := SavedParams;
         FGenerator.ApplyParams;
         FEditor.Params := @FGenerator.Params;
         FManager.UpdateStreaming(CamChunkX, CamChunkY);
         FLightMap.ComputeLighting;
         FLastLoadedCount := FManager.LoadedCount;
         FGenMsg := Format('Seed %d  |  chunk %dx%d  |  infinite world', [FSeed, CHUNK_TILES_W, CHUNK_TILES_H]);
      end;

      if FEditor.LoadPressed then
      begin
         SavedParams := FGenerator.Params;
         ClampGenParams(SavedParams);
         FSeed := SavedParams.Seed;
         if FSeed = 0 then
            FSeed := Trunc(Now * 86400000) mod $7FFFFF + 1;
         SavedParams.Seed := FSeed;
         RebuildWorld;
         FGenerator.Params := SavedParams;
         FGenerator.ApplyParams;
         FEditor.Params := @FGenerator.Params;
         FEditor.Lighting := @FLightMap.Settings;
         FManager.UpdateStreaming(CamChunkX, CamChunkY);
         FLightMap.ComputeLighting;
         FLastLoadedCount := FManager.LoadedCount;
         FGenMsg := Format('Loaded  Seed %d  |  chunk %dx%d  |  infinite world', [FSeed, CHUNK_TILES_W, CHUNK_TILES_H]);
      end;

      FEditor.Update(ADelta);
   end;

   { Chunk streaming — recompute lighting whenever any chunk loads or
     unloads.  Comparing only LoadedCount was insufficient: when exactly
     the same number of chunks load and unload in one frame (steady panning)
     the count stays constant and lighting was never refreshed, leaving new
     chunks shadowed until a subsequent frame triggered a recompute. }
   CCX := CamChunkX;
   CCY := CamChunkY;
   FManager.UpdateStreaming(CCX, CCY);

   if FManager.StreamingDirty then
   begin
      FManager.ClearStreamingDirty;
      FLightMap.ComputeLighting;
      FLastLoadedCount := FManager.LoadedCount;
   end;

   World.Update(ADelta);
end;

{ ---------------------------------------------------------------------------
  Render
--------------------------------------------------------------------------- }

procedure TWorldScene.Render;
var
   SkyTop, SkyBot: TColor;
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
   CamID: Integer;
begin
   { Sky gradient }
   SkyTop := ColorCreate(20, 80, 160, 255);
   SkyBot := ColorCreate(60, 120, 200, 255);
   DrawRectangleGradientV(0, 0, FScreenW, FScreenH, SkyTop, SkyBot);

   { World (camera space) }
   if Assigned(FCamSys) then
   begin
      FCamSys.BeginCameraMode;
      World.RenderByLayer(rlWorld);
      DrawChunkOverlay;
      FCamSys.EndCameraMode;
   end;

   { HUD (screen space) }
   if FShowHUD then
   begin
      { Top bar }
      DrawRectangle(0, 0, FScreenW, 28, ColorCreate(0, 0, 0, 160));
      DrawText(PChar('Pascal 2D Game Engine  Terraria Chunk Demo'),
         8, 6, 12, ColorCreate(220, 220, 220, 255));

      { Zoom label — guarded with plain if-then, no ternary }
      Tr := CamTr;
      CamID := ComponentRegistry.GetComponentID(TCamera2DComponent);
      if Assigned(Tr) and Assigned(FCamSys) and Assigned(FCamE) then
      begin
         Cam := TCamera2DComponent(FCamE.GetComponentByID(CamID));
         if Assigned(Cam) then
            DrawText(
               PChar(Format('Zoom: %.2f  |  TAB: editor  |  F1: HUD  |  R: reseed', [Cam.Zoom])),
               FScreenW - 420, 6, 10, ColorCreate(180, 180, 180, 255));
      end;

      { Bottom bar }
      DrawRectangle(0, FScreenH - 24, FScreenW, 24, ColorCreate(0, 0, 0, 160));
      DrawText(PChar(FGenMsg), 8, FScreenH - 18, 10, ColorCreate(200, 200, 200, 255));
      DrawText(PChar(Format('FPS: %d', [GetFPS])),
         FScreenW - 70, FScreenH - 18, 10, ColorCreate(180, 220, 100, 255));

      { Chunk info panel }
      if not FShowEditor then
      begin
         DrawRectangle(FScreenW - 180, 32, 176, 80, ColorCreate(0, 0, 0, 140));
         DrawText(
            PChar(Format('Loaded: %d  Created: %d', [FManager.LoadedCount, FManager.TotalCreated])),
            FScreenW - 174, 36, 10, ColorCreate(200, 200, 200, 255));
         DrawText(
            PChar(Format('Chunk: %d , %d', [CamChunkX, CamChunkY])),
            FScreenW - 174, 50, 10, ColorCreate(180, 180, 180, 255));
         DrawBiomeLegend;
      end;
   end;

   { Editor panel }
   if FShowEditor then
      FEditor.Draw;
end;

{ ---------------------------------------------------------------------------
  DrawChunkOverlay
--------------------------------------------------------------------------- }

procedure TWorldScene.DrawChunkOverlay;
const
   MAX_VIS = 256;
var
   RaylibCam: TCamera2D;
   TL, BR: TVector2;
   CX0, CX1, CY0, CY1: Integer;
   CX, CY, WX, WY: Integer;
   Visible: array[0..MAX_VIS - 1] of TWorldChunk;
   Count, I: Integer;
   BLCol: TColor;
begin
   if not Assigned(FCamSys) then
      Exit;

   RaylibCam := FCamSys.GetRaylibCamera;
   TL := GetScreenToWorld2D(Vector2Create(0, 0), RaylibCam);
   BR := GetScreenToWorld2D(Vector2Create(FScreenW, FScreenH), RaylibCam);

   CX0 := TChunkManager.TileToChunkX(Floor(TL.X / TILE_SIZE)) - 1;
   CX1 := TChunkManager.TileToChunkX(Ceil(BR.X / TILE_SIZE)) + 1;
   CY0 := TChunkManager.TileToChunkY(Floor(TL.Y / TILE_SIZE)) - 1;
   CY1 := TChunkManager.TileToChunkY(Ceil(BR.Y / TILE_SIZE)) + 1;

   Count := FManager.GetLoadedInRange(CX0, CY0, CX1, CY1, Visible, MAX_VIS);

   BLCol := ColorCreate(255, 255, 80, 60);
   for I := 0 to Count - 1 do
   begin
      CX := Visible[I].CX;
      CY := Visible[I].CY;
      WX := TChunkManager.ChunkToTileX(CX) * TILE_SIZE;
      WY := TChunkManager.ChunkToTileY(CY) * TILE_SIZE;
      DrawRectangleLinesEx(
         RectangleCreate(WX, WY, CHUNK_TILES_W * TILE_SIZE, CHUNK_TILES_H * TILE_SIZE),
         1, BLCol);
      DrawText(PChar(Format('%d,%d', [CX, CY])),
         WX + 2, WY + 2, 6, ColorCreate(255, 255, 80, 120));
   end;
end;

{ ---------------------------------------------------------------------------
  DrawBiomeLegend
--------------------------------------------------------------------------- }

procedure TWorldScene.DrawBiomeLegend;
const
   LX = 6;
   LY = 36;
   SZ = 10;
begin
   DrawRectangle(LX, LY, SZ, SZ, ColorCreate(80, 180, 80, 255));
   DrawText(PChar('Plains'), LX + SZ + 4, LY, 9, ColorCreate(180, 180, 180, 255));
   DrawRectangle(LX, LY + 14, SZ, SZ, ColorCreate(210, 170, 50, 255));
   DrawText(PChar('Desert'), LX + SZ + 4, LY + 14, 9, ColorCreate(180, 180, 180, 255));
   DrawRectangle(LX, LY + 28, SZ, SZ, ColorCreate(40, 140, 60, 255));
   DrawText(PChar('Forest'), LX + SZ + 4, LY + 28, 9, ColorCreate(180, 180, 180, 255));
end;

end.
