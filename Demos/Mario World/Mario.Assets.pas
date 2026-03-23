unit Mario.Assets;

{$mode objfpc}{$H+}

{ Geração procedural dos assets visuais da demo Mario }

interface

uses
   raylib, P2D.Core.Types;

procedure GenerateAssets;
procedure UnloadAssets;

var
   TexEnemy      : TTexture2D;   { goomba: 2 frames × 16×16                        }
   TexTiles      : TTexture2D;   { tileset: 4 tiles (ground, plank, ?-block, coin) }
   TexBackground : TTexture2D;   { sky + hills + clouds: 512×240 (far layer)       }
   TexBackground2: TTexture2D;   { closer hills + bushes: 256×120 (near layer)     }

implementation

{ ── Helpers ─────────────────────────────────────────────────────────────── }
procedure FillRect(img: PImage; x, y, w, h: Integer; c: TColor);
var
   IX, IY: Integer;
begin
   for IY := y to y + h - 1 do
      for IX := x to x + w - 1 do
         ImageDrawPixel(img, IX, IY, ColorCreate(c.R, c.G, c.B, c.A));
end;

procedure DrawCircleImg(img: PImage; cx, cy, r: Integer; c: TColor);
var
   IX, IY: Integer;
begin
   for IY := cy - r to cy + r do
      for IX := cx - r to cx + r do
         if (Sqr(IX - cx) + Sqr(IY - cy)) <= Sqr(r) then
            ImageDrawPixel(img, IX, IY, ColorCreate(c.R, c.G, c.B, c.A));
end;

{ ── Goomba (32×16, 2 frames 16×16) ──────────────────────────────────────── }
procedure MakeEnemy;
var
   img: TImage;
   BX : Integer;
begin
   img := GenImageColor(32, 16, ColorCreate(0,0,0,0));
   for BX := 0 to 1 do
   begin
      FillRect(@img, BX*16+1,  4, 14, 11, ColorCreate(150, 75,   0, 255));
      FillRect(@img, BX*16+3,  5,  4,  4, ColorCreate(255,255, 255, 255));
      FillRect(@img, BX*16+9,  5,  4,  4, ColorCreate(255,255, 255, 255));
      FillRect(@img, BX*16+4,  6,  2,  2, ColorCreate( 10, 10,  10, 255));
      FillRect(@img, BX*16+10, 6,  2,  2, ColorCreate( 10, 10,  10, 255));
      if BX = 0 then
      begin
         FillRect(@img, BX*16+2,  13, 4, 3, ColorCreate(80,40,0, 255));
         FillRect(@img, BX*16+10, 13, 4, 3, ColorCreate(80,40,0, 255));
      end
      else
      begin
         FillRect(@img, BX*16+0,  13, 5, 3, ColorCreate(80,40,0, 255));
         FillRect(@img, BX*16+11, 13, 5, 3, ColorCreate(80,40,0, 255));
      end;
      FillRect(@img, BX*16+3, 4, 4, 1, ColorCreate(60,30,0, 255));
      FillRect(@img, BX*16+9, 4, 4, 1, ColorCreate(60,30,0, 255));
   end;
   TexEnemy := LoadTextureFromImage(img);
   UnloadImage(img);
end;

{ ── Tileset (64×16, 4 tiles of 16×16) ───────────────────────────────────── }
procedure MakeTiles;
var
   Img: TImage;
   X  : Integer;
begin
   Img := GenImageColor(64, 16, ColorCreate(0,0,0,0));

   { Tile 0 — solid ground }
   FillRect(@Img,  0, 0, 16, 16, ColorCreate(139,101, 62, 255));
   FillRect(@Img,  0, 0, 16,  4, ColorCreate( 80,160, 50, 255));
   for X := 0 to 15 do ImageDrawPixel(@Img, X, 4, ColorCreate(60,130,40,255));

   { Tile 1 — semi-solid plank }
   FillRect(@Img, 16,  0, 16, 16, ColorCreate(210,170,100, 255));
   FillRect(@Img, 16,  0, 16,  3, ColorCreate(240,200,120, 255));
   FillRect(@Img, 16,  3, 16,  1, ColorCreate(160,120, 60, 255));
   ImageDrawPixel(@Img, 20, 4, ColorCreate(160,120,60,255));
   ImageDrawPixel(@Img, 20, 5, ColorCreate(160,120,60,255));
   ImageDrawPixel(@Img, 24, 4, ColorCreate(160,120,60,255));
   ImageDrawPixel(@Img, 24, 5, ColorCreate(160,120,60,255));
   ImageDrawPixel(@Img, 28, 4, ColorCreate(160,120,60,255));
   ImageDrawPixel(@Img, 28, 5, ColorCreate(160,120,60,255));

   { Tile 2 — ? block }
   FillRect(@Img, 32,  0, 16, 16, ColorCreate(220,170,  0, 255));
   FillRect(@Img, 32,  0, 16,  1, ColorCreate(255,210, 80, 255));
   FillRect(@Img, 32,  0,  1, 16, ColorCreate(255,210, 80, 255));
   FillRect(@Img, 47,  0,  1, 16, ColorCreate(160,110,  0, 255));
   FillRect(@Img, 32, 15, 16,  1, ColorCreate(160,110,  0, 255));
   FillRect(@Img, 37,  3,  6,  2, ColorCreate(255,255,255, 255));
   FillRect(@Img, 41,  5,  2,  3, ColorCreate(255,255,255, 255));
   FillRect(@Img, 38,  8,  4,  2, ColorCreate(255,255,255, 255));
   FillRect(@Img, 38, 11,  4,  2, ColorCreate(255,255,255, 255));

   { Tile 3 — coin tile }
   DrawCircleImg(@Img, 56, 8, 6, ColorCreate(255,200,  0, 255));
   DrawCircleImg(@Img, 56, 8, 4, ColorCreate(255,230, 80, 255));

   TexTiles := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

{ ── Background layer 0 — sky + distant hills + clouds (512×240) ──────────
  Scroll factor ≈ 0.10 (barely moves — the far horizon).                  }
procedure MakeBackground;
var
   img       : TImage;
   IX, IY    : Integer;
begin
   img := GenImageColor(512, 240, ColorCreate(92,148,252,255));

   { Ground base strip }
   FillRect(@img, 0, 210, 512, 30, ColorCreate( 80,160, 50, 255));
   FillRect(@img, 0, 218, 512, 22, ColorCreate(140,100, 60, 255));

   { Far hills (large, light green) }
   for IX := 0 to 511 do
      for IY := 150 to 209 do
      begin
         if Sqr(IX -  80) + Sqr(IY - 210) < Sqr(80) then
            ImageDrawPixel(@img, IX, IY, ColorCreate( 50,140,30,255));
         if Sqr(IX - 320) + Sqr(IY - 210) < Sqr(110) then
            ImageDrawPixel(@img, IX, IY, ColorCreate( 50,140,30,255));
         if Sqr(IX - 460) + Sqr(IY - 210) < Sqr(65) then
            ImageDrawPixel(@img, IX, IY, ColorCreate( 50,140,30,255));
      end;

   { Clouds }
   DrawCircleImg(@img, 100, 60, 20, WHITE);
   DrawCircleImg(@img, 125, 55, 25, WHITE);
   DrawCircleImg(@img, 150, 60, 20, WHITE);
   DrawCircleImg(@img, 350, 40, 18, WHITE);
   DrawCircleImg(@img, 372, 35, 22, WHITE);
   DrawCircleImg(@img, 394, 40, 18, WHITE);

   TexBackground := LoadTextureFromImage(img);
   UnloadImage(img);
end;

{ ── Background layer 1 — closer hills + bushes (256×120) ─────────────────
  Scroll factor ≈ 0.35 (mid-distance parallax layer).
  Drawn tiled horizontally; anchored just above the ground strip.        }
procedure MakeBackground2;
var
   img    : TImage;
   IX, IY : Integer;
begin
   img := GenImageColor(256, 120, ColorCreate(0,0,0,0));  { transparent bg }

   { Rounded hills (darker green to stand out against sky) }
   for IX := 0 to 255 do
      for IY := 50 to 119 do
      begin
         if Sqr(IX -  50) + Sqr(IY - 120) < Sqr(55) then
            ImageDrawPixel(@img, IX, IY, ColorCreate(40,120,20,255));
         if Sqr(IX - 180) + Sqr(IY - 120) < Sqr(70) then
            ImageDrawPixel(@img, IX, IY, ColorCreate(40,120,20,255));
      end;

   { Simple bushes: two overlapping circles }
   DrawCircleImg(@img, 115, 110, 10, ColorCreate(30,110,10,255));
   DrawCircleImg(@img, 128, 107, 13, ColorCreate(30,110,10,255));
   DrawCircleImg(@img, 141, 110, 10, ColorCreate(30,110,10,255));

   DrawCircleImg(@img, 210, 113,  8, ColorCreate(30,110,10,255));
   DrawCircleImg(@img, 222, 110, 11, ColorCreate(30,110,10,255));
   DrawCircleImg(@img, 234, 113,  8, ColorCreate(30,110,10,255));

   TexBackground2 := LoadTextureFromImage(img);
   UnloadImage(img);
end;

{ ── Public API ────────────────────────────────────────────────────────────── }
procedure GenerateAssets;
begin
  MakeEnemy;
  MakeTiles;
  MakeBackground;
  MakeBackground2;
end;

procedure UnloadAssets;
begin
  if TexEnemy.Id > 0 then
     UnloadTexture(TexEnemy);
  if TexTiles.Id > 0 then
     UnloadTexture(TexTiles);
  if TexBackground.Id > 0 then
     UnloadTexture(TexBackground);
  if TexBackground2.Id > 0 then
     UnloadTexture(TexBackground2);
end;

end.
