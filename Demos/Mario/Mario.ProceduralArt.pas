unit Mario.ProceduralArt;

{$mode objfpc}{$H+}

{ Geração procedural de todos os assets visuais da demo Mario.
  Nenhum arquivo de imagem externo é necessário.

  Spritesheet do player (128x32) — 8 colunas × 2 linhas (small / big):
    Col 0 : idle
    Col 1 : walk A  (pé direito à frente)
    Col 2 : walk B  (cruzamento de passada)
    Col 3 : walk C  (pé esquerdo à frente)
    Col 4 : jump    (pernas recolhidas, braços levantados)
    Col 5 : run A   (passada larga – perna dir. muito à frente)
    Col 6 : run B   (passada larga – perna esq. muito à frente)
    Col 7 : dead    (pernas e braços abertos) }

interface

uses
   raylib, P2D.Core.Types;

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

// ---------------------------------------------------------------------------
// Goomba – 16x16, 2 frames
// ---------------------------------------------------------------------------
procedure MakeEnemy;
var
   img: TImage;
   BX: Integer;
begin
   img := GenImageColor(32, 16, ColorCreate(0,0,0,0));
   for BX := 0 to 1 do
   begin
      // Body (brown)
      FillRect(@img, BX*16+1, 4, 14, 11, ColorCreate(150,75,0, 255));
      // Eyes
      FillRect(@img, BX*16+3, 5, 4, 4, ColorCreate(255,255,255, 255));
      FillRect(@img, BX*16+9, 5, 4, 4, ColorCreate(255,255,255, 255));
      FillRect(@img, BX*16+4, 6, 2, 2, ColorCreate(10,10,10, 255));
      FillRect(@img, BX*16+10,6, 2, 2, ColorCreate(10,10,10, 255));
      // Feet (alternate per frame)
      if BX = 0 then
      begin
         FillRect(@img, BX*16+2, 13, 4, 3, ColorCreate(80,40,0, 255));
         FillRect(@img, BX*16+10,13, 4, 3, ColorCreate(80,40,0, 255));
      end
      else
      begin
         FillRect(@img, BX*16+0, 13, 5, 3, ColorCreate(80,40,0, 255));
         FillRect(@img, BX*16+11,13, 5, 3, ColorCreate(80,40,0, 255));
      end;
   end;
   // Eyebrows (angry)
   FillRect(@img, BX*16+3, 4, 4, 1, ColorCreate(60,30,0, 255));
   FillRect(@img, BX*16+9, 4, 4, 1, ColorCreate(60,30,0, 255));

   TexEnemy := LoadTextureFromImage(img);
   UnloadImage(img);
end;

// ---------------------------------------------------------------------------
// Tileset – 16x16 per tile, 4 tiles in a row:
//   0=ground  1=brick  2=question-block  3=coin-tile
// ---------------------------------------------------------------------------
procedure MakeTiles;
var
   Img: TImage;
   X  : Integer;
begin
   Img := GenImageColor(64, 16, ColorCreate(0, 0, 0, 0));

   { ── Tile 0 (TileID 1): Solid ground ─────────────────────────────────────── }
   FillRect(@Img,  0, 0, 16, 16, ColorCreate(139, 101,  62, 255)); { dirt brown  }
   FillRect(@Img,  0, 0, 16,  4, ColorCreate( 80, 160,  50, 255)); { grass strip }
   { Subtle grid lines to break up the surface }
   for X := 0 to 15 do
      ImageDrawPixel(@Img, X, 4, ColorCreate(60, 130, 40, 255));

   { ── Tile 1 (TileID 2): Semi-solid one-way platform ──────────────────────── }
   { Visually distinct: a lighter wood-plank look with a clear top edge         }
   FillRect(@Img, 16,  0, 16, 16, ColorCreate(210, 170, 100, 255)); { plank base  }
   FillRect(@Img, 16,  0, 16,  3, ColorCreate(240, 200, 120, 255)); { bright top  }
   FillRect(@Img, 16,  3, 16,  1, ColorCreate(160, 120,  60, 255)); { top border  }
   { Vertical plank separators }
   ImageDrawPixel(@Img, 20,  4, ColorCreate(160, 120, 60, 255));
   ImageDrawPixel(@Img, 20,  5, ColorCreate(160, 120, 60, 255));
   ImageDrawPixel(@Img, 20,  6, ColorCreate(160, 120, 60, 255));
   ImageDrawPixel(@Img, 24,  4, ColorCreate(160, 120, 60, 255));
   ImageDrawPixel(@Img, 24,  5, ColorCreate(160, 120, 60, 255));
   ImageDrawPixel(@Img, 24,  6, ColorCreate(160, 120, 60, 255));
   ImageDrawPixel(@Img, 28,  4, ColorCreate(160, 120, 60, 255));
   ImageDrawPixel(@Img, 28,  5, ColorCreate(160, 120, 60, 255));
   ImageDrawPixel(@Img, 28,  6, ColorCreate(160, 120, 60, 255));

   { ── Tile 2 (TileID 3): ? Block ──────────────────────────────────────────── }
   FillRect(@Img, 32,  0, 16, 16, ColorCreate(220, 170,   0, 255)); { gold body   }
   FillRect(@Img, 32,  0, 16,  1, ColorCreate(255, 210,  80, 255)); { top shine   }
   FillRect(@Img, 32,  0,  1, 16, ColorCreate(255, 210,  80, 255)); { left shine  }
   FillRect(@Img, 47,  0,  1, 16, ColorCreate(160, 110,   0, 255)); { right dark  }
   FillRect(@Img, 32, 15, 16,  1, ColorCreate(160, 110,   0, 255)); { bottom dark }
   { "?" mark — 3 small rectangles forming the glyph }
   FillRect(@Img, 37,  3,  6,  2, ColorCreate(255, 255, 255, 255)); { top bar     }
   FillRect(@Img, 41,  5,  2,  3, ColorCreate(255, 255, 255, 255)); { right leg   }
   FillRect(@Img, 38,  8,  4,  2, ColorCreate(255, 255, 255, 255)); { middle bar  }
   FillRect(@Img, 38, 11,  4,  2, ColorCreate(255, 255, 255, 255)); { dot         }

   { ── Tile 3 (TileID 4): Coin tile ────────────────────────────────────────── }
   DrawCircleImg(@Img, 56, 8, 6, ColorCreate(255, 200,   0, 255)); { gold circle  }
   DrawCircleImg(@Img, 56, 8, 4, ColorCreate(255, 230,  80, 255)); { inner shine  }

   TexTiles := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

// ---------------------------------------------------------------------------
// Spinning coin – 16x16, 4 frames
// ---------------------------------------------------------------------------
procedure MakeCoin;
var
   img: TImage;
   F: Integer;
   W: Integer;
begin
   img := GenImageColor(64, 16, ColorCreate(0,0,0,0));
   // Widths for each frame simulate rotation: 14, 8, 2, 8
   for F := 0 to 3 do
   begin
      case F of
         0: W := 14;
         1: W := 8;
         2: W := 2;
         3: W := 8;
      end;
      DrawCircleImg(@img, F*16+8, 8, W div 2, ColorCreate(255,215,0, 255));
      DrawCircleImg(@img, F*16+8, 8, W div 4, ColorCreate(255,240,100, 255));
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
begin
   img := GenImageColor(512, 240, ColorCreate(92,148,252,255));

   // Ground strip
   FillRect(@img, 0, 210, 512, 30, ColorCreate(80,160,50, 255));
   FillRect(@img, 0, 218, 512, 22, ColorCreate(140,100,60, 255));

   // Hills
   for IX := 0 to 511 do
   begin
      for IY := 150 to 209 do
      begin
         Dist := Sqr(IX - 80) + Sqr(IY - 210);
         if Dist < Sqr(80) then
            ImageDrawPixel(@img, IX, IY, ColorCreate(50,140,30,255));
         Dist := Sqr(IX - 320) + Sqr(IY - 210);
         if Dist < Sqr(110) then
            ImageDrawPixel(@img, IX, IY, ColorCreate(50,140,30,255));
      end;
   end;

   // Clouds
   DrawCircleImg(@img,100, 60, 20, ColorCreate(255, 255, 255, 255));
   DrawCircleImg(@img,125, 55, 25, ColorCreate(255, 255, 255, 255));
   DrawCircleImg(@img,150, 60, 20, ColorCreate(255, 255, 255, 255));

   DrawCircleImg(@img,350, 40, 18, ColorCreate(255, 255, 255, 255));
   DrawCircleImg(@img,372, 35, 22, ColorCreate(255, 255, 255, 255));
   DrawCircleImg(@img,394, 40, 18, ColorCreate(255, 255, 255, 255));

   TexBackground := LoadTextureFromImage(img);
   UnloadImage(img);
end;

// ---------------------------------------------------------------------------
procedure GenerateAssets;
begin
   MakeEnemy;
   MakeTiles;
   MakeCoin;
   MakeBackground;
end;

procedure UnloadAssets;
begin
   if TexPlayer.Id > 0 then
      UnloadTexture(TexPlayer);
   if TexEnemy.Id > 0 then
      UnloadTexture(TexEnemy);
   if TexTiles.Id > 0 then
      UnloadTexture(TexTiles);
   if TexCoin.Id > 0 then
      UnloadTexture(TexCoin);
   if TexBackground.Id > 0 then
      UnloadTexture(TexBackground);
end;

end.
