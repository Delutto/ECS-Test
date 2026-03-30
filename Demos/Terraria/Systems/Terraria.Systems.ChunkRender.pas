unit Terraria.Systems.ChunkRender;

{$mode objfpc}{$H+}

{ TChunkRenderSystem — renders loaded chunks with optional BFS lighting.

  SOIL SPRITESHEET RENDERING
  ──────────────────────────
  All solid terrain tiles (IDs 1–13, i.e. TILE_AIR < ID < TILE_SHRUB) are
  rendered from the external spritesheet  soils_better_16x16.png  instead of
  procedurally-generated CPU textures.

  Spritesheet layout:
    • 4 columns × 13 rows
    • Each cell is SOIL_SHEET_TILE (16) × SOIL_SHEET_TILE (16) pixels
    • Column index  (0–3) = visual variation of the same soil type
    • Row index     (0–12) = soil type (see SOIL_SHEET_ROW in Terraria.Common)

  VARIATION SELECTION
  ───────────────────
  For every solid tile at world position (WTX, WTY) a variation column is
  selected using a fast, branchless integer hash:

      H  = (WTX * 1664525) XOR (WTY * 22695477)
      H  = H XOR (H SHR 16)
      col = H AND 3   →  0, 1, 2, or 3

  This hash is deterministic (same seed-less position → same column) and
  produces visually uncorrelated values for adjacent tiles, making the map
  look organic without any extra storage.

  BACKGROUND TILES
  ────────────────
  Background (wall) soil tiles are rendered from the same spritesheet but with
  all RGB channels of the computed tint multiplied by SOIL_BG_DIM (0.45),
  giving the characteristic darker-behind-wall appearance.

  DECORATION TILES
  ────────────────
  Tiles with ID >= TILE_SHRUB (shrubs, trees, roots, vines, etc.) continue to
  use the procedurally-generated FTex / FTexBG textures from GenTileTextures. }

interface

uses
   SysUtils, Math, raylib,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Systems.Camera,
   Terraria.Common,
   Terraria.WorldChunk,
   Terraria.ChunkManager,
   Terraria.Lighting;

const
   MAX_VISIBLE_CHUNKS = 512;

type
   TChunkRenderSystem = class(TSystem2D)
   private
      FManager: TChunkManager;
      FLightMap: TLightMap;
      FCamSys: TCameraSystem;
      FScreenW: Integer;
      FScreenH: Integer;

      { Spritesheet for all solid terrain tiles }
      FSoilSheet: TTexture2D;

      { Procedural textures for decoration tiles (ID >= TILE_SHRUB).
        FTex  = foreground (full brightness).
        FTexBG = background wall version (darker, tinted at generation time). }
      FTex: array[0..TILE_COUNT - 1] of TTexture2D;
      FTexBG: array[0..TILE_COUNT - 1] of TTexture2D;

      FVisible: array[0..MAX_VISIBLE_CHUNKS - 1] of TWorldChunk;

      { Returns the variation column (0–3) for a world tile coordinate pair.
        The result is deterministic and spatially uncorrelated — adjacent tiles
        almost never share the same column. }
      function TileVariation(WTX, WTY: Integer): Integer; inline;

      { Generates procedural CPU textures only for decoration tiles
        (ID >= TILE_SHRUB).  Soil tiles are served by the spritesheet. }
      procedure GenDecorTextures;
      procedure FreeAllTextures;
      procedure RenderChunk(AChunk: TWorldChunk; AIsFG: boolean);
   public
      constructor Create(AWorld: TWorldBase; AManager: TChunkManager; AScrW, AScrH: Integer); reintroduce;
      destructor Destroy; override;
      procedure Init; override;
      procedure Render; override;
      procedure Shutdown; override;
      property Manager: TChunkManager read FManager write FManager;
      property LightMap: TLightMap read FLightMap write FLightMap;
   end;

implementation

{ ── Inline variation hash ────────────────────────────────────────────────── }

function TChunkRenderSystem.TileVariation(WTX, WTY: Integer): Integer;
var
   H: cardinal;
begin
   { Mix X and Y with distinct multipliers, then fold the high bits down. }
   H := cardinal(WTX) * 1664525 xor cardinal(WTY) * 22695477;
   H := H xor (H shr 16);
   Result := Integer(H and 3);   { 0, 1, 2, or 3 — never negative }
end;

{ ── Procedural decoration texture helpers ────────────────────────────────── }

{ Builds a foreground image and a matching background image for a decoration
  tile, both starting from a transparent base so they blend correctly over
  the soil or sky behind them. }
procedure MakeDecorPair(var ATex, ATex_BG: TTexture2D; BR, BG, BB: byte; const Det: array of TRect4; Alpha: byte = 255);
var
   Img: TImage;
   J: Integer;
begin
   { Foreground — transparent background, only detail rects drawn }
   Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(0, 0, 0, 0));
   if Alpha = 255 then
      ImageDrawRectangle(@Img, 1, 0, TILE_SIZE - 2, TILE_SIZE,
         ColorCreate(BR, BG, BB, 255));
   for J := 0 to High(Det) do
      ImageDrawRectangle(@Img, Det[J].X, Det[J].Y, Det[J].W, Det[J].H,
         ColorCreate(Det[J].R, Det[J].G, Det[J].B, Alpha));
   ATex := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { Background — always fully transparent for decorations }
   Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(0, 0, 0, 0));
   ATex_BG := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

{ Fills any slot whose texture was never set with a 1×1 transparent fallback,
  preventing a spurious Id=0 crash in the render path. }
procedure EnsureTransparentFallback(var ATex: TTexture2D);
var
   Img: TImage;
begin
   if ATex.Id = 0 then
   begin
      Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(0, 0, 0, 0));
      ATex := LoadTextureFromImage(Img);
      UnloadImage(Img);
   end;
end;

procedure TChunkRenderSystem.GenDecorTextures;
var
   I: Integer;
   Img: TImage;
begin
   { ── Surface vegetation ────────────────────────────────────────────────── }
   MakeDecorPair(FTex[TILE_SHRUB], FTexBG[TILE_SHRUB], 0, 0, 0, TILE_SHRUB_RGB, 200);

   MakeDecorPair(FTex[TILE_TREE_TRUNK], FTexBG[TILE_TREE_TRUNK], 110, 72, 40, TILE_TREE_TRUNK_RGB);

   { Tree leaf — use full detail overdraw for realistic canopy }
   MakeDecorPair(FTex[TILE_TREE_LEAF], FTexBG[TILE_TREE_LEAF], 40, 130, 36, TILE_TREE_LEAF_RGB, 200);

   { Additional leaf overdraw for rounder canopy appearance }
   begin
      Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(40, 130, 36, 200));
      ImageDrawRectangle(@Img, 1, 1, 2, 2, ColorCreate(60, 160, 50, 220));
      ImageDrawRectangle(@Img, 5, 2, 2, 2, ColorCreate(56, 154, 46, 220));
      ImageDrawRectangle(@Img, 2, 5, 3, 2, ColorCreate(52, 148, 42, 220));
      ImageDrawRectangle(@Img, 0, 0, 1, 1, ColorCreate(0, 0, 0, 0));
      ImageDrawRectangle(@Img, 7, 0, 1, 1, ColorCreate(0, 0, 0, 0));
      ImageDrawRectangle(@Img, 0, 7, 1, 1, ColorCreate(0, 0, 0, 0));
      ImageDrawRectangle(@Img, 7, 7, 1, 1, ColorCreate(0, 0, 0, 0));
      UnloadTexture(FTex[TILE_TREE_LEAF]);
      FTex[TILE_TREE_LEAF] := LoadTextureFromImage(Img);
      UnloadImage(Img);
   end;

   MakeDecorPair(FTex[TILE_CACTUS], FTexBG[TILE_CACTUS], 0, 0, 0, TILE_CACTUS_RGB, 200);
   MakeDecorPair(FTex[TILE_CACTUS_TOP], FTexBG[TILE_CACTUS_TOP], 0, 0, 0, TILE_CACTUS_TOP_RGB, 200);
   MakeDecorPair(FTex[TILE_FERN], FTexBG[TILE_FERN], 0, 0, 0, TILE_FERN_RGB, 200);

   { ── Cave decorations ──────────────────────────────────────────────────── }
   MakeDecorPair(FTex[TILE_ROOT], FTexBG[TILE_ROOT], 0, 0, 0, TILE_ROOT_RGB, 255);
   MakeDecorPair(FTex[TILE_VINE], FTexBG[TILE_VINE], 0, 0, 0, TILE_VINE_RGB, 200);
   MakeDecorPair(FTex[TILE_STALACTITE], FTexBG[TILE_STALACTITE], 0, 0, 0, TILE_STALACTITE_RGB, 200);
   MakeDecorPair(FTex[TILE_STALAGMITE], FTexBG[TILE_STALAGMITE], 0, 0, 0, TILE_STALAGMITE_RGB, 200);
   MakeDecorPair(FTex[TILE_MUSHROOM], FTexBG[TILE_MUSHROOM], 0, 0, 0, TILE_MUSHROOM_RGB, 240);
   MakeDecorPair(FTex[TILE_MOSS], FTexBG[TILE_MOSS], 0, 0, 0, TILE_MOSS_RGB, 180);

   { Guarantee every slot has a valid (possibly transparent) texture.
     Soil tile slots (0..TILE_SHRUB-1) are intentionally left with Id=0 here because the render path never indexes FTex/FTexBG for those IDs —
     it uses FSoilSheet instead.  The fallback covers any future decoration tile IDs that were not explicitly generated above. }
   for I := TILE_SHRUB to TILE_COUNT - 1 do
   begin
      EnsureTransparentFallback(FTex[I]);
      EnsureTransparentFallback(FTexBG[I]);
   end;
end;

procedure TChunkRenderSystem.FreeAllTextures;
var
   I: Integer;
begin
   { Unload the soil spritesheet }
   if FSoilSheet.Id > 0 then
   begin
      UnloadTexture(FSoilSheet);
      FSoilSheet.Id := 0;
   end;

   { Unload decoration textures }
   for I := TILE_SHRUB to TILE_COUNT - 1 do
   begin
      if FTex[I].Id > 0 then
      begin
         UnloadTexture(FTex[I]);
         FTex[I].Id := 0;
      end;
      if FTexBG[I].Id > 0 then
      begin
         UnloadTexture(FTexBG[I]);
         FTexBG[I].Id := 0;
      end;
   end;
end;

{ ── Chunk rendering ──────────────────────────────────────────────────────── }

procedure TChunkRenderSystem.RenderChunk(AChunk: TWorldChunk; AIsFG: boolean);
const
   DECOR_TINT: TColor = (R: 255; G: 255; B: 255; A: 220);
var
   LX, LY: Integer;
   TileType, FGTile: Integer;
   WX, WY: Single;
   BaseWX, BaseWY: Single;
   Src, Dst: TRectangle;
   Tint: TColor;
   Light: TRGBLight;
   UseLighting: boolean;
   DimFactor: Single;
   DecorMinBright: byte;
   TWX, TWY: Integer;   { world-tile coordinates of current cell }
   SheetRow: shortint;
   Variation: Integer;
   IsSoil: boolean;
   Tex: TTexture2D;
begin
   BaseWX := AChunk.CX * CHUNK_PIXEL_W;
   BaseWY := AChunk.CY * CHUNK_PIXEL_H;
   UseLighting := Assigned(FLightMap) and FLightMap.Settings.Enabled;

   DimFactor := 0.55;
   if UseLighting then
      DimFactor := FLightMap.Settings.BackgroundDimFactor;

   for LY := 0 to CHUNK_TILES_H - 1 do
      for LX := 0 to CHUNK_TILES_W - 1 do
      begin
         { ── Select the tile type to render ─────────────────────────────── }
         if AIsFG then
         begin
            TileType := AChunk.GetFG(LX, LY);
            if TileType = TILE_AIR then
               Continue;
         end
         else
         begin
            { Skip background when a solid foreground block covers this cell.
              Decoration tiles (>= TILE_SHRUB) are semi-transparent; we must still render the wall behind them so their edges don't cut into the sky. }
            FGTile := AChunk.GetFG(LX, LY);
            if (FGTile <> TILE_AIR) and (FGTile < TILE_SHRUB) then
               Continue;
            TileType := AChunk.GetBG(LX, LY);
            if TileType = TILE_AIR then
               Continue;
         end;

         { ── World-tile coordinates (needed for both hash and lighting) ─── }
         TWX := TChunkManager.ChunkToTileX(AChunk.CX) + LX;
         TWY := TChunkManager.ChunkToTileY(AChunk.CY) + LY;

         { ── Destination rectangle (world pixels) ─────────────────────── }
         WX := BaseWX + LX * TILE_SIZE;
         WY := BaseWY + LY * TILE_SIZE;
         Dst := RectangleCreate(WX, WY, TILE_SIZE, TILE_SIZE);

         { ── Lighting tint ────────────────────────────────────────────── }
         if UseLighting then
         begin
            Light := FLightMap.GetLight(TWX, TWY);
            if AIsFG then
            begin
               Tint.R := Light.R;
               Tint.G := Light.G;
               Tint.B := Light.B;
            end
            else
            begin
               Tint.R := byte(Round(Light.R * DimFactor));
               Tint.G := byte(Round(Light.G * DimFactor));
               Tint.B := byte(Round(Light.B * DimFactor));
            end;
            if TileType >= TILE_SHRUB then
            begin
               Tint.A := DECOR_TINT.A;
               DecorMinBright := FLightMap.Settings.AmbientLight * 8;
               if Tint.R < DecorMinBright then
                  Tint.R := DecorMinBright;
               if Tint.G < DecorMinBright then
                  Tint.G := DecorMinBright;
               if Tint.B < DecorMinBright then
                  Tint.B := DecorMinBright;
            end
            else
               Tint.A := 255;
         end
         else
         begin
            if TileType >= TILE_SHRUB then
               Tint := DECOR_TINT
            else
               Tint := WHITE;
         end;

         { ── Render ───────────────────────────────────────────────────── }
         SheetRow := SOIL_SHEET_ROW[TileType];
         IsSoil := SheetRow >= 0;

         if IsSoil then
         begin
            { ── Spritesheet path for solid terrain tiles ──────────────── }
            if FSoilSheet.Id = 0 then
               Continue;  { sheet not loaded — skip }

            Variation := TileVariation(TWX, TWY);

            Src := RectangleCreate(Variation * SOIL_SHEET_TILE, SheetRow * SOIL_SHEET_TILE, SOIL_SHEET_TILE, SOIL_SHEET_TILE);

            { Background soil tiles get the same spritesheet but with a darker tint, matching the 45% dim factor of the old procedural background textures. }
            if not AIsFG then
            begin
               Tint.R := byte(Round(Tint.R * SOIL_BG_DIM));
               Tint.G := byte(Round(Tint.G * SOIL_BG_DIM));
               Tint.B := byte(Round(Tint.B * SOIL_BG_DIM));
            end;

            DrawTexturePro(FSoilSheet, Src, Dst, Vector2Create(0, 0), 0, Tint);
         end
         else
         begin
            { ── Procedural-texture path for decoration tiles ──────────── }
            if AIsFG then
               Tex := FTex[TileType]
            else
               Tex := FTexBG[TileType];
            if Tex.Id = 0 then
               Continue;

            Src := RectangleCreate(0, 0, TILE_SIZE, TILE_SIZE);
            DrawTexturePro(Tex, Src, Dst, Vector2Create(0, 0), 0, Tint);
         end;
      end;
end;

{ ── System lifecycle ─────────────────────────────────────────────────────── }

constructor TChunkRenderSystem.Create(AWorld: TWorldBase; AManager: TChunkManager; AScrW, AScrH: Integer);
begin
   inherited Create(AWorld);
   FManager := AManager;
   FLightMap := nil;
   FScreenW := AScrW;
   FScreenH := AScrH;
   Priority := 5;
   Name := 'ChunkRenderSystem';
   RenderLayer := rlWorld;
   FSoilSheet.Id := 0;
   FillChar(FTex, SizeOf(FTex), 0);
   FillChar(FTexBG, SizeOf(FTexBG), 0);
end;

destructor TChunkRenderSystem.Destroy;
begin
   inherited;
end;

procedure TChunkRenderSystem.Init;
var
   W: TWorld;
begin
   inherited;
   W := (World as TWorld);
   FCamSys := TCameraSystem(W.GetSystem(TCameraSystem));

   { Load the soil spritesheet first so it is available the moment the first
     chunk is rendered.  If the file is missing, FSoilSheet.Id stays 0 and
     soil tiles are silently skipped (the world appears cave-only until the
     asset is placed correctly). }
   FSoilSheet := LoadTexture(SOIL_SHEET_PATH);

   { Enable bilinear filtering so the 16×16 source tiles scale cleanly to
     the 8×8 world-space destination rectangles. }
   if FSoilSheet.Id > 0 then
      SetTextureFilter(FSoilSheet, TEXTURE_FILTER_ANISOTROPIC_16X);

   { Generate procedural textures for every decoration tile. }
   GenDecorTextures;
end;

procedure TChunkRenderSystem.Render;
var
   Cam: TCamera2D;
   TL, BR: TVector2;
   CX0, CY0: Integer;
   CX1, CY1: Integer;
   N, I: Integer;
begin
   if not Assigned(FManager) then
      Exit;
   if not Assigned(FCamSys) then
      Exit;

   Cam := FCamSys.GetRaylibCamera;
   TL := GetScreenToWorld2D(Vector2Create(0, 0), Cam);
   BR := GetScreenToWorld2D(Vector2Create(FScreenW, FScreenH), Cam);

   CX0 := TChunkManager.TileToChunkX(Trunc(TL.X / TILE_SIZE) - 1);
   CY0 := TChunkManager.TileToChunkY(Trunc(TL.Y / TILE_SIZE) - 1);
   CX1 := TChunkManager.TileToChunkX(Trunc(BR.X / TILE_SIZE) + 1);
   CY1 := TChunkManager.TileToChunkY(Trunc(BR.Y / TILE_SIZE) + 1);
   if CY0 < WORLD_MIN_CY then
      CY0 := WORLD_MIN_CY;
   if CY1 > WORLD_MAX_CY then
      CY1 := WORLD_MAX_CY;

   N := FManager.GetLoadedInRange(CX0, CY0, CX1, CY1, FVisible, MAX_VISIBLE_CHUNKS);

   { Background pass }
   for I := 0 to N - 1 do
      RenderChunk(FVisible[I], False);
   { Foreground pass }
   for I := 0 to N - 1 do
      RenderChunk(FVisible[I], True);
end;

procedure TChunkRenderSystem.Shutdown;
begin
   FreeAllTextures;
   inherited;
end;

end.
