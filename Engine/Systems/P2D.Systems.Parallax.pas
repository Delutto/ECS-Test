unit P2D.Systems.Parallax;

{$mode objfpc}{$H+}

{ =============================================================================
  TParallaxSystem2D — screen-space parallax background renderer.

  KEY DESIGN DECISIONS
  ─────────────────────
  1. Only TParallaxLayerComponent2D + TTransformComponent are required.
     TSpriteComponent is intentionally absent: if a parallax entity carried
     TSpriteComponent, TRenderSystem would also match it and draw the raw
     texture in rlWorld space (inside BeginMode2D × zoom=3), producing a
     texture thousands of pixels wide that covers the entire tilemap.

  2. RenderLayer = rlBackground, drawn BEFORE BeginMode2D.
     Scene Render order must be:
       World.RenderByLayer(rlBackground)   ← this system
       BeginMode2D → World.RenderByLayer(rlWorld) → EndMode2D
       World.RenderByLayer(rlScreen)

  3. Entities are sorted by TParallaxLayerComponent2D.ZOrder each frame
     so lower-ZOrder layers (distant background) are always drawn first,
     regardless of ECS entity creation order.

  SCROLL MATH (screen space)
  ───────────────────────────
  RawOffX  = CamTargetX × ScrollFactorX       { pixels scrolled }
  TexOffX  = RawOffX mod DrawW                { seamless wrap   }
  DrawX[i] = BaseX − TexOffX + i × DrawW     { tiled copies    }
  NumCols  = ceil(ScreenW / DrawW) + 2        { fill + margins  }

  Because the tilemap is inside BeginMode2D (zoom = 3), its apparent
  screen speed for a camera displacement d is: d × 3 pixels.
  A parallax layer with ScrollFactorX = f moves at d × f pixels, giving
  a visual depth ratio of f / zoom (e.g. f=0.6, zoom=3 → 20% of tile speed).
  ============================================================================= }

interface

uses
   SysUtils,
   Math,
   raylib,
   P2D.Core.ComponentRegistry,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Components.Transform,
   P2D.Components.ParallaxLayer,
   P2D.Components.Camera2D;

type
   { Small sort-pair used inside Render to order layers by ZOrder. }
   TLayerEntry = record
      Entity: TEntity;
      ZOrder: Integer;
   end;

   TParallaxSystem2D = class(TSystem2D)
   private
      FParallaxID: Integer;
      FTransformID: Integer;
      FCameraID: Integer;
      FCamEntity: TEntity;
      FScreenW: Integer;
      FScreenH: Integer;

      { Reusable sort buffer — grows as needed, never shrinks. }
      FSortBuf: array of TLayerEntry;
      FSortCount: Integer;

      procedure FindCameraEntity;
      function GetCamTargetX: Single;
      function GetCamTargetY: Single;

    { Insertion sort on FSortBuf[0..FSortCount-1] by ZOrder (ascending).
      In practice FSortCount is 2-4, so O(n²) is perfectly fast. }
      procedure SortLayers;
   public
      constructor Create(AWorld: TWorldBase; AScreenW, AScreenH: Integer); reintroduce;
      procedure Init; override;
      procedure Render; override;
      procedure Shutdown; override;
   end;

implementation

constructor TParallaxSystem2D.Create(AWorld: TWorldBase; AScreenW, AScreenH: Integer);
begin
   inherited Create(AWorld);

   Priority := 10;
   Name := 'ParallaxSystem';
   RenderLayer := rlBackground;
   FScreenW := AScreenW;
   FScreenH := AScreenH;
   FCamEntity := nil;
   FSortCount := 0;
   SetLength(FSortBuf, 8);
end;

procedure TParallaxSystem2D.FindCameraEntity;
var
   E: TEntity;
begin
   FCamEntity := nil;
   for E in World.Entities.GetAll do
   begin
      if E.Alive and E.HasComponent(TCamera2DComponent) then
      begin
         FCamEntity := E;
         Exit;
      end;
   end;
end;

function TParallaxSystem2D.GetCamTargetX: Single;
var
   Cam: TCamera2DComponent;
begin
   Result := 0;
   if not (Assigned(FCamEntity) and FCamEntity.Alive) then
   begin
      Exit;
   end;
   Cam := TCamera2DComponent(FCamEntity.GetComponentByID(FCameraID));
   if Assigned(Cam) then
   begin
      Result := Cam.RaylibCamera.Target.X;
   end;
end;

function TParallaxSystem2D.GetCamTargetY: Single;
var
   Cam: TCamera2DComponent;
begin
   Result := 0;
   if not (Assigned(FCamEntity) and FCamEntity.Alive) then
   begin
      Exit;
   end;
   Cam := TCamera2DComponent(FCamEntity.GetComponentByID(FCameraID));
   if Assigned(Cam) then
   begin
      Result := Cam.RaylibCamera.Target.Y;
   end;
end;

procedure TParallaxSystem2D.SortLayers;
var
   I, J: Integer;
   Tmp: TLayerEntry;
begin
   for I := 1 to FSortCount - 1 do
   begin
      Tmp := FSortBuf[I];
      J := I - 1;
      while (J >= 0) and (FSortBuf[J].ZOrder > Tmp.ZOrder) do
      begin
         FSortBuf[J + 1] := FSortBuf[J];
         Dec(J);
      end;
      FSortBuf[J + 1] := Tmp;
   end;
end;

procedure TParallaxSystem2D.Init;
begin
   inherited;

   { Only require the two components this system actually reads from.
    No TSpriteComponent — that would cause TRenderSystem to also pick up
    parallax entities and draw them in world space at huge apparent size. }
   RequireComponent(TParallaxLayerComponent2D);
   RequireComponent(TTransformComponent);

   FParallaxID := ComponentRegistry.GetComponentID(TParallaxLayerComponent2D);
   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
   FCameraID := ComponentRegistry.GetComponentID(TCamera2DComponent);

   FindCameraEntity;
end;

procedure TParallaxSystem2D.Render;
var
   E: TEntity;
   PL: TParallaxLayerComponent2D;
   Tr: TTransformComponent;
   CamX: Single;
   CamY: Single;
   { Per-layer drawing state }
   TexW: Integer;
   TexH: Integer;
   DrawW: Single;
   DrawH: Single;
   RawOffX: Single;
   RawOffY: Single;
   TexOffX: Single;
   TexOffY: Single;
   NumCols: Integer;
   NumRows: Integer;
   ColIdx: Integer;
   RowIdx: Integer;
   DrawX: Single;
   DrawY: Single;
   Src: TRectangle;
   Dst: TRectangle;
   I: Integer;
begin
   { ── Phase 1: collect matching entities into sort buffer ────────────────── }
   FSortCount := 0;
   for E in GetMatchingEntities do
   begin
      PL := TParallaxLayerComponent2D(E.GetComponentByID(FParallaxID));
      if not Assigned(PL) or not PL.Enabled then
      begin
         Continue;
      end;
      if PL.Texture.Id = 0 then
      begin
         Continue;
      end;  { no texture yet }

      if FSortCount >= Length(FSortBuf) then
      begin
         SetLength(FSortBuf, FSortCount * 2);
      end;

      FSortBuf[FSortCount].Entity := E;
      FSortBuf[FSortCount].ZOrder := PL.ZOrder;
      Inc(FSortCount);
   end;

   if FSortCount = 0 then
   begin
      Exit;
   end;

   { ── Phase 2: sort by ZOrder ascending (far → near) ─────────────────────── }
   SortLayers;

   { ── Phase 3: resolve camera position once ──────────────────────────────── }
   CamX := GetCamTargetX;
   CamY := GetCamTargetY;

   { ── Phase 4: draw layers in sorted order ───────────────────────────────── }
   for I := 0 to FSortCount - 1 do
   begin
      E := FSortBuf[I].Entity;
      PL := TParallaxLayerComponent2D(E.GetComponentByID(FParallaxID));
      Tr := TTransformComponent(E.GetComponentByID(FTransformID));

      if not (Assigned(PL) and Assigned(Tr)) then
      begin
         Continue;
      end;
      if not (PL.Enabled and Tr.Enabled) then
      begin
         Continue;
      end;

      TexW := PL.Texture.Width;
      TexH := PL.Texture.Height;
      DrawW := TexW * Tr.Scale.X;
      DrawH := TexH * Tr.Scale.Y;

      if (DrawW <= 0) or (DrawH <= 0) then
      begin
         Continue;
      end;

      { Scroll offset in screen pixels }
      RawOffX := CamX * PL.ScrollFactorX;
      RawOffY := CamY * PL.ScrollFactorY;

      { Wrap into [0, DrawW) for seamless horizontal tiling }
      if PL.TileH then
      begin
         TexOffX := RawOffX - Floor(RawOffX / DrawW) * DrawW;
         NumCols := Ceil(FScreenW / DrawW) + 2;
      end
      else
      begin
         TexOffX := RawOffX;
         NumCols := 1;
      end;

      { Wrap into [0, DrawH) for seamless vertical tiling }
      if PL.TileV then
      begin
         TexOffY := RawOffY - Floor(RawOffY / DrawH) * DrawH;
         NumRows := Ceil(FScreenH / DrawH) + 2;
      end
      else
      begin
         TexOffY := RawOffY;
         NumRows := 1;
      end;

      { Source = full texture, always }
      Src.X := 0;
      Src.Y := 0;
      Src.Width := TexW;
      Src.Height := TexH;

      for RowIdx := 0 to NumRows - 1 do
      begin
         DrawY := Tr.Position.Y - TexOffY + RowIdx * DrawH;

         { Skip rows entirely outside the canvas }
         if (DrawY + DrawH < 0) or (DrawY > FScreenH) then
         begin
            Continue;
         end;

         for ColIdx := 0 to NumCols - 1 do
         begin
            DrawX := Tr.Position.X - TexOffX + ColIdx * DrawW;

            { Skip columns entirely outside the canvas }
            if (DrawX + DrawW < 0) or (DrawX > FScreenW) then
            begin
               Continue;
            end;

            Dst.X := DrawX;
            Dst.Y := DrawY;
            Dst.Width := DrawW;
            Dst.Height := DrawH;

            DrawTexturePro(PL.Texture, Src, Dst, Vector2Create(0, 0), Tr.Rotation, ColorCreate(PL.Tint.R, PL.Tint.G, PL.Tint.B, PL.Tint.A));
         end;
      end;
   end;
end;

procedure TParallaxSystem2D.Shutdown;
begin
   FCamEntity := nil;

   inherited;
end;

end.
