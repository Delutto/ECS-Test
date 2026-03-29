unit Terraria.Systems.MapRender;

{$mode objfpc}{$H+}

{ TMapRenderSystem — renders the procedural Terraria map.

  TWO-PASS RENDERING  (both inside BeginMode2D, RenderLayer = rlWorld)
  ─────────────────
  Pass 1 – Background (wall) tiles drawn at 40% brightness.
            Only drawn where the foreground tile is AIR.
  Pass 2 – Foreground (solid) tiles at full brightness.

  FRUSTUM CULLING
  ───────────────
  Uses GetScreenToWorld2D to convert screen corners to world-space coords,
  then converts those to tile indices to iterate only visible tiles.
  This makes rendering efficient even at large map sizes.

  CPU-GENERATED TILE TEXTURES
  ────────────────────────────
  One 8×8 texture per tile type is generated in Init (GL context already
  available at that stage).  Each texture uses characteristic colours and a
  small rectangle pattern to give a distinct visual identity.

  The system holds a direct reference to the TGameMap, set by the scene
  before World.Init is called. }

interface

uses
   SysUtils, Math, raylib,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Systems.Camera,
   Terraria.Common,
   Terraria.Map;

type
   TMapRenderSystem = class(TSystem2D)
   private
      FMap: TGameMap;              { not owned }
      FCamSys: TCameraSystem;      { resolved in Init }
      FScreenW: Integer;
      FScreenH: Integer;
      FTex: array[0..TILE_COUNT - 1] of TTexture2D;     { foreground }
      FTexBG: array[0..TILE_COUNT - 1] of TTexture2D;   { background (darker) }

      procedure GenTileTextures;
      procedure FreeTileTextures;

      { Draw a single pass }
      procedure DrawPass(AIsForeground: boolean; TileX0, TileY0, TileX1, TileY1: Integer);
   public
      constructor Create(AWorld: TWorldBase; AMap: TGameMap; AScrW, AScrH: Integer); reintroduce;
      destructor Destroy; override;

      procedure Init; override;
      procedure Render; override;
      procedure Shutdown; override;
   end;

implementation

procedure MakeTileImage(var Img: TImage; BaseR, BaseG, BaseB: byte; const Details: array of TRect4);
var
   I: Integer;
begin
   Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(BaseR, BaseG, BaseB, 255));
   { top highlight }
   ImageDrawRectangle(@Img, 0, 0, TILE_SIZE, 1, ColorCreate(Min(255, BaseR + 24), Min(255, BaseG + 24), Min(255, BaseB + 24), 255));
   { bottom shadow }
   ImageDrawRectangle(@Img, 0, TILE_SIZE - 1, TILE_SIZE, 1, ColorCreate(Max(0, BaseR - 20), Max(0, BaseG - 20), Max(0, BaseB - 20), 255));
   { left highlight }
   ImageDrawRectangle(@Img, 0, 0, 1, TILE_SIZE, ColorCreate(Min(255, BaseR + 16), Min(255, BaseG + 16), Min(255, BaseB + 16), 255));
   { detail rectangles }
   for I := 0 to High(Details) do
      ImageDrawRectangle(@Img, Details[I].X, Details[I].Y, Details[I].W, Details[I].H, ColorCreate(Details[I].R, Details[I].G, Details[I].B, 255));
end;

function DarkenColor(C: TColor; Factor: Single): TColor;
begin
   Result := ColorCreate(Round(C.R * Factor), Round(C.G * Factor), Round(C.B * Factor), C.A);
end;

{ ── Texture generation ──────────────────────────────────────────────────── }

procedure TMapRenderSystem.GenTileTextures;
var
   Img: TImage;
   D: array[0..3] of TRect4;
   T: TTexture2D;
   I: Integer;

   procedure Make(Idx: Integer; BaseR, BaseG, BaseB: byte; const Det: array of TRect4);
   var
      J: Integer;
      C: TColor;
   begin
      for J := 0 to High(Det) do
         D[J] := Det[J];

      MakeTileImage(Img, BaseR, BaseG, BaseB, Det);
      FTex[Idx] := LoadTextureFromImage(Img);
      { Darker version for background walls }
      for J := 0 to TILE_SIZE - 1 do
      begin
         { Re-tint each row of the image to ~45% brightness }
      end;
      { Simpler: just create a new darker version }
      UnloadImage(Img);
      C := ColorCreate(Round(BaseR * 0.45), Round(BaseG * 0.45), Round(BaseB * 0.45), 255);
      Img := GenImageColor(TILE_SIZE, TILE_SIZE, C);
      ImageDrawRectangle(@Img, 0, 0, 1, TILE_SIZE, ColorCreate(Min(255, Round(BaseR * 0.50)), Min(255, Round(BaseG * 0.50)), Min(255, Round(BaseB * 0.50)), 255));
      { small detail darker }
      for J := 0 to High(Det) do
      begin
         D[J] := Det[J];
         D[J].R := Round(Det[J].R * 0.45);
         D[J].G := Round(Det[J].G * 0.45);
         D[J].B := Round(Det[J].B * 0.45);
         ImageDrawRectangle(@Img, D[J].X, D[J].Y, D[J].W, D[J].H,
            ColorCreate(D[J].R, D[J].G, D[J].B, 255));
      end;
      FTexBG[Idx] := LoadTextureFromImage(Img);
      UnloadImage(Img);
   end;

begin
   { TILE_AIR (0) – transparent: never drawn, leave default zero texture }

   { TILE_DIRT (1) – warm brown }
   Make(TILE_DIRT, 128, 88, 52, TILE_DIRT_RGB);

   { TILE_GRASS (2) – green top strip + dirt body }
   Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(128, 88, 52, 255));
   { green top 2 rows }
   ImageDrawRectangle(@Img, 0, 0, TILE_SIZE, 2, ColorCreate(56, 140, 36, 255));
   ImageDrawRectangle(@Img, 0, 0, TILE_SIZE, 1, ColorCreate(72, 164, 48, 255));
   { grass tufts }
   ImageDrawRectangle(@Img, 1, 0, 1, 1, ColorCreate(48, 160, 32, 255));
   ImageDrawRectangle(@Img, 4, 0, 1, 1, ColorCreate(80, 172, 56, 255));
   ImageDrawRectangle(@Img, 6, 0, 1, 1, ColorCreate(52, 156, 36, 255));
   { dirt detail }
   ImageDrawRectangle(@Img, 2, 3, 3, 2, ColorCreate(142, 100, 62, 255));
   ImageDrawRectangle(@Img, 5, 5, 3, 2, ColorCreate(112, 76, 44, 255));
   FTex[TILE_GRASS] := LoadTextureFromImage(Img);
   UnloadImage(Img);
   { BG wall for grass: just dirt-coloured wall }
   Img := GenImageColor(TILE_SIZE, TILE_SIZE, ColorCreate(58, 40, 24, 255));
   ImageDrawRectangle(@Img, 0, 0, 1, TILE_SIZE, ColorCreate(65, 46, 28, 255));
   FTexBG[TILE_GRASS] := LoadTextureFromImage(Img);
   UnloadImage(Img);

   { TILE_STONE (3) – medium grey }
   Make(TILE_STONE, 118, 118, 118, TILE_STONE_RGB);

   { TILE_SAND (4) – warm tan }
   Make(TILE_SAND, 196, 174, 112, TILE_SAND_RGB);

   { TILE_SANDSTONE (5) – darker layered tan }
   Make(TILE_SANDSTONE, 168, 142, 88, TILE_SANDSTONE_RGB);

   { TILE_GRANITE (6) – dark blue-grey }
   Make(TILE_GRANITE, 82, 78, 96, TILE_GRANITE_RGB);

   { TILE_MARBLE (7) – white-grey with dark veins }
   Make(TILE_MARBLE, 214, 210, 220, TILE_MARBLE_RGB);

   { TILE_CLAY (8) – reddish-brown }
   Make(TILE_CLAY, 154, 84, 62, TILE_CLAY_RGB);

   { TILE_GRAVEL (9) – mixed grey pebbles }
   Make(TILE_GRAVEL, 112, 108, 104, TILE_GRAVEL_RGB);

   { TILE_BEDROCK (10) – very dark, almost black }
   Make(TILE_BEDROCK, 28, 26, 32, TILE_BEDROCK_RGB);
end;

procedure TMapRenderSystem.FreeTileTextures;
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

{ ── Drawing pass ────────────────────────────────────────────────────────── }

procedure TMapRenderSystem.DrawPass(AIsForeground: boolean; TileX0, TileY0, TileX1, TileY1: Integer);
var
   X, Y, TileType: Integer;
   WX, WY: Single;
   Tex: TTexture2D;
   Src, Dst: TRectangle;
begin
   Src := RectangleCreate(0, 0, TILE_SIZE, TILE_SIZE);
   for Y := TileY0 to TileY1 do
      for X := TileX0 to TileX1 do
      begin
         if AIsForeground then
         begin
            TileType := FMap.GetFG(X, Y);
            if TileType = TILE_AIR then
               Continue;
            Tex := FTex[TileType];
         end
         else
         begin
            { Background only where foreground is air }
            if FMap.GetFG(X, Y) <> TILE_AIR then
               Continue;
            TileType := FMap.GetBG(X, Y);
            if TileType = TILE_AIR then
               Continue;
            Tex := FTexBG[TileType];
         end;

         if Tex.Id = 0 then
            Continue;

         WX := X * TILE_SIZE;
         WY := Y * TILE_SIZE;
         Dst := RectangleCreate(WX, WY, TILE_SIZE, TILE_SIZE);
         DrawTexturePro(Tex, Src, Dst, Vector2Create(0, 0), 0, WHITE);
      end;
end;

{ ── System lifecycle ────────────────────────────────────────────────────── }

constructor TMapRenderSystem.Create(AWorld: TWorldBase; AMap: TGameMap; AScrW, AScrH: Integer);
begin
   inherited Create(AWorld);
   FMap := AMap;
   FScreenW := AScrW;
   FScreenH := AScrH;
   Priority := 5;
   Name := 'MapRenderSystem';
   RenderLayer := rlWorld;
end;

destructor TMapRenderSystem.Destroy;
begin
   inherited Destroy;
end;

procedure TMapRenderSystem.Init;
var
   W: TWorld;
begin
   inherited;

   W := (World as TWorld);
   { Resolve camera system reference }
   FCamSys := TCameraSystem(W.GetSystem(TCameraSystem));
   { Build tile textures (GL context is available at Init time) }
   GenTileTextures;
end;

procedure TMapRenderSystem.Render;
var
   Cam: TCamera2D;
   TL, BR: TVector2;
   TX0, TY0, TX1, TY1: Integer;
begin
   if not Assigned(FMap) then
      Exit;
   if not Assigned(FCamSys) then
      Exit;

   { ── Compute visible tile range via camera frustum ── }
   Cam := FCamSys.GetRaylibCamera;
   TL := GetScreenToWorld2D(Vector2Create(0, 0), Cam);
   BR := GetScreenToWorld2D(Vector2Create(FScreenW, FScreenH), Cam);

   TX0 := Max(0, Trunc(TL.X / TILE_SIZE) - 1);
   TY0 := Max(0, Trunc(TL.Y / TILE_SIZE) - 1);
   TX1 := Min(MAP_WIDTH - 1, Trunc(BR.X / TILE_SIZE) + 1);
   TY1 := Min(MAP_HEIGHT - 1, Trunc(BR.Y / TILE_SIZE) + 1);

   { ── Pass 1: background walls (dimmer) ── }
   DrawPass(False, TX0, TY0, TX1, TY1);

   { ── Pass 2: foreground solid tiles ── }
   DrawPass(True, TX0, TY0, TX1, TY1);
end;

procedure TMapRenderSystem.Shutdown;
begin
   FreeTileTextures;
   inherited;
end;

end.
