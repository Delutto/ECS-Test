unit P2D.Systems.TileMap;

{$mode objfpc}{$H+}

{ =============================================================================
  P2D.Systems.TileMap — Frustum-Culled Tile Rendering (Optimization 3.3)

  CHANGE LOG:
    OLD: Iterated ALL grid cells (MapRows × MapCols) every frame regardless
         of the current camera viewport. For the Mario demo (40 × 15 = 600
         cells at zoom 3.0) roughly 430 of those 600 draw calls landed
         entirely outside the visible screen area.

    NEW: Computes the visible tile index range from the camera viewport once
         per frame using raylib's GetScreenToWorld2D, then iterates only the
         cells that overlap the screen. At zoom 3.0 (800 × 600 px screen)
         approximately 19 × 12 = 228 cells are visited — a 62% reduction.

  DESIGN NOTES:
    • FCamEntity is cached in Init (and refreshed whenever Init is re-called,
      e.g. after DoRestart → World.ShutdownSystems → World.Init).
    • The camera search in Init scans World.Entities.GetAll for an entity
      that carries TCamera2DComponent. This is independent of the tilemap
      component requirements — the camera is a separate entity.
    • GetScreenToWorld2D (raylib) converts screen-corner pixel coordinates
      to world-space positions using the full camera matrix (target, offset,
      zoom, rotation). This is the authoritative transformation and handles
      any camera configuration correctly without duplicating the math.
    • A ±1 tile safety margin is added to each boundary to absorb float
      rounding at tile edges. The Max/Min clamps keep the range inside the
      valid grid regardless of camera position or zoom level.
    • When no camera entity is found (headless rendering, unit tests, early
      init), the system falls back to rendering the full grid — identical
      behaviour to the original implementation.
  ============================================================================= }

interface

uses
   raylib,
   Math,
   P2D.Common,
   P2D.Core.ComponentRegistry,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Components.Transform,
   P2D.Components.TileMap,
   P2D.Components.Camera2D;

type
   { TTileMapSystem }
   TTileMapSystem = class(TSystem2D)
   private
      FTileMapID: Integer;
      FTransformID: Integer;
      FCamera: Integer;

      { Camera entity cached at Init time.
        Used every Render call to obtain the raylib TCamera2D needed by
        GetScreenToWorld2D for frustum culling.
        Re-cached automatically when Init is called again (DoRestart). }
      FCamEntity: TEntity;

      { Scans all world entities for one that carries TCamera2DComponent
        and stores the reference in FCamEntity.
        Called from Init — O(n) scan happens only once per session/restart. }
      procedure FindCameraEntity;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

implementation

{ TTileMapSystem }

constructor TTileMapSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 30;
   Name := 'TileMapSystem';
   FCamEntity := nil;
end;

{ FindCameraEntity
  Scans the entity list once and caches the first entity that owns a
  TCamera2DComponent. Called only from Init — not from the render loop.
  ─────────────────────────────────────────────────────────────────────────── }
procedure TTileMapSystem.FindCameraEntity;
var
   E: TEntity;
begin
   FCamEntity := nil;
   for E in World.Entities.GetAll do
   begin
      if E.HasComponent(TCamera2DComponent) then
      begin
         FCamEntity := E;
         FCamera := ComponentRegistry.GetComponentID(TCamera2DComponent);
         Exit;
      end;
   end;

   {$IFDEF DEBUG}
   if Not Assigned(FCamEntity) then
   begin
      P2D.Utils.Logger.Logger.Warn(
         '[TileMapSystem] No camera entity found — frustum culling disabled.')
   end;
   {$ENDIF}
end;

procedure TTileMapSystem.Init;
begin
   inherited;

   RequireComponent(TTileMapComponent);
   RequireComponent(TTransformComponent);

   FTileMapID := ComponentRegistry.GetComponentID(TTileMapComponent);
   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);

   { Cache the camera entity for use in Render.
     This must run after LoadLevel has created the camera entity, which is
     guaranteed because World.Init is called after LoadLevel in both
     OnInit and DoRestart. }
   FindCameraEntity;
end;

procedure TTileMapSystem.Update(ADelta: Single);
begin
   { Tilemap is static — nothing to update each frame. }
end;

{ Render
  ─────────────────────────────────────────────────────────────────────────────
  Frustum-culling overview:

    1. Before the entity loop, resolve the camera once:
         • Validate FCamEntity (alive + has TCamera2DComponent).
         • Call GetScreenToWorld2D for the screen's top-left (0, 0) and
           bottom-right (ScreenW, ScreenH) corners.
         • This gives TL and BR in world-space coordinates.

    2. For each tilemap entity, convert TL/BR from world to tile indices:
         TileCol = (WorldX - TileMap.OriginX) / TileWidth
         TileRow = (WorldY - TileMap.OriginY) / TileHeight
         Clamped to [0 .. MapCols-1] and [0 .. MapRows-1].
         A ±1 margin on each edge absorbs sub-pixel rounding.

    3. Iterate only ColStart..ColEnd × RowStart..RowEnd.

  Fallback: if no camera is found, ColStart/RowStart = 0 and
  ColEnd/RowEnd = MapCols-1/MapRows-1 (identical to old behavior).
  ─────────────────────────────────────────────────────────────────────────── }
procedure TTileMapSystem.Render;
var
   E: TEntity;
   TM: TTileMapComponent;
   Tr: TTransformComponent;
   R, C: Integer;
   Tile: TTileData;
   Src: TRectangle;
   Dst: TRectangle;
   Cam: TCamera2DComponent;
   TL, BR: TVector2;   // world-space screen corners
   ColStart, ColEnd: Integer;
   RowStart, RowEnd: Integer;
   HasCam: boolean;
   VW, VH: Integer;
begin
   { ── Step 1: Resolve camera and compute world-space viewport ─────────────
     This block runs ONCE per frame, outside the tilemap entity loop.
     GetScreenToWorld2D accounts for the camera's Target, Offset, Zoom and
     Rotation fields, so the result is always correct regardless of how
     TCameraSystem configures the raylib camera struct. }
   HasCam := Assigned(FCamEntity) and FCamEntity.Alive;
   if HasCam then
   begin
      Cam := TCamera2DComponent(FCamEntity.GetComponentByID(FCamera));
      HasCam := Assigned(Cam);
   end
   else
   begin
      Cam := nil;
   end;  { suppress "may be uninitialised" warning }

   if HasCam then
   begin
      { TCameraSystem sets Offset = (VirtualW/2, VirtualH/2).
        Multiply by 2 to recover the full virtual canvas dimensions.
        GetScreenToWorld2D with corners (0,0) and (VW,VH) gives the world-space rectangle visible through
      the virtual canvas — correct at any physical resolution because only the camera matrix matters. }
      VW := Round(Cam.RaylibCamera.Offset.X * 2);
      VH := Round(Cam.RaylibCamera.Offset.Y * 2);
      TL := GetScreenToWorld2D(Vector2Create(0, 0), Cam.RaylibCamera);
      BR := GetScreenToWorld2D(Vector2Create(VW, VH), Cam.RaylibCamera);
   end;

   { ── Step 2 + 3: Render each tilemap with culled tile range ─────────────── }
   for E in GetMatchingEntities do
   begin
      TM := TTileMapComponent(E.GetComponentByID(FTileMapID));
      Tr := TTransformComponent(E.GetComponentByID(FTransformID));

      if not (TM.Enabled and Tr.Enabled) then
      begin
         Continue;
      end;
      if TM.TileSet.Id = 0 then
      begin
         Continue;
      end;

      if HasCam then
      begin
         { ── Frustum cull: convert world coords to tile indices ─────────────
           Subtract the tilemap's world origin (Tr.Position) before dividing
           by tile size so that offset tilemaps are handled correctly.

           The ±1 margin prevents a one-frame visual pop when a tile's edge
           is exactly on the screen boundary and floating-point truncation
           would exclude it.

           Max/Min clamps ensure the range stays within valid grid indices
           even when the camera looks beyond the tilemap's bounds
           (e.g. player near a level edge at high zoom). }
         ColStart := Max(0, Trunc((TL.X - Tr.Position.X) / TM.TileWidth) - 1);
         ColEnd := Min(TM.MapCols - 1, Trunc((BR.X - Tr.Position.X) / TM.TileWidth) + 1);
         RowStart := Max(0, Trunc((TL.Y - Tr.Position.Y) / TM.TileHeight) - 1);
         RowEnd := Min(TM.MapRows - 1, Trunc((BR.Y - Tr.Position.Y) / TM.TileHeight) + 1);
      end
      else
      begin
         { ── Fallback: no camera found → render the entire grid ────────────
           Identical to the original unculled implementation. Used when
           rendering without a camera (headless tests, title screens, etc.). }
         ColStart := 0;
         ColEnd := TM.MapCols - 1;
         RowStart := 0;
         RowEnd := TM.MapRows - 1;
      end;

      { ── Draw only the visible tile range ───────────────────────────────── }
      for R := RowStart to RowEnd do
      begin
         for C := ColStart to ColEnd do
         begin
            Tile := TM.GetTile(C, R);
            if Tile.TileID = TILE_NONE then
            begin
               Continue;
            end;

            Src := TM.GetTileRect(Tile.TileID - 1);
            Dst.X := Tr.Position.X + C * TM.TileWidth;
            Dst.Y := Tr.Position.Y + R * TM.TileHeight;
            Dst.Width := TM.TileWidth;
            Dst.Height := TM.TileHeight;

            DrawTexturePro(TM.TileSet, Src, Dst, Vector2Create(0, 0), 0, WHITE);
         end;
      end;
   end;
end;

end.
