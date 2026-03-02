unit Mario.ProceduralArt;

{$mode objfpc}{$H+}
{
  Generates all demo assets programmatically using raylib drawing primitives,
  so the demo runs without external image files.
}

interface

uses raylib, P2D.Core.Types;

procedure GenerateAssets;
procedure UnloadAssets;

// Textures accessible by the rest of the demo
var
  TexPlayer    : TTexture2D;   // spritesheet: 8 frames x 2 rows (small/big)
  TexEnemy     : TTexture2D;   // goomba: 2 frames
  TexTiles     : TTexture2D;   // tileset: 4 tiles (ground,brick,block,coin)
  TexCoin      : TTexture2D;   // coin spin: 4 frames
  TexBackground: TTexture2D;   // sky gradient with hills

implementation

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
procedure FillRect(img: PImage; x, y, w, h: Integer; c: TColor);
var
  IX, IY: Integer;
  Color: TColor;
begin
  for IY := y to y + h - 1 do
    for IX := x to x + w - 1 do
    begin
      Color.Create(c.R, c.G, c.B, c.A);
      ImageDrawPixel(img, IX, IY, Color);
    end;
end;

procedure DrawCircleImg(img: PImage; cx, cy, r: Integer; c: TColor);
var
   IX, IY: Integer;
   Color: TColor;
begin
  for IY := cy - r to cy + r do
    for IX := cx - r to cx + r do
      if (Sqr(IX - cx) + Sqr(IY - cy)) <= Sqr(r) then
      begin
        Color.Create(c.R, c.G, c.B, c.A);
        ImageDrawPixel(img, IX, IY, Color);
      end;
end;

// ---------------------------------------------------------------------------
// Player spritesheet – 16x16 per frame, 8 frames wide, 2 rows
//   Row 0: small Mario  (idle, walk1, walk2, walk3, jump, run1, run2, dead)
//   Row 1: big Mario    (same layout)
// ---------------------------------------------------------------------------
procedure MakePlayer;
const
  FW = 16; FH = 16;
  COLS = 8;
  ROWS = 2;
  W = FW * COLS;
  H = FH * ROWS;
var
  img: TImage;
  col: TColor;
  F, R, BX, BY: Integer;
begin
  col.Create(0,0,0,0);
  img := GenImageColor(W, H, col);

  // Skin / hat / shoe / overall colours
  for R := 0 to ROWS - 1 do
    for F := 0 to COLS - 1 do
    begin
      BX := F * FW;
      BY := R * FH;
      // Hat (red)
      col.Create(200,30,30, 255);
      FillRect(@img, BX+3, BY+0, 10, 3, col);
      // Face (skin)
      col.Create(255,200,140, 255);
      FillRect(@img, BX+2, BY+3, 12, 5, col);
      // Eyes
      col.Create(10,10,10, 255);
      FillRect(@img, BX+4, BY+4, 2, 2, col);
      FillRect(@img, BX+10,BY+4, 2, 2, col);
      // Moustache
      col.Create(80,40,0, 255);
      FillRect(@img, BX+3, BY+7, 10, 2, col);
      // Overall (blue)
      col.Create(30,60,200, 255);
      FillRect(@img, BX+2, BY+8, 12, 5, col);
      // Buttons
      col.Create(255,255,80, 255);
      FillRect(@img, BX+5, BY+9, 2, 2, col);
      FillRect(@img, BX+9, BY+9, 2, 2, col);
      // Shoes (brown)
      col.Create(100,60,20, 255);
      FillRect(@img, BX+2, BY+13, 5, 3, col);
      FillRect(@img, BX+9, BY+13, 5, 3, col);
    end;

  TexPlayer := LoadTextureFromImage(img);
  UnloadImage(img);
end;

// ---------------------------------------------------------------------------
// Goomba – 16x16, 2 frames
// ---------------------------------------------------------------------------
procedure MakeEnemy;
var
   img: TImage;
   BX: Integer;
   col: TColor;
begin
   col.Create(0,0,0,0);
   img := GenImageColor(32, 16, col);
   for BX := 0 to 1 do
   begin
      // Body (brown)
      col.Create(150,75,0, 255);
      FillRect(@img, BX*16+1, 4, 14, 11, col);
      // Eyes
      col.Create(255,255,255, 255);
      FillRect(@img, BX*16+3, 5, 4, 4, col);
      FillRect(@img, BX*16+9, 5, 4, 4, col);
      col.Create(10,10,10, 255);
      FillRect(@img, BX*16+4, 6, 2, 2, col);
      FillRect(@img, BX*16+10,6, 2, 2, col);
      // Feet (alternate per frame)
      col.Create(80,40,0, 255);
      if BX = 0 then
      begin
         FillRect(@img, BX*16+2, 13, 4, 3, col);
         FillRect(@img, BX*16+10,13, 4, 3, col);
      end
      else
      begin
         FillRect(@img, BX*16+0, 13, 5, 3, col);
         FillRect(@img, BX*16+11,13, 5, 3, col);
      end;
   end;
   // Eyebrows (angry)
   col.Create(60,30,0, 255);
   FillRect(@img, BX*16+3, 4, 4, 1, col);
   FillRect(@img, BX*16+9, 4, 4, 1, col);

   TexEnemy := LoadTextureFromImage(img);
   UnloadImage(img);
end;

// ---------------------------------------------------------------------------
// Tileset – 16x16 per tile, 4 tiles in a row:
//   0=ground  1=brick  2=question-block  3=coin-tile
// ---------------------------------------------------------------------------
procedure MakeTiles;
var
   img: TImage;
   BX: Integer;
   col: TColor;
begin
   col.Create(0,0,0,0);
  img := GenImageColor(64, 16, col);

  // 0 – Ground (green/dirt)
  col.Create(80,160,50, 255);
  FillRect(@img, 0, 0, 16, 4,col);
  col.Create(140,100,60, 255);
  FillRect(@img, 0, 4, 16,12, col);
  // grid lines
  col.Create(100,70,30, 255);
  FillRect(@img, 0, 4, 16, 1, col);
  FillRect(@img, 8, 4, 1, 12, col);

  // 1 – Brick
  col.Create(180,80,30, 255);
  FillRect(@img,16, 0, 16,16, col);
  col.Create(220,120,60, 255);
  FillRect(@img,16, 0, 16, 1, col);
  col.Create(120,50,10, 255);
  FillRect(@img,16, 8, 16, 1, col);
  FillRect(@img,20, 1,  1,  7, col);
  FillRect(@img,28, 9,  1,  7, col);

  // 2 – Question block
  col.Create(200,160,0, 255);
  FillRect(@img,32, 0, 16,16, col);
  col.Create(240,200,50, 255);
  FillRect(@img,32, 0, 16, 1, col);
  FillRect(@img,32, 0,  1,16, col);
  col.Create(100,80,0, 255);
  FillRect(@img,47, 0,  1,16, col);
  FillRect(@img,32,15, 16, 1, col);
  // "?"
  col.Create(255,255,255, 255);
  FillRect(@img,37, 4,  6, 2, col);
  FillRect(@img,41, 6,  2, 3, col);
  FillRect(@img,39, 9,  4, 2, col);
  FillRect(@img,39,12,  4, 2, col);

  // 3 – Coin in tile
  col.Create(255,215,0, 255);
  DrawCircleImg(@img, 56, 8, 6, col);
  col.Create(255,240,100, 255);
  DrawCircleImg(@img, 56, 8, 3, col);

  TexTiles := LoadTextureFromImage(img);
  UnloadImage(img);
end;

// ---------------------------------------------------------------------------
// Spinning coin – 16x16, 4 frames
// ---------------------------------------------------------------------------
procedure MakeCoin;
var
   img: TImage;
   F: Integer;
   W: Integer;
   col: TColor;
begin
  col.Create(0,0,0,0);
  img := GenImageColor(64, 16, col);
  // Widths for each frame simulate rotation: 14, 8, 2, 8
  for F := 0 to 3 do
  begin
    case F of
      0: W := 14;
      1: W := 8;
      2: W := 2;
      3: W := 8;
    end;
    col.Create(255,215,0, 255);
    DrawCircleImg(@img, F*16+8, 8, W div 2, col);
    col.Create(255,240,100, 255);
    DrawCircleImg(@img, F*16+8, 8, W div 4, col);
  end;
  TexCoin := LoadTextureFromImage(img);
  UnloadImage(img);
end;

// ---------------------------------------------------------------------------
// Background – sky + hills + clouds (512 x 240)
// ---------------------------------------------------------------------------
procedure MakeBackground;
var
   img: TImage;
   IX, IY, Dist: Integer;
   col: TColor;
begin
  col.Create(92,148,252,255);
  img := GenImageColor(512, 240, col);

  // Ground strip
  col.Create(80,160,50, 255);
  FillRect(@img, 0, 210, 512, 30, col);
  col.Create(140,100,60, 255);
  FillRect(@img, 0, 218, 512, 22, col);

  // Hills
  for IX := 0 to 511 do
    for IY := 150 to 209 do
    begin
      Dist := Sqr(IX - 80) + Sqr(IY - 210);
      col.Create(50,140,30,255);
      if Dist < Sqr(80) then
        ImageDrawPixel(@img, IX, IY, col);
      Dist := Sqr(IX - 320) + Sqr(IY - 210);
      if Dist < Sqr(110) then
        ImageDrawPixel(@img, IX, IY, col);
    end;

  // Clouds
  col.Create(255, 255, 255, 255);
  DrawCircleImg(@img,100, 60, 20, col);
  DrawCircleImg(@img,125, 55, 25, col);
  DrawCircleImg(@img,150, 60, 20, col);

  DrawCircleImg(@img,350, 40, 18, col);
  DrawCircleImg(@img,372, 35, 22, col);
  DrawCircleImg(@img,394, 40, 18, col);

  TexBackground := LoadTextureFromImage(img);
  UnloadImage(img);
end;

// ---------------------------------------------------------------------------
procedure GenerateAssets;
begin
  MakePlayer;
  MakeEnemy;
  MakeTiles;
  MakeCoin;
  MakeBackground;
end;

procedure UnloadAssets;
begin
  if TexPlayer.Id > 0     then UnloadTexture(TexPlayer);
  if TexEnemy.Id > 0      then UnloadTexture(TexEnemy);
  if TexTiles.Id > 0      then UnloadTexture(TexTiles);
  if TexCoin.Id > 0       then UnloadTexture(TexCoin);
  if TexBackground.Id > 0 then UnloadTexture(TexBackground);
end;

end.
