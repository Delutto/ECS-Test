unit Terraria.Systems.ChunkRender;
{$mode objfpc}{$H+}
interface

uses
   SysUtils, Math, raylib, P2D.Core.System, P2D.Core.World, P2D.Systems.Camera,
   Terraria.Common, Terraria.WorldChunk, Terraria.ChunkManager, Terraria.Lighting,
   Terraria.Liquid, Terraria.LiquidSim, Terraria.LiquidRender;

const
   MAX_VISIBLE_CHUNKS = 512;

type
   TChunkRenderSystem = class(TSystem2D)
   private
      FManager: TChunkManager;
      FLightMap: TLightMap;
      FCamSys: TCameraSystem;
      FScreenW, FScreenH: Integer;
      FSoilSheet: TTexture2D;
      FTex: array[0..TILE_COUNT - 1] of TTexture2D;
      FTexBG: array[0..TILE_COUNT - 1] of TTexture2D;
      FVisible: array[0..MAX_VISIBLE_CHUNKS - 1] of TWorldChunk;
      FLiquidRenderer: TLiquidRenderer;
      FSim: TLiquidSimulator;
      FLiquidParams: PLiquidParams;
      function TileVariation(WTX, WTY: Integer): Integer; inline;
      procedure GenDecorTextures;
      procedure FreeAllTextures;
      procedure RenderChunk(AChunk: TWorldChunk; AIsFG: boolean);
   public
      constructor Create(AWorld: TWorldBase; AManager: TChunkManager; AScrW, AScrH: Integer; ALiquidParams: PLiquidParams = nil; ASim: TLiquidSimulator = nil); reintroduce;
      destructor Destroy; override;
      procedure Init; override;
      procedure Render; override;
      procedure Shutdown; override;
      property Manager: TChunkManager read FManager write FManager;
      property LightMap: TLightMap read FLightMap write FLightMap;
      property LiquidParams: PLiquidParams read FLiquidParams write FLiquidParams;
      property Sim: TLiquidSimulator read FSim write FSim;
   end;

implementation

function TChunkRenderSystem.TileVariation(WTX, WTY: Integer): Integer;
var
   H: cardinal;
begin
   H := cardinal(WTX) * 1664525 xor cardinal(WTY) * 22695477;
   H := H xor (H shr 16);
   Result := Integer(H and 3);
end;

procedure MakeDecorPair(var ATex, ATex_BG: TTexture2D; BR, BG, BB: byte; const Det: array of TRect4; Alpha: byte = 255);
var
   Img: TImage;
   J: Integer;
begin
   Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(0, 0, 0, 0));
   if Alpha = 255 then
      ImageDrawRectangle(@Img, 1, 0, TILE_SIZE - 2, TILE_SIZE, ColorCreate(BR, BG, BB, 255));
   for J := 0 to High(Det) do
      ImageDrawRectangle(@Img, Det[J].X, Det[J].Y, Det[J].W, Det[J].H, ColorCreate(Det[J].R, Det[J].G, Det[J].B, Alpha));
   ATex := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(0, 0, 0, 0));
   ATex_BG := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

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
   MakeDecorPair(FTex[TILE_SHRUB], FTexBG[TILE_SHRUB], 0, 0, 0, TILE_SHRUB_RGB, 200);
   MakeDecorPair(FTex[TILE_TREE_TRUNK], FTexBG[TILE_TREE_TRUNK], 110, 72, 40, TILE_TREE_TRUNK_RGB);
   MakeDecorPair(FTex[TILE_TREE_LEAF], FTexBG[TILE_TREE_LEAF], 40, 130, 36, TILE_TREE_LEAF_RGB, 200);
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
   MakeDecorPair(FTex[TILE_ROOT], FTexBG[TILE_ROOT], 0, 0, 0, TILE_ROOT_RGB, 255);
   MakeDecorPair(FTex[TILE_VINE], FTexBG[TILE_VINE], 0, 0, 0, TILE_VINE_RGB, 200);
   MakeDecorPair(FTex[TILE_STALACTITE], FTexBG[TILE_STALACTITE], 0, 0, 0, TILE_STALACTITE_RGB, 200);
   MakeDecorPair(FTex[TILE_STALAGMITE], FTexBG[TILE_STALAGMITE], 0, 0, 0, TILE_STALAGMITE_RGB, 200);
   MakeDecorPair(FTex[TILE_MUSHROOM], FTexBG[TILE_MUSHROOM], 0, 0, 0, TILE_MUSHROOM_RGB, 240);
   MakeDecorPair(FTex[TILE_MOSS], FTexBG[TILE_MOSS], 0, 0, 0, TILE_MOSS_RGB, 180);
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
   if FSoilSheet.Id > 0 then
   begin
      UnloadTexture(FSoilSheet);
      FSoilSheet.Id := 0;
   end;
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

procedure TChunkRenderSystem.RenderChunk(AChunk: TWorldChunk; AIsFG: boolean);
const
   DECOR_TINT: TColor = (R: 255; G: 255; B: 255; A: 220);
var
   LX, LY, TileType, FGTile: Integer;
   WX, WY, BaseWX, BaseWY: Single;
   Src, Dst: TRectangle;
   Tint: TColor;
   Light: TRGBLight;
   UseLighting: boolean;
   DimFactor: Single;
   DecorMinBright: byte;
   TWX, TWY, SheetRow, Variation: Integer;
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
         if AIsFG then
         begin
            TileType := AChunk.GetFG(LX, LY);
            if TileType = TILE_AIR then
               Continue;
            if TileType >= TILE_LIQUID_BOUNDARY then
               Continue;
         end
         else
         begin
            FGTile := AChunk.GetFG(LX, LY);
            if (FGTile <> TILE_AIR) and (FGTile < TILE_SHRUB) and (FGTile < TILE_LIQUID_BOUNDARY) then
               Continue;
            TileType := AChunk.GetBG(LX, LY);
            if TileType = TILE_AIR then
               Continue;
            if TileType >= TILE_LIQUID_BOUNDARY then
               Continue;
         end;
         TWX := TChunkManager.ChunkToTileX(AChunk.CX) + LX;
         TWY := TChunkManager.ChunkToTileY(AChunk.CY) + LY;
         WX := BaseWX + LX * TILE_SIZE;
         WY := BaseWY + LY * TILE_SIZE;
         Dst := RectangleCreate(WX, WY, TILE_SIZE, TILE_SIZE);
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
         SheetRow := SOIL_SHEET_ROW[TileType];
         IsSoil := SheetRow >= 0;
         if IsSoil then
         begin
            if FSoilSheet.Id = 0 then
               Continue;
            Variation := TileVariation(TWX, TWY);
            Src := RectangleCreate(Variation * SOIL_SHEET_TILE, SheetRow * SOIL_SHEET_TILE, SOIL_SHEET_TILE, SOIL_SHEET_TILE);
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

constructor TChunkRenderSystem.Create(AWorld: TWorldBase; AManager: TChunkManager; AScrW, AScrH: Integer; ALiquidParams: PLiquidParams; ASim: TLiquidSimulator);
begin
   inherited Create(AWorld);
   FManager := AManager;
   FLightMap := nil;
   FLiquidParams := ALiquidParams;
   FSim := ASim;
   FLiquidRenderer := nil;
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
   FSoilSheet := LoadTexture(SOIL_SHEET_PATH);
   if FSoilSheet.Id > 0 then
      SetTextureFilter(FSoilSheet, TEXTURE_FILTER_ANISOTROPIC_16X);
   GenDecorTextures;
   FreeAndNil(FLiquidRenderer);
   if Assigned(FLiquidParams) then
      FLiquidRenderer := TLiquidRenderer.Create(FLiquidParams, FLightMap, FSim);
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
   if Assigned(FLiquidRenderer) then
   begin
      FLiquidRenderer.LightMap := FLightMap;
      FLiquidRenderer.Sim := FSim;
      for I := 0 to N - 1 do
         FLiquidRenderer.RenderChunk(FVisible[I]);
   end;
   for I := 0 to N - 1 do
      RenderChunk(FVisible[I], True);
end;

procedure TChunkRenderSystem.Shutdown;
begin
   FreeAndNil(FLiquidRenderer);
   FreeAllTextures;
   inherited;
end;

end.
