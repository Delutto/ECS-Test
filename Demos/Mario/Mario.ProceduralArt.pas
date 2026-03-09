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
   F, R, BX, BY: Integer;
   LegOffset: Integer;
begin
   img := GenImageColor(W, H, Blank); // Usar Blank ou ColorCreate(0,0,0,0)

   for R := 0 to ROWS - 1 do
   begin
      for F := 0 to COLS - 1 do
      begin
         BX := F * FW;
         BY := R * FH;

         // Lógica simples de animação baseada no frame F
         // 0=Idle, 1-3=Walk, 4=Jump, 5-6=Run, 7=Dead
         LegOffset := 0;

         // Animação das pernas
         if (F >= 1) and (F <= 3) then // Walk
         begin
            if F = 1 then LegOffset := -2
            else if F = 2 then LegOffset := 0
            else if F = 3 then LegOffset := 2;
         end
         else if (F >= 5) and (F <= 6) then // Run
         begin
            if F = 5 then LegOffset := -3
            else LegOffset := 3;
         end
         else if F = 4 then // Jump
            LegOffset := -4; // Pernas encolhidas

         // --- Desenho do Mario ---

         // Cabeça/Chapéu (sempre igual)
         // Hat (red)
         FillRect(@img, BX+2, BY+2, 12, 3, RED);
         FillRect(@img, BX+10, BY+2, 4, 3, RED); // Aba do boné

         // Face (skin)
         FillRect(@img, BX+2, BY+5, 10, 4, BEIGE);
         // Eyes
         FillRect(@img, BX+8, BY+5, 2, 2, BLACK);
         // Moustache
         FillRect(@img, BX+9, BY+7, 4, 1, BLACK);
         // Sideburns / Hair
         FillRect(@img, BX+2, BY+6, 2, 2, BROWN);

         // Corpo / Macacão (Blue)
         FillRect(@img, BX+4, BY+9, 6, 4, BLUE);

         // Braços (Red) - variam levemente com walk
         if (F = 1) or (F = 3) or (F = 5) or (F = 6) then
         begin
             // Braços balançando
             FillRect(@img, BX+2, BY+9, 2, 3, RED);
             FillRect(@img, BX+10, BY+9, 2, 3, RED);
         end
         else
         begin
             // Braços parados
             FillRect(@img, BX+1, BY+9, 3, 3, RED);
             FillRect(@img, BX+10, BY+9, 3, 3, RED);
         end;

         // Botões do macacão
         FillRect(@img, BX+4, BY+10, 1, 1, YELLOW);
         FillRect(@img, BX+9, BY+10, 1, 1, YELLOW);

         // Pernas / Sapatos (Brown)
         // Perna esquerda
         FillRect(@img, BX+3 + LegOffset, BY+13, 3, 3, BROWN);
         // Perna direita
         FillRect(@img, BX+8 - LegOffset, BY+13, 3, 3, BROWN);

         // Frame de Morte (Dead) - vira de cabeça para baixo ou olhos em X
         if F = 7 then
         begin
            // Olhos em X
            FillRect(@img, BX+8, BY+5, 3, 1, BLACK);
            FillRect(@img, BX+9, BY+4, 1, 3, BLACK);
         end;
      end;
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
   img: TImage;
   BX: Integer;
begin
   img := GenImageColor(64, 16, ColorCreate(0,0,0,0));

   // 0 – Ground (green/dirt)
   FillRect(@img, 0, 0, 16, 4, ColorCreate(80,160,50, 255));
   FillRect(@img, 0, 4, 16,12, ColorCreate(140,100,60, 255));
   // grid lines
   FillRect(@img, 0, 4, 16, 1, ColorCreate(100,70,30, 255));
   FillRect(@img, 8, 4, 1, 12, ColorCreate(100,70,30, 255));

   // 1 – Brick
   FillRect(@img,16, 0, 16,16, ColorCreate(180,80,30, 255));
   FillRect(@img,16, 0, 16, 1, ColorCreate(220,120,60, 255));
   FillRect(@img,16, 8, 16, 1, ColorCreate(120,50,10, 255));
   FillRect(@img,20, 1,  1,  7, ColorCreate(120,50,10, 255));
   FillRect(@img,28, 9,  1,  7, ColorCreate(120,50,10, 255));

   // 2 – Question block
   FillRect(@img,32, 0, 16,16, ColorCreate(200,160,0, 255));
   FillRect(@img,32, 0, 16, 1, ColorCreate(240,200,50, 255));
   FillRect(@img,32, 0,  1,16, ColorCreate(240,200,50, 255));
   FillRect(@img,47, 0,  1,16, ColorCreate(100,80,0, 255));
   FillRect(@img,32,15, 16, 1, ColorCreate(100,80,0, 255));
   // "?"
   FillRect(@img,37, 4,  6, 2, ColorCreate(255,255,255, 255));
   FillRect(@img,41, 6,  2, 3, ColorCreate(255,255,255, 255));
   FillRect(@img,39, 9,  4, 2, ColorCreate(255,255,255, 255));
   FillRect(@img,39,12,  4, 2, ColorCreate(255,255,255, 255));

   // 3 – Coin in tile
   DrawCircleImg(@img, 56, 8, 6, ColorCreate(255,215,0, 255));
   DrawCircleImg(@img, 56, 8, 3, ColorCreate(255,240,100, 255));

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
   MakePlayer;
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
