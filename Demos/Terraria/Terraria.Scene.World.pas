unit Terraria.Scene.World;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene,
   P2D.Core.Entity,
   P2D.Core.World,
   P2D.Core.ComponentRegistry,
   P2D.Systems.Camera,
   P2D.Components.Transform,
   P2D.Components.Camera2D,
   Terraria.Common,
   Terraria.ChunkManager,
   Terraria.ChunkGenerator,
   Terraria.Lighting,
   Terraria.GenParams,
   Terraria.UI.GenEditor,
   Terraria.Systems.ChunkRender;

const
   DEMO_SCROLL_SPD = 600.0;
   DEMO_ZOOM_WIDE = 2.0;
   DEMO_ZOOM_MIN = 0.25;
   DEMO_ZOOM_MAX = 8.0;
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

      { ── Cached snapshot of lighting settings from the previous frame.
        Used to detect when the user changes a lighting control so that
        ComputeLighting can be triggered without requiring a full rebuild. }
      FPrevLightSettings: TLightSettings;

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
   P2D.Core.System;

   { ── helpers ────────────────────────────────────────────────────────────── }

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

{ ── RebuildWorld ────────────────────────────────────────────────────────
  Recreates FManager / FGenerator / FLightMap while preserving the
  current TGenParams (including every value the user has edited in the
  editor panel) and the current TLightSettings.

  The call sequence that USED to reset values:
    1. SavedParams := FGenerator.Params          ← user edits captured
    2. RebuildWorld                              ← new generator created with
                                                   DefaultGenParams internally
    3. FGenerator.Params := SavedParams          ← edits restored

  That sequence was correct but fragile: if anything inside step 2
  called ApplyParams the generator's cached noise params could diverge
  from FGenerator.Params before step 3 ran.

  The fixed approach keeps the responsibility inside RebuildWorld itself:
  the caller passes the params to preserve, and RebuildWorld both
  restores them and calls ApplyParams in the right order.
──────────────────────────────────────────────────────────────────────── }
procedure TWorldScene.RebuildWorld;
begin
   { Free old objects — order matters (LightMap references Manager). }
   FLightMap.Free;
   FManager.Free;
   FGenerator.Free;

   { Recreate subsystems. }
   FManager := TChunkManager.Create(FSeed);
   FGenerator := TChunkGenerator.Create(FManager, FSeed);
   FManager.OnGenerate := @FGenerator.GenerateChunk;
   FLightMap := TLightMap.Create(FManager);

   { Point editor pointers at the newly allocated objects. }
   FEditor.Params := @FGenerator.Params;
   FEditor.Lighting := @FLightMap.Settings;

   { Keep the renderer in sync. }
   if Assigned(FChunkRender) then
   begin
      FChunkRender.Manager := FManager;
      FChunkRender.LightMap := FLightMap;
   end;

   FLastLoadedCount := 0;

   { Reset the cached lighting snapshot so the first frame after a rebuild
     does not mistakenly trigger an extra ComputeLighting call. }
   FPrevLightSettings := FLightMap.Settings;
end;

{ ── DoLoad / DoUnload ───────────────────────────────────────────────────── }

procedure TWorldScene.DoLoad;
begin
   FSeed := 0;
   FShowHUD := True;
   FShowEditor := True;

   { Create subsystems — no seed yet; seed is applied in DoEnter. }
   FManager := TChunkManager.Create(0);
   FGenerator := TChunkGenerator.Create(FManager, 0);
   FManager.OnGenerate := @FGenerator.GenerateChunk;
   FLightMap := TLightMap.Create(FManager);

   { Add ECS systems. }
   FCamSys := TCameraSystem(World.AddSystem(TCameraSystem.Create(World, FScreenW, FScreenH)));
   FCamSys.Priority := 15;

   FChunkRender := TChunkRenderSystem(World.AddSystem(TChunkRenderSystem.Create(World, FManager, FScreenW, FScreenH)));
   FChunkRender.Priority := 30;
   FChunkRender.LightMap := FLightMap;

   { Build the editor, pointing it at the live param structs. }
   FEditor := TGenEditor.Create(FScreenW - EDIT_W - 4, (FScreenH - EDIT_H) div 2, @FGenerator.Params, @FLightMap.Settings);

   FPrevLightSettings := FLightMap.Settings;
end;

procedure TWorldScene.DoUnload;
begin
   FEditor.Free;
   FEditor := nil;
   FLightMap.Free;
   FLightMap := nil;
   FManager.Free;
   FManager := nil;
   FGenerator.Free;
   FGenerator := nil;
end;

{ ── DoEnter / DoExit ───────────────────────────────────────────────────── }

procedure TWorldScene.DoEnter;
begin
   { Pick a seed if we do not have one yet. }
   if FSeed = 0 then
      FSeed := Trunc(Now * 86400000) mod $7FFFFF + 1;
   ApplySeed(FSeed);

   { Create the camera entity. }
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

   { Snapshot lighting so the first Update does not trigger a redundant
     ComputeLighting call. }
   FPrevLightSettings := FLightMap.Settings;

   FGenMsg := Format('Seed %d  |  chunk %dx%d  |  infinite world', [FSeed, CHUNK_TILES_W, CHUNK_TILES_H]);
end;

procedure TWorldScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FCamE := nil;
end;

{ ── Update ──────────────────────────────────────────────────────────────── }

procedure TWorldScene.Update(ADelta: Single);
var
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
   Spd, Wheel: Single;
   CCX, CCY: Integer;
   EditorHovered: boolean;
   VMX, VMY: Integer;
   PhysW, PhysH: Integer;
   Sc, OX, OY: Single;
   CamID: Integer;
   { ── Used when Regenerate / Load is pressed ── }
   ParamsToApply: TGenParams;
   LightToApply: TLightSettings;
   NeedRebuild: boolean;
   NeedRelight: boolean;
begin
   Tr := CamTr;
   CamID := ComponentRegistry.GetComponentID(TCamera2DComponent);
   Cam := TCamera2DComponent(FCamE.GetComponentByID(CamID));
   Spd := DEMO_SCROLL_SPD / Cam.Zoom * ADelta;

   { ── Virtual-mouse coords ─────────────────────────────────────────── }
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

   { ── Camera pan ───────────────────────────────────────────────────── }
   if IsKeyDown(KEY_W) or IsKeyDown(KEY_UP) then
      Tr.Position.Y := Tr.Position.Y - Spd;
   if IsKeyDown(KEY_S) or IsKeyDown(KEY_DOWN) then
      Tr.Position.Y := Tr.Position.Y + Spd;
   if IsKeyDown(KEY_A) or IsKeyDown(KEY_LEFT) then
      Tr.Position.X := Tr.Position.X - Spd;
   if IsKeyDown(KEY_D) or IsKeyDown(KEY_RIGHT) then
      Tr.Position.X := Tr.Position.X + Spd;

   { ── Zoom ─────────────────────────────────────────────────────────── }
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

   { ── Quick reseed (R key) ──────────────────────────────────────────── }
   if IsKeyPressed(KEY_R) then
   begin
      { Preserve all editor params; only replace the seed. }
      ParamsToApply := FGenerator.Params;
      ParamsToApply.Seed := Trunc(Now * 86400000) mod $7FFFFF + 1;
      LightToApply := FLightMap.Settings;
      FSeed := ParamsToApply.Seed;

      RebuildWorld;

      FGenerator.Params := ParamsToApply;
      FLightMap.Settings := LightToApply;
      FGenerator.ApplyParams;
      FEditor.Params := @FGenerator.Params;
      FEditor.Lighting := @FLightMap.Settings;

      FManager.UpdateStreaming(CamChunkX, CamChunkY);
      FLightMap.ComputeLighting;
      FLastLoadedCount := FManager.LoadedCount;
      FPrevLightSettings := FLightMap.Settings;
      FGenMsg := Format('Seed %d  |  chunk %dx%d  |  infinite world', [FSeed, CHUNK_TILES_W, CHUNK_TILES_H]);
   end;

   if IsKeyPressed(KEY_F1) then
      FShowHUD := not FShowHUD;
   if IsKeyPressed(KEY_TAB) then
      FShowEditor := not FShowEditor;

   { ── Editor interaction ───────────────────────────────────────────── }
   if FShowEditor then
   begin
      { ── Reset to Defaults ─────────────────────────────────────────
        Restore all TGenParams fields to their default values while
        keeping the current seed and current lighting settings.
        This must NOT trigger a rebuild: the user can continue editing
        and only press Regenerate when ready.
        ────────────────────────────────────────────────────────────── }
      if FEditor.ResetPressed then
      begin
         { Preserve seed and lighting before resetting. }
         ParamsToApply := DefaultGenParams;
         ParamsToApply.Seed := FGenerator.Params.Seed;
         { Assign directly — FEditor.Params still points to
           FGenerator.Params so the editor will immediately show the
           restored default values on the next Draw call. }
         FGenerator.Params := ParamsToApply;
         { DO NOT rebuild or regenerate here; the user decides when
           to press Regenerate. }
      end;

      { ── Regenerate World ──────────────────────────────────────────
        1. Capture all current editor values (including every slider
           the user has touched) BEFORE calling RebuildWorld, which
           frees and recreates the generator with DefaultGenParams.
        2. Call RebuildWorld.
        3. Restore the captured params into the new generator.
        4. Apply and stream.
        ────────────────────────────────────────────────────────────── }
      if FEditor.RegeneratePressed then
      begin
         { Step 1: snapshot everything the user has set. }
         ParamsToApply := FGenerator.Params;
         LightToApply := FLightMap.Settings;
         ClampGenParams(ParamsToApply);

         { Ensure seed is valid. }
         FSeed := ParamsToApply.Seed;
         if FSeed = 0 then
            FSeed := Trunc(Now * 86400000) mod $7FFFFF + 1;
         ParamsToApply.Seed := FSeed;

         { Step 2: rebuild (frees old objects, creates new ones with defaults). }
         RebuildWorld;

         { Step 3: restore user values into the freshly created generator. }
         FGenerator.Params := ParamsToApply;
         FLightMap.Settings := LightToApply;
         FGenerator.ApplyParams;

         { Step 4: re-point editor at the new param structs. }
         FEditor.Params := @FGenerator.Params;
         FEditor.Lighting := @FLightMap.Settings;

         { Step 5: stream and relight. }
         FManager.UpdateStreaming(CamChunkX, CamChunkY);
         FLightMap.ComputeLighting;
         FLastLoadedCount := FManager.LoadedCount;
         FPrevLightSettings := FLightMap.Settings;

         FGenMsg := Format('Seed %d  |  chunk %dx%d  |  infinite world', [FSeed, CHUNK_TILES_W, CHUNK_TILES_H]);
      end;

      { ── Load preset ───────────────────────────────────────────────
        Identical flow to Regenerate: the file was already loaded into
        FGenerator.Params by the editor's Save/Load button handler.
        ────────────────────────────────────────────────────────────── }
      if FEditor.LoadPressed then
      begin
         ParamsToApply := FGenerator.Params;
         LightToApply := FLightMap.Settings;
         ClampGenParams(ParamsToApply);

         FSeed := ParamsToApply.Seed;
         if FSeed = 0 then
            FSeed := Trunc(Now * 86400000) mod $7FFFFF + 1;
         ParamsToApply.Seed := FSeed;

         RebuildWorld;

         FGenerator.Params := ParamsToApply;
         FLightMap.Settings := LightToApply;
         FGenerator.ApplyParams;

         FEditor.Params := @FGenerator.Params;
         FEditor.Lighting := @FLightMap.Settings;

         FManager.UpdateStreaming(CamChunkX, CamChunkY);
         FLightMap.ComputeLighting;
         FLastLoadedCount := FManager.LoadedCount;
         FPrevLightSettings := FLightMap.Settings;

         FGenMsg := Format('Loaded  Seed %d  |  chunk %dx%d  |  infinite world', [FSeed, CHUNK_TILES_W, CHUNK_TILES_H]);
      end;

      { ── Live-preview: detect lighting changes ─────────────────────
        The Lighting section controls (sky colour, falloff, ambient,
        emitters, dim factor) take effect purely inside ComputeLighting
        and the renderer — no world rebuild is needed.  Compare the
        current TLightSettings with the snapshot from the previous frame
        and recompute only when something actually changed.

        NOTE: FEditor.Params points directly into FGenerator.Params and
        FEditor.Lighting points directly into FLightMap.Settings, so any
        slider click has already modified the live structs by the time we
        reach this check.
        ────────────────────────────────────────────────────────────── }
      NeedRelight := False;
      with FLightMap.Settings do
      begin
         if Enabled <> FPrevLightSettings.Enabled then
            NeedRelight := True;
         if SkyR <> FPrevLightSettings.SkyR then
            NeedRelight := True;
         if SkyG <> FPrevLightSettings.SkyG then
            NeedRelight := True;
         if SkyB <> FPrevLightSettings.SkyB then
            NeedRelight := True;
         if AmbientLight <> FPrevLightSettings.AmbientLight then
            NeedRelight := True;
         if FalloffAir <> FPrevLightSettings.FalloffAir then
            NeedRelight := True;
         if FalloffSolid <> FPrevLightSettings.FalloffSolid then
            NeedRelight := True;
         if FalloffDecor <> FPrevLightSettings.FalloffDecor then
            NeedRelight := True;
         if MushroomBrightness <> FPrevLightSettings.MushroomBrightness then
            NeedRelight := True;
         if MushroomR <> FPrevLightSettings.MushroomR then
            NeedRelight := True;
         if MushroomG <> FPrevLightSettings.MushroomG then
            NeedRelight := True;
         if MushroomB <> FPrevLightSettings.MushroomB then
            NeedRelight := True;
         { DimBackground and BackgroundDimFactor are renderer-only;
           they do not require rerunning the BFS lightmap.  They take
           effect immediately on the next Render call at zero cost. }
      end;

      if NeedRelight then
      begin
         FLightMap.ComputeLighting;
         FPrevLightSettings := FLightMap.Settings;
      end;

      FEditor.Update(ADelta);
   end;

   { ── Chunk streaming ──────────────────────────────────────────────── }
   CCX := CamChunkX;
   CCY := CamChunkY;
   FManager.UpdateStreaming(CCX, CCY);

   if FManager.StreamingDirty then
   begin
      FManager.ClearStreamingDirty;
      FLightMap.ComputeLighting;
      FLastLoadedCount := FManager.LoadedCount;
      FPrevLightSettings := FLightMap.Settings;
   end;

   World.Update(ADelta);
end;

{ ── DrawChunkOverlay / DrawBiomeLegend (unchanged) ─────────────────────── }

procedure TWorldScene.DrawChunkOverlay;
begin
   { intentionally empty — override in subclass if desired }
end;

procedure TWorldScene.DrawBiomeLegend;
begin
   { intentionally empty — override in subclass if desired }
end;

{ ── Render ──────────────────────────────────────────────────────────────── }

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
      DrawRectangle(0, 0, FScreenW, 28, ColorCreate(0, 0, 0, 160));
      DrawText(PChar('Pascal 2D Game Engine  Terraria Chunk Demo'),
         8, 6, 12, ColorCreate(220, 220, 220, 255));

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

      DrawRectangle(0, FScreenH - 24, FScreenW, 24, ColorCreate(0, 0, 0, 160));
      DrawText(PChar(FGenMsg), 8, FScreenH - 18, 10, ColorCreate(200, 200, 200, 255));
      DrawText(PChar(Format('FPS: %d', [GetFPS])),
         FScreenW - 70, FScreenH - 18, 10, ColorCreate(180, 220, 100, 255));

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

{ ── Constructor / Destructor ─────────────────────────────────────────────── }

constructor TWorldScene.Create(AScreenW, AScreenH: Integer);
begin
   inherited Create('TerrainWorld');
   FScreenW := AScreenW;
   FScreenH := AScreenH;
end;

destructor TWorldScene.Destroy;
begin
   inherited;
end;

end.
