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
   Terraria.LiquidSim,
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
      FLiquidSim: TLiquidSimulator;    { cellular-automaton flow }

      { Cached lighting settings — used to detect live changes in the editor
        without requiring a full world rebuild (see NeedRelight in Update). }
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
      procedure DoUnload; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AScreenW, AScreenH: Integer);
      destructor Destroy; override;
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Core.System;

{ =============================================================================
  Private helpers
  ============================================================================= }

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

{ =============================================================================
  RebuildWorld
  ─────────────────────────────────────────────────────────────────────────────
  Recreates FManager / FGenerator / FLightMap / FLiquidPlacer while preserving
  all parameters the user has edited.  The caller is responsible for restoring
  FGenerator.Params and FLightMap.Settings after this call and then calling
  FGenerator.ApplyParams.

  Liquid integration: FLiquidPlacer is recreated after the generator so its
  internal pointer (@FGenerator.Params.Liquid) points into the new generator's
  param record.  SeedLightEmitters is called so the new lava emitter settings
  are visible to the next ComputeLighting pass.
  ============================================================================= }
procedure TWorldScene.RebuildWorld;
var
   LMLS: TLightSettings;
begin
   { Free old objects in reverse dependency order. }
   FLightMap.Free;
   FManager.Free;
   FGenerator.Free;

   { Recreate subsystems. }
   FManager := TChunkManager.Create(FSeed);
   FGenerator := TChunkGenerator.Create(FManager, FSeed);
   FManager.OnGenerate := @FGenerator.GenerateChunk;
   FLightMap := TLightMap.Create(FManager);

   { NEW — recreate the liquid placer pointing at the new generator's params.
     The placer's Params pointer is @FGenerator.Params.Liquid; this remains
     valid for the lifetime of the generator because FGenerator is owned by
     this scene and never moved in memory. }

   { NEW — register lava as a light emitter in the new TLightMap settings.
     This must be done before the first ComputeLighting call after the rebuild
     so lava pools cast orange-red light correctly. }
   LMLS := FLightMap.Settings;
   FGenerator.LiquidPlacer.SeedLightEmitters(LMLS);
   FLightMap.Settings := LMLS;

   { Re-point editor at the newly allocated param structs. }
   FEditor.Params := @FGenerator.Params;
   FEditor.Lighting := @FLightMap.Settings;

   { Keep the renderer in sync with the new manager and light map. }
   if Assigned(FChunkRender) then
   begin
      FChunkRender.Manager := FManager;
      FChunkRender.LightMap := FLightMap;
      { NEW — update the renderer's liquid params pointer so TLiquidRenderer
        reads from the new generator's param record after the rebuild. }
      FChunkRender.LiquidParams := @FGenerator.Params.Liquid;
   end;

   FLastLoadedCount := 0;

   { Recreate liquid simulator for the new world,
     then re-inject into placer and renderer. }
   FLiquidSim.Free;
   FLiquidSim := TLiquidSimulator.Create(FManager);
   FGenerator.LiquidPlacer.Simulator := FLiquidSim;
   if Assigned(FChunkRender) then
      FChunkRender.Sim := FLiquidSim;

   { Reset lighting snapshot so the first frame after rebuild does not
     trigger an extra ComputeLighting call. }
   FPrevLightSettings := FLightMap.Settings;
end;

{ =============================================================================
  DoLoad
  ─────────────────────────────────────────────────────────────────────────────
  Called once when the scene is registered.  Builds the ECS world and
  allocates all subsystems.  The OpenGL context is available here.

  Liquid integration:
    • TLiquidPlacer is created after the generator so it can receive a pointer
      into FGenerator.Params.Liquid.
    • SeedLightEmitters is called before any lighting computation.
    • TChunkRenderSystem receives the liquid params pointer so its internal
      TLiquidRenderer can draw water, lava, and mud-water tiles.
  ============================================================================= }
procedure TWorldScene.DoLoad;
var
   LMLS: TLightSettings;
begin
   FSeed := 0;
   FShowHUD := True;
   FShowEditor := True;

   { Create subsystems — seed is applied later in DoEnter. }
   FManager := TChunkManager.Create(0);
   FGenerator := TChunkGenerator.Create(FManager, 0);
   FManager.OnGenerate := @FGenerator.GenerateChunk;
   FLightMap := TLightMap.Create(FManager);

   { Create the liquid flow simulator and inject into the generator's placer.
     Must happen BEFORE UpdateStreaming (in DoEnter) generates the first chunks. }
   FLiquidSim := TLiquidSimulator.Create(FManager);
   FGenerator.LiquidPlacer.Simulator := FLiquidSim;

   { NEW — create the liquid placer.
     @FGenerator.Params.Liquid is a stable pointer for the lifetime of
     FGenerator (records embedded in objects do not move). }

   { NEW — seed lava emitter settings into the lighting system so
     ComputeLighting picks up lava light sources from the first pass. }
   LMLS := FLightMap.Settings;
   FGenerator.LiquidPlacer.SeedLightEmitters(LMLS);
   FLightMap.Settings := LMLS;

   { Add ECS systems. }
   FCamSys := TCameraSystem(World.AddSystem(TCameraSystem.Create(World, FScreenW, FScreenH)));
   FCamSys.Priority := 15;

   { NEW — pass @FGenerator.Params.Liquid to TChunkRenderSystem so its
     internal TLiquidRenderer uses the live param values from the editor. }
   FChunkRender := TChunkRenderSystem(World.AddSystem(TChunkRenderSystem.Create(World, FManager, FScreenW, FScreenH, @FGenerator.Params.Liquid, FLiquidSim)));
   FChunkRender.Priority := 30;
   FChunkRender.LightMap := FLightMap;

   { Build the editor, pointing it at the live param structs. }
   FEditor := TGenEditor.Create(FScreenW - EDIT_W - 4, (FScreenH - EDIT_H) div 2, @FGenerator.Params, @FLightMap.Settings);

   FPrevLightSettings := FLightMap.Settings;
end;

{ =============================================================================
  DoUnload
  ============================================================================= }
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

   FLiquidSim.Free;
   FLiquidSim := nil;
end;

{ =============================================================================
  DoEnter
  ─────────────────────────────────────────────────────────────────────────────
  Called every time the scene becomes active.  Seeds the generator, creates
  the camera entity, and runs the initial chunk stream + lighting pass.

  Liquid integration: no extra steps needed here — TLiquidPlacer.PlaceChunk
  is called automatically by TChunkGenerator.GenerateChunk (which fires via
  FManager.OnGenerate during UpdateStreaming).  Lava emitters were already
  registered in DoLoad via SeedLightEmitters, so ComputeLighting at the end
  of DoEnter finds them correctly.
  ============================================================================= }
procedure TWorldScene.DoEnter;
begin
   { Pick a seed if none has been set yet. }
   if FSeed = 0 then
      FSeed := Trunc(Now * 86400000) mod $7FFFFF + 1;

   ApplySeed(FSeed);

   { Update the liquid placer's seed to match (so ColRand is consistent). }
   { Note: TLiquidPlacer does not expose a Seed property setter, but its
     FSeed is set at construction time. If the seed changes between DoEnter
     calls (e.g. on a restart), RebuildWorld recreates the placer correctly. }

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

   { Initial stream: generates and places liquid in all chunks within the
     VIEW_RADIUS automatically via the OnGenerate callback. }
   FManager.UpdateStreaming(CamChunkX, CamChunkY);

   { Initial lighting: lava emitters were already registered in DoLoad. }
   FLightMap.ComputeLighting;
   FLastLoadedCount := FManager.LoadedCount;
   FPrevLightSettings := FLightMap.Settings;

   FGenMsg := Format('Seed %d  |  chunk %dx%d  |  infinite world', [FSeed, CHUNK_TILES_W, CHUNK_TILES_H]);
end;

{ =============================================================================
  DoExit
  ============================================================================= }
procedure TWorldScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   FCamE := nil;
end;

{ =============================================================================
  Update
  ─────────────────────────────────────────────────────────────────────────────
  Liquid integration notes:
    • Regenerate / Load / R-key flows call RebuildWorld which handles
      FLiquidPlacer recreation and SeedLightEmitters automatically.
    • The NeedRelight block now also checks EmitterTileID / EmitterBrightness /
      EmitR/G/B changes so that editing lava light settings triggers a relight.
    • No other per-frame work is needed: liquid placement happens at chunk
      generation time (inside TChunkGenerator.GenerateChunk), not per-frame.
  ============================================================================= }
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
   ParamsToApply: TGenParams;
   LightToApply: TLightSettings;
   NeedRelight: boolean;
   LMLS: TLightSettings;
begin
   Tr := CamTr;
   CamID := ComponentRegistry.GetComponentID(TCamera2DComponent);
   Cam := TCamera2DComponent(FCamE.GetComponentByID(CamID));
   Spd := DEMO_SCROLL_SPD / Cam.Zoom * ADelta;

   { ── Virtual-mouse coordinates ────────────────────────────────────── }
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

   { ── Quick reseed (R) ─────────────────────────────────────────────── }
   if IsKeyPressed(KEY_R) then
   begin
      ParamsToApply := FGenerator.Params;
      ParamsToApply.Seed := Trunc(Now * 86400000) mod $7FFFFF + 1;
      LightToApply := FLightMap.Settings;
      FSeed := ParamsToApply.Seed;

      RebuildWorld;  { recreates FLiquidPlacer and calls SeedLightEmitters }

      FGenerator.Params := ParamsToApply;
      FLightMap.Settings := LightToApply;
      FGenerator.ApplyParams;
      FEditor.Params := @FGenerator.Params;
      FEditor.Lighting := @FLightMap.Settings;

      { After restoring params, re-seed emitters with the (possibly edited)
        lava visual settings from the restored params. }
      LMLS := FLightMap.Settings;
      FGenerator.LiquidPlacer.SeedLightEmitters(LMLS);
      FLightMap.Settings := LMLS;

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
      { ── Reset to Defaults ── }
      if FEditor.ResetPressed then
      begin
         ParamsToApply := DefaultGenParams;
         ParamsToApply.Seed := FGenerator.Params.Seed;
         FGenerator.Params := ParamsToApply;
         { Liquid defaults are restored as part of DefaultGenParams.Liquid.
           Re-register emitters with the restored lava visual settings. }
         LMLS := FLightMap.Settings;
         FGenerator.LiquidPlacer.SeedLightEmitters(LMLS);
         FLightMap.Settings := LMLS;
      end;

      { ── Regenerate World ── }
      if FEditor.RegeneratePressed then
      begin
         ParamsToApply := FGenerator.Params;
         LightToApply := FLightMap.Settings;
         ClampGenParams(ParamsToApply);

         FSeed := ParamsToApply.Seed;
         if FSeed = 0 then
            FSeed := Trunc(Now * 86400000) mod $7FFFFF + 1;
         ParamsToApply.Seed := FSeed;

         RebuildWorld;  { recreates FLiquidPlacer with the current seed }

         FGenerator.Params := ParamsToApply;
         FLightMap.Settings := LightToApply;
         FGenerator.ApplyParams;
         FEditor.Params := @FGenerator.Params;
         FEditor.Lighting := @FLightMap.Settings;

         { Restore the liquid params pointer and re-seed emitters. }
         LMLS := FLightMap.Settings;
         FGenerator.LiquidPlacer.SeedLightEmitters(LMLS);
         FLightMap.Settings := LMLS;

         FManager.UpdateStreaming(CamChunkX, CamChunkY);
         FLightMap.ComputeLighting;
         FLastLoadedCount := FManager.LoadedCount;
         FPrevLightSettings := FLightMap.Settings;
         FGenMsg := Format('Seed %d  |  chunk %dx%d  |  infinite world', [FSeed, CHUNK_TILES_W, CHUNK_TILES_H]);
      end;

      { ── Load preset ── }
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

         LMLS := FLightMap.Settings;
         FGenerator.LiquidPlacer.SeedLightEmitters(LMLS);
         FLightMap.Settings := LMLS;

         FManager.UpdateStreaming(CamChunkX, CamChunkY);
         FLightMap.ComputeLighting;
         FLastLoadedCount := FManager.LoadedCount;
         FPrevLightSettings := FLightMap.Settings;
         FGenMsg := Format('Loaded  Seed %d  |  chunk %dx%d  |  infinite world', [FSeed, CHUNK_TILES_W, CHUNK_TILES_H]);
      end;

      { ── Live-preview: detect lighting-settings changes ───────────────
        Compares the current TLightSettings against last frame's snapshot.
        Recomputes BFS lighting only when something actually changed.

        EmitterTileID / EmitterBrightness / EmitR/G/B are now included
        in the comparison so that editing lava emissive settings in the
        Liquids editor section triggers an immediate relight.
        ──────────────────────────────────────────────────────────────── }
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
         { NEW — lava emitter changes (set via SeedLightEmitters) }
         if EmitterTileID <> FPrevLightSettings.EmitterTileID then
            NeedRelight := True;
         if EmitterBrightness <> FPrevLightSettings.EmitterBrightness then
            NeedRelight := True;
         if EmitterR <> FPrevLightSettings.EmitterR then
            NeedRelight := True;
         if EmitterG <> FPrevLightSettings.EmitterG then
            NeedRelight := True;
         if EmitterB <> FPrevLightSettings.EmitterB then
            NeedRelight := True;
         { DimBackground and BackgroundDimFactor are renderer-only;
           they take effect on the next Render call without relighting. }
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

   { ── Liquid flow simulation ──────────────────────────────────────────
     Drives the cellular-automaton one tick at a time.  Camera tile
     coordinates are passed so only the visible region is simulated. }
   if Assigned(FLiquidSim) then
      FLiquidSim.Update(ADelta);

   World.Update(ADelta);
end;

{ =============================================================================
  DrawChunkOverlay / DrawBiomeLegend — override in a subclass if desired
  ============================================================================= }

procedure TWorldScene.DrawChunkOverlay;
begin
end;

procedure TWorldScene.DrawBiomeLegend;
begin
end;

{ =============================================================================
  Render
  ─────────────────────────────────────────────────────────────────────────────
  Rendering order:
    1. Sky gradient (screen-space, full clear)
    2. World layer (camera-space):
         a. Background tiles (cave walls)
         b. Liquid layer ← drawn by TLiquidRenderer inside TChunkRenderSystem
         c. Foreground tiles (solid terrain, decorations)
    3. HUD (screen-space)
    4. Editor panel (screen-space)
  ============================================================================= }
procedure TWorldScene.Render;
var
   SkyTop, SkyBot: TColor;
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
   CamID: Integer;
begin
   SkyTop := ColorCreate(20, 80, 160, 255);
   SkyBot := ColorCreate(60, 120, 200, 255);
   DrawRectangleGradientV(0, 0, FScreenW, FScreenH, SkyTop, SkyBot);

   { World (camera space) — liquids are rendered inside World.RenderByLayer by TChunkRenderSystem between its BG and FG passes. }
   if Assigned(FCamSys) then
   begin
      FCamSys.BeginCameraMode;
      World.RenderByLayer(rlWorld);
      DrawChunkOverlay;
      FCamSys.EndCameraMode;
   end;

   { HUD }
   if FShowHUD then
   begin
      DrawRectangle(0, 0, FScreenW, 28, ColorCreate(0, 0, 0, 160));
      DrawText(PChar('Pascal 2D Game Engine  Terraria Chunk Demo'), 8, 6, 12, ColorCreate(220, 220, 220, 255));

      Tr := CamTr;
      CamID := ComponentRegistry.GetComponentID(TCamera2DComponent);
      if Assigned(Tr) and Assigned(FCamSys) and Assigned(FCamE) then
      begin
         Cam := TCamera2DComponent(FCamE.GetComponentByID(CamID));
         if Assigned(Cam) then
            DrawText(PChar(Format('Zoom: %.2f  |  TAB: editor  |  F1: HUD  |  R: reseed', [Cam.Zoom])), FScreenW - 420, 6, 10, ColorCreate(180, 180, 180, 255));
      end;

      DrawRectangle(0, FScreenH - 24, FScreenW, 24, ColorCreate(0, 0, 0, 160));
      DrawText(PChar(FGenMsg), 8, FScreenH - 18, 10, ColorCreate(200, 200, 200, 255));
      DrawText(PChar(Format('FPS: %d', [GetFPS])), FScreenW - 70, FScreenH - 18, 10, ColorCreate(180, 220, 100, 255));

      if not FShowEditor then
      begin
         DrawRectangle(FScreenW - 180, 32, 176, 80, ColorCreate(0, 0, 0, 140));
         DrawText(PChar(Format('Loaded: %d  Created: %d', [FManager.LoadedCount, FManager.TotalCreated])), FScreenW - 174, 36, 10, ColorCreate(200, 200, 200, 255));
         DrawText(PChar(Format('Chunk: %d , %d', [CamChunkX, CamChunkY])), FScreenW - 174, 50, 10, ColorCreate(180, 180, 180, 255));
         DrawBiomeLegend;
      end;
   end;

   { Editor panel }
   if FShowEditor then
      FEditor.Draw;
end;

{ =============================================================================
  Constructor / Destructor
  ============================================================================= }

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
