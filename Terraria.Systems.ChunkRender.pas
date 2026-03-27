
unit Terraria.Systems.ChunkRender;
{$mode objfpc}{$H+}
{ TChunkRenderSystem — renders visible loaded chunks of the infinite world.

  ALGORITHM
  ─────────
  1. Ask GetScreenToWorld2D for screen corners → world pixel rect.
  2. Convert to chunk coordinate range.
  3. Enumerate loaded chunks within that range via TChunkManager.
  4. For each chunk: two-pass render (BG walls, then FG tiles).
     Tiles are drawn with DrawTexturePro at their world-pixel position.

  Tile textures are the same 8×8 CPU images as before (shared palette
  from Terraria.Common tile RGB constants).

  RenderLayer = rlWorld  → called between BeginMode2D / EndMode2D by
  TWorldScene.Render.

  IMPORTANT: This system does NOT call World.Update / GetMatchingEntities.
  It holds a direct reference to TChunkManager and TCamera2D, bypassing
  the normal ECS path for performance (no component iteration needed). }

interface

uses
   SysUtils, Math, raylib,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Systems.Camera,
   Terraria.Common,
   Terraria.WorldChunk,
   Terraria.ChunkManager;

const
   MAX_VISIBLE_CHUNKS = 512;   { upper bound for the chunk scratch array }

type
   TChunkRenderSystem = class(TSystem2D)
   private
      FManager: TChunkManager;
      FCamSys: TCameraSystem;
      FScreenW: Integer;
      FScreenH: Integer;

      FTex: array[0..TILE_COUNT - 1] of TTexture2D;
      FTexBG: array[0..TILE_COUNT - 1] of TTexture2D;

      { Scratch buffer for chunk enumeration — avoids per-frame heap allocs }
      FVisible: array[0..MAX_VISIBLE_CHUNKS - 1] of TWorldChunk;

      procedure GenTileTextures;
      procedure FreeTileTextures;
      procedure RenderChunk(AChunk: TWorldChunk; AIsFG: boolean);
   public
      constructor Create(AWorld: TWorldBase; AManager: TChunkManager; AScrW, AScrH: Integer); reintroduce;
      destructor Destroy; override;

      procedure Init; override;
      procedure Render; override;
      procedure Shutdown; override;
      property Manager: TChunkManager read FManager write FManager;
   end;

implementation

uses
   Terraria.ChunkGenerator;  { for TILE_* colour arrays via Terraria.Common }

   { ── Texture helpers ───────────────────────────────────────────────────── }

procedure MakeTileImg(var Img: TImage; BR, BG, BB: byte; const Det: array of TRect4);
var
   I: Integer;
begin
   Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(BR, BG, BB, 255));
   ImageDrawRectangle(@Img, 0, 0, TILE_SIZE, 1,
      ColorCreate(Min(255, BR + 24), Min(255, BG + 24), Min(255, BB + 24), 255));
   ImageDrawRectangle(@Img, 0, TILE_SIZE - 1, TILE_SIZE, 1,
      ColorCreate(Max(0, BR - 20), Max(0, BG - 20), Max(0, BB - 20), 255));
   ImageDrawRectangle(@Img, 0, 0, 1, TILE_SIZE,
      ColorCreate(Min(255, BR + 16), Min(255, BG + 16), Min(255, BB + 16), 255));
   for I := 0 to High(Det) do
      ImageDrawRectangle(@Img, Det[I].X, Det[I].Y, Det[I].W, Det[I].H,
         ColorCreate(Det[I].R, Det[I].G, Det[I].B, 255));
end;

procedure TChunkRenderSystem.GenTileTextures;
var
   Img: TImage;
   I: Integer;
   C: TColor;

   procedure Make(Idx: Integer; BR, BG, BB: byte; const Det: array of TRect4);
   var
      J: Integer;
      D: TRect4;
   begin
      MakeTileImg(Img, BR, BG, BB, Det);
      FTex[Idx] := LoadTextureFromImage(Img);
      UnloadImage(Img);
      C := ColorCreate(Round(BR * 0.45), Round(BG * 0.45), Round(BB * 0.45), 255);
      Img := GenImageColor(TILE_SIZE, TILE_SIZE, C);
      ImageDrawRectangle(@Img, 0, 0, 1, TILE_SIZE,
         ColorCreate(Round(BR * 0.50), Round(BG * 0.50), Round(BB * 0.50), 255));
      for J := 0 to High(Det) do
      begin
         D := Det[J];
         D.R := Round(D.R * 0.45);
         D.G := Round(D.G * 0.45);
         D.B := Round(D.B * 0.45);
         ImageDrawRectangle(@Img, D.X, D.Y, D.W, D.H,
            ColorCreate(D.R, D.G, D.B, 255));
      end;
      FTexBG[Idx] := LoadTextureFromImage(Img);
      UnloadImage(Img);
   end;

begin
   Make(TILE_DIRT, 128, 88, 52, TILE_DIRT_RGB);
   Make(TILE_STONE, 118, 118, 118, TILE_STONE_RGB);
   Make(TILE_SAND, 196, 174, 112, TILE_SAND_RGB);
   Make(TILE_SANDSTONE, 168, 142, 88, TILE_SANDSTONE_RGB);
   Make(TILE_GRANITE, 82, 78, 96, TILE_GRANITE_RGB);
   Make(TILE_MARBLE, 214, 210, 220, TILE_MARBLE_RGB);
   Make(TILE_CLAY, 154, 84, 62, TILE_CLAY_RGB);
   Make(TILE_GRAVEL, 112, 108, 104, TILE_GRAVEL_RGB);
   Make(TILE_BEDROCK, 28, 26, 32, TILE_BEDROCK_RGB);

   { TILE_GRASS (2) — special: green top strip + brown body }
   Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(128, 88, 52, 255));
   ImageDrawRectangle(@Img, 0, 0, TILE_SIZE, 2, ColorCreate(56, 140, 36, 255));
   ImageDrawRectangle(@Img, 0, 0, TILE_SIZE, 1, ColorCreate(72, 164, 48, 255));
   ImageDrawRectangle(@Img, 1, 0, 1, 1, ColorCreate(48, 160, 32, 255));
   ImageDrawRectangle(@Img, 4, 0, 1, 1, ColorCreate(80, 172, 56, 255));
   ImageDrawRectangle(@Img, 6, 0, 1, 1, ColorCreate(52, 156, 36, 255));
   ImageDrawRectangle(@Img, 2, 3, 3, 2, ColorCreate(142, 100, 62, 255));
   ImageDrawRectangle(@Img, 5, 5, 3, 2, ColorCreate(112, 76, 44, 255));
   FTex[TILE_GRASS] := LoadTextureFromImage(Img);
   UnloadImage(Img);

   Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(58, 40, 24, 255));
   ImageDrawRectangle(@Img, 0, 0, 1, TILE_SIZE, ColorCreate(65, 46, 28, 255));
   FTexBG[TILE_GRASS] := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TChunkRenderSystem.FreeTileTextures;
var
   I: Integer;
begin
   for I := 0 to TILE_COUNT - 1 do
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

{ ── Chunk rendering ───────────────────────────────────────────────────── }

procedure TChunkRenderSystem.RenderChunk(AChunk: TWorldChunk; AIsFG: boolean);
var
   LX, LY, TileType: Integer;
   WX, WY: Single;
   Tex: TTexture2D;
   Src, Dst: TRectangle;
   BaseWX, BaseWY: Single;
begin
   Src := RectangleCreate(0, 0, TILE_SIZE, TILE_SIZE);
   BaseWX := AChunk.CX * CHUNK_PIXEL_W;
   BaseWY := AChunk.CY * CHUNK_PIXEL_H;

   for LY := 0 to CHUNK_TILES_H - 1 do
      for LX := 0 to CHUNK_TILES_W - 1 do
      begin
         if AIsFG then
         begin
            TileType := AChunk.GetFG(LX, LY);
            if TileType = TILE_AIR then
               Continue;
            Tex := FTex[TileType];
         end
         else
         begin
            { BG only where FG is air }
            if AChunk.GetFG(LX, LY) <> TILE_AIR then
               Continue;
            TileType := AChunk.GetBG(LX, LY);
            if TileType = TILE_AIR then
               Continue;
            Tex := FTexBG[TileType];
         end;

         if Tex.Id = 0 then
            Continue;

         WX := BaseWX + LX * TILE_SIZE;
         WY := BaseWY + LY * TILE_SIZE;
         Dst := RectangleCreate(WX, WY, TILE_SIZE, TILE_SIZE);
         DrawTexturePro(Tex, Src, Dst, Vector2Create(0, 0), 0, WHITE);
      end;
end;

{ ── System lifecycle ──────────────────────────────────────────────────── }

constructor TChunkRenderSystem.Create(AWorld: TWorldBase; AManager: TChunkManager; AScrW, AScrH: Integer);
begin
   inherited Create(AWorld);
   FManager := AManager;
   FScreenW := AScrW;
   FScreenH := AScrH;
   Priority := 5;
   Name := 'ChunkRenderSystem';
   RenderLayer := rlWorld;
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
   GenTileTextures;
end;

procedure TChunkRenderSystem.Render;
var
   Cam: TCamera2D;
   TL, BR: TVector2;
   CX0, CY0, CX1, CY1: Integer;
   N, I: Integer;
begin
   if not Assigned(FManager) then
      Exit;
   if not Assigned(FCamSys) then
      Exit;

   { ── Camera frustum → chunk range ─────────────────────────────────────── }
   Cam := FCamSys.GetRaylibCamera;
   TL := GetScreenToWorld2D(Vector2Create(0, 0), Cam);
   BR := GetScreenToWorld2D(Vector2Create(FScreenW, FScreenH), Cam);

   CX0 := TChunkManager.TileToChunkX(Trunc(TL.X / TILE_SIZE) - 1);
   CY0 := TChunkManager.TileToChunkY(Trunc(TL.Y / TILE_SIZE) - 1);
   CX1 := TChunkManager.TileToChunkX(Trunc(BR.X / TILE_SIZE) + 1);
   CY1 := TChunkManager.TileToChunkY(Trunc(BR.Y / TILE_SIZE) + 1);

   { Clamp Y to world limits }
   if CY0 < WORLD_MIN_CY then
      CY0 := WORLD_MIN_CY;
   if CY1 > WORLD_MAX_CY then
      CY1 := WORLD_MAX_CY;

   { ── Collect visible loaded chunks ────────────────────────────────────── }
   N := FManager.GetLoadedInRange(CX0, CY0, CX1, CY1, FVisible, MAX_VISIBLE_CHUNKS);

   { ── Pass 1: background walls ─────────────────────────────────────────── }
   for I := 0 to N - 1 do
      RenderChunk(FVisible[I], False);

   { ── Pass 2: foreground tiles ─────────────────────────────────────────── }
   for I := 0 to N - 1 do
      RenderChunk(FVisible[I], True);
end;

procedure TChunkRenderSystem.Shutdown;
begin
   FreeTileTextures;
   inherited;
end;

end.
