unit Terraria.Systems.ChunkRender;

{$mode objfpc}{$H+}

{ TChunkRenderSystem — renders loaded chunks with optional BFS lighting.
  When LightMap is assigned, each tile is tinted by its computed RGB light
  value.  Background tiles are additionally dimmed by BackgroundDimFactor. }

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
      FScreenW, FScreenH: Integer;
      FTex: array[0..TILE_COUNT - 1] of TTexture2D;
      FTexBG: array[0..TILE_COUNT - 1] of TTexture2D;
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
      property LightMap: TLightMap read FLightMap write FLightMap;
   end;

implementation

{ ── CPU texture helpers ─────────────────────────────────────────────────── }
procedure MakeTileImg(var Img: TImage; BR, BG, BB: byte; const Det: array of TRect4);
var
   I: Integer;
begin
   Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(BR, BG, BB, 255));
   ImageDrawRectangle(@Img, 0, 0, TILE_SIZE, 1, ColorCreate(Min(255, BR + 24), Min(255, BG + 24), Min(255, BB + 24), 255));
   ImageDrawRectangle(@Img, 0, TILE_SIZE - 1, TILE_SIZE, 1, ColorCreate(Max(0, BR - 20), Max(0, BG - 20), Max(0, BB - 20), 255));
   ImageDrawRectangle(@Img, 0, 0, 1, TILE_SIZE, ColorCreate(Min(255, BR + 16), Min(255, BG + 16), Min(255, BB + 16), 255));
   for I := 0 to High(Det) do
      ImageDrawRectangle(@Img, Det[I].X, Det[I].Y, Det[I].W, Det[I].H, ColorCreate(Det[I].R, Det[I].G, Det[I].B, 255));
end;

procedure TChunkRenderSystem.GenTileTextures;
var
   Img: TImage;
   I: Integer;

   procedure Make(Idx: Integer; BR, BG, BB: byte; const Det: array of TRect4);
   var
      J: Integer;
      D: TRect4;
   begin
      MakeTileImg(Img, BR, BG, BB, Det);
      FTex[Idx] := LoadTextureFromImage(Img);
      UnloadImage(Img);
      Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(Round(BR * 0.45), Round(BG * 0.45), Round(BB * 0.45), 255));
      ImageDrawRectangle(@Img, 0, 0, 1, TILE_SIZE, ColorCreate(Round(BR * 0.50), Round(BG * 0.50), Round(BB * 0.50), 255));
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

   procedure MakeDecor(Idx: Integer; BR, BG, BB: byte; const Det: array of TRect4; Alpha: byte = 255);
   var
      J: Integer;
   begin
      Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(0, 0, 0, 0));
      if Alpha = 255 then
         ImageDrawRectangle(@Img, 1, 0, TILE_SIZE - 2, TILE_SIZE, ColorCreate(BR, BG, BB, 255));
      for J := 0 to High(Det) do
         ImageDrawRectangle(@Img, Det[J].X, Det[J].Y, Det[J].W, Det[J].H, ColorCreate(Det[J].R, Det[J].G, Det[J].B, Alpha));
      FTex[Idx] := LoadTextureFromImage(Img);
      UnloadImage(Img);
      Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(0, 0, 0, 0));
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

   { Grass — custom pixel art }
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

   MakeDecor(TILE_SHRUB, 0, 0, 0, TILE_SHRUB_RGB, 200);

   MakeDecor(TILE_TREE_TRUNK, 110, 72, 40, TILE_TREE_TRUNK_RGB);
   MakeDecor(TILE_TREE_LEAF, 0, 0, 0, TILE_TREE_LEAF_RGB, 200);
   { Overdraw leaf detail }
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
      Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(0, 0, 0, 0));
      UnloadTexture(FTexBG[TILE_TREE_LEAF]);
      FTexBG[TILE_TREE_LEAF] := LoadTextureFromImage(Img);
      UnloadImage(Img);
   end;

   MakeDecor(TILE_CACTUS, 0, 0, 0, TILE_CACTUS_RGB, 200);
   MakeDecor(TILE_CACTUS_TOP, 0, 0, 0, TILE_CACTUS_TOP_RGB, 200);
   MakeDecor(TILE_FERN, 0, 0, 0, TILE_FERN_RGB, 200);
   MakeDecor(TILE_ROOT, 0, 0, 0, TILE_ROOT_RGB, 200);
   MakeDecor(TILE_VINE, 0, 0, 0, TILE_VINE_RGB, 200);
   MakeDecor(TILE_STALACTITE, 0, 0, 0, TILE_STALACTITE_RGB, 200);
   MakeDecor(TILE_STALAGMITE, 0, 0, 0, TILE_STALAGMITE_RGB, 200);
   MakeDecor(TILE_MUSHROOM, 0, 0, 0, TILE_MUSHROOM_RGB, 240);
   MakeDecor(TILE_MOSS, 0, 0, 0, TILE_MOSS_RGB, 180);

   for I := 0 to TILE_COUNT - 1 do
   begin
      if FTex[I].Id = 0 then
      begin
         Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(0, 0, 0, 0));
         FTex[I] := LoadTextureFromImage(Img);
         UnloadImage(Img);
      end;
      if FTexBG[I].Id = 0 then
      begin
         Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(0, 0, 0, 0));
         FTexBG[I] := LoadTextureFromImage(Img);
         UnloadImage(Img);
      end;
   end;
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

{ ── Chunk rendering ─────────────────────────────────────────────────────── }

procedure TChunkRenderSystem.RenderChunk(AChunk: TWorldChunk; AIsFG: boolean);
const
   DECOR_TINT: TColor = (R: 255; G: 255; B: 255; A: 220);
var
   LX, LY, TileType, FGTile: Integer;
   WX, WY: Single;
   Tex: TTexture2D;
   Src, Dst: TRectangle;
   BaseWX, BaseWY: Single;
   Tint: TColor;
   Light: TRGBLight;
   UseLighting: boolean;
   TWX, TWY: Integer;
   DimFactor: Single;
   DecorMinBright: byte;
begin
   Src := RectangleCreate(0, 0, TILE_SIZE, TILE_SIZE);
   BaseWX := AChunk.CX * CHUNK_PIXEL_W;
   BaseWY := AChunk.CY * CHUNK_PIXEL_H;
   UseLighting := Assigned(FLightMap) and FLightMap.Settings.Enabled;
   DimFactor := 0.55;
   if UseLighting then
      DimFactor := FLightMap.Settings.BackgroundDimFactor;

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
            { Draw the BG wall tile unless a solid foreground block is present.
              Decor tiles (TILE_SHRUB+) are semi-transparent; the wall behind
              them must still render so their edges blend with stone/dirt
              instead of the sky-blue background. }
            FGTile := AChunk.GetFG(LX, LY);
            if (FGTile <> TILE_AIR) and (FGTile < TILE_SHRUB) then
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

         { ── Compute tint ── }
         if UseLighting then
         begin
            TWX := TChunkManager.ChunkToTileX(AChunk.CX) + LX;
            TWY := TChunkManager.ChunkToTileY(AChunk.CY) + LY;
            Light := FLightMap.GetLight(TWX, TWY);
            if AIsFG then
            begin
               Tint.R := Light.R;
               Tint.G := Light.G;
               Tint.B := Light.B;
            end
            else
            begin
               { Background tiles are dimmer than foreground }
               Tint.R := byte(Round(Light.R * DimFactor));
               Tint.G := byte(Round(Light.G * DimFactor));
               Tint.B := byte(Round(Light.B * DimFactor));
            end;
            { Decor tiles: set alpha and enforce a minimum brightness so
              underground decor (roots, vines, mushrooms) is always faintly
              visible even at ambient light, instead of nearly black. }
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

         DrawTexturePro(Tex, Src, Dst, Vector2Create(0, 0), 0, Tint);
      end;
end;

{ ── System lifecycle ────────────────────────────────────────────────────── }
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
   CX0, CY0, CX1, CY1, N, I: Integer;
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
   for I := 0 to N - 1 do
      RenderChunk(FVisible[I], False);
   for I := 0 to N - 1 do
      RenderChunk(FVisible[I], True);
end;

procedure TChunkRenderSystem.Shutdown;
begin
   FreeTileTextures;

   inherited;
end;

end.
