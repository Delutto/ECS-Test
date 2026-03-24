unit Mario.Assets;

{$mode objfpc}
{$H+}

interface

uses
   raylib,
   P2D.Core.Types;

procedure GenerateAssets;
procedure UnloadAssets;

var
  { ── Level 1 (overworld) textures ── }
   TexEnemy: TTexture2D;   { Goomba: 2 frames × 16×16           }
   TexTiles: TTexture2D;   { Tileset: 4 tiles 16×16             }
   TexBackground: TTexture2D;   { Sky + hills + clouds 512×240       }
   TexBackground2: TTexture2D;   { Near hills + bushes 256×120        }

  { ── Level 2 (underwater) textures ── }
   TexWaterBG: TTexture2D;   { Deep-sea background 512×240        }
   TexWaterNear: TTexture2D;   { Seaweed + bubbles (alpha) 256×120  }
   TexCoralTiles: TTexture2D;   { Coral tileset: 4 tiles 16×16       }
   TexFish: TTexture2D;   { Fish enemy: 2 frames × 16×16       }

implementation

{ ── Helpers ──────────────────────────────────────────────────────────────── }
procedure FillRect(img: PImage; x, y, w, h: Integer; c: TColor);
var
   IX, IY: Integer;
begin
   for IY := y to y + h - 1 do
   begin
      for IX := x to x + w - 1 do
      begin
         ImageDrawPixel(img, IX, IY, ColorCreate(c.R, c.G, c.B, c.A))
      end
   end;
end;

procedure DrawCircleImg(img: PImage; cx, cy, r: Integer; c: TColor);
var
   IX, IY: Integer;
begin
   for IY := cy - r to cy + r do
   begin
      for IX := cx - r to cx + r do
      begin
         if (Sqr(IX - cx) + Sqr(IY - cy)) <= Sqr(r) then
         begin
            ImageDrawPixel(img, IX, IY, ColorCreate(c.R, c.G, c.B, c.A))
         end
      end
   end;
end;

{ Light rays — bright diagonal streaks from the top }
procedure DrawRay(img: PImage; CX, Width_: Integer);
var
   IX, IY: Integer;
   Alpha: Byte;
begin
   for IY := 0 to 120 do
   begin
      Alpha := Round(60 * (1 - IY / 120));
      for IX := CX - Width_ to CX + Width_ do
      begin
         if (IX >= 0) And (IX < 512) then
         begin
            ImageDrawPixel(img, IX, IY, ColorCreate(160, 220, 255, Alpha))
         end
      end;
   end;
end;

procedure Stem(img: PImage; BaseX, H: Integer; C: TColor);
var
   SX, IY: Integer;
begin
   for SX := BaseX - 1 to BaseX + 1 do
   begin
      for IY := 120 - H to 119 do
      begin
         if (SX >= 0) And (SX < 256) then
         begin
            ImageDrawPixel(img, SX, IY, C)
         end
      end
   end;
end;

procedure Leaf(img: PImage; CX, CY, RX, RY: Integer; C: TColor);
var
   LX, LY: Integer;
begin
   for LY := CY - RY to CY + RY do
   begin
      for LX := CX - RX to CX + RX do
      begin
         if (Sqr(LX - CX) * RY * RY + Sqr(LY - CY) * RX * RX) <= (RX * RY * RX * RY) then
         begin
            if (LX >= 0) And (LX < 256) And (LY >= 0) And (LY < 120) then
            begin
               ImageDrawPixel(img, LX, LY, C)
            end
         end
      end
   end;
end;

{ ── Goomba (32×16) ───────────────────────────────────────────────────────── }
procedure MakeEnemy;
var
   img: TImage;
   BX: Integer;
begin
   img := GenImageColor(32, 16, ColorCreate(0, 0, 0, 0));
   for BX := 0 to 1 do
   begin
      FillRect(@img, BX * 16 + 1, 4, 14, 11, ColorCreate(150, 75, 0, 255));
      FillRect(@img, BX * 16 + 3, 5, 4, 4, ColorCreate(255, 255, 255, 255));
      FillRect(@img, BX * 16 + 9, 5, 4, 4, ColorCreate(255, 255, 255, 255));
      FillRect(@img, BX * 16 + 4, 6, 2, 2, ColorCreate(10, 10, 10, 255));
      FillRect(@img, BX * 16 + 10, 6, 2, 2, ColorCreate(10, 10, 10, 255));
      FillRect(@img, BX * 16 + 3, 4, 4, 1, ColorCreate(60, 30, 0, 255));
      FillRect(@img, BX * 16 + 9, 4, 4, 1, ColorCreate(60, 30, 0, 255));
      if BX = 0 then
      begin
         FillRect(@img, BX * 16 + 2, 13, 4, 3, ColorCreate(80, 40, 0, 255));
         FillRect(@img, BX * 16 + 10, 13, 4, 3, ColorCreate(80, 40, 0, 255));
      end
      else
      begin
         FillRect(@img, BX * 16 + 0, 13, 5, 3, ColorCreate(80, 40, 0, 255));
         FillRect(@img, BX * 16 + 11, 13, 5, 3, ColorCreate(80, 40, 0, 255));
      end;
   end;
   TexEnemy := LoadTextureFromImage(img);
   UnloadImage(img);
end;

{ ── Overworld tileset (64×16) ────────────────────────────────────────────── }
procedure MakeTiles;
var
   Img: TImage;
   X: Integer;
begin
   Img := GenImageColor(64, 16, ColorCreate(0, 0, 0, 0));
   FillRect(@Img, 0, 0, 16, 16, ColorCreate(139, 101, 62, 255));
   FillRect(@Img, 0, 0, 16, 4, ColorCreate(80, 160, 50, 255));
   for X := 0 to 15 do
   begin
      ImageDrawPixel(@Img, X, 4, ColorCreate(60, 130, 40, 255))
   end;
   FillRect(@Img, 16, 0, 16, 16, ColorCreate(210, 170, 100, 255));
   FillRect(@Img, 16, 0, 16, 3, ColorCreate(240, 200, 120, 255));
   FillRect(@Img, 16, 3, 16, 1, ColorCreate(160, 120, 60, 255));
   FillRect(@Img, 32, 0, 16, 16, ColorCreate(220, 170, 0, 255));
   FillRect(@Img, 32, 0, 16, 1, ColorCreate(255, 210, 80, 255));
   FillRect(@Img, 32, 0, 1, 16, ColorCreate(255, 210, 80, 255));
   FillRect(@Img, 47, 0, 1, 16, ColorCreate(160, 110, 0, 255));
   FillRect(@Img, 32, 15, 16, 1, ColorCreate(160, 110, 0, 255));
   FillRect(@Img, 37, 3, 6, 2, ColorCreate(255, 255, 255, 255));
   FillRect(@Img, 41, 5, 2, 3, ColorCreate(255, 255, 255, 255));
   FillRect(@Img, 38, 8, 4, 2, ColorCreate(255, 255, 255, 255));
   FillRect(@Img, 38, 11, 4, 2, ColorCreate(255, 255, 255, 255));
   DrawCircleImg(@Img, 56, 8, 6, ColorCreate(255, 200, 0, 255));
   DrawCircleImg(@Img, 56, 8, 4, ColorCreate(255, 230, 80, 255));
   TexTiles := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

{ ── Overworld far background (512×240) ───────────────────────────────────── }
procedure MakeBackground;
var
   img: TImage;
   IX, IY: Integer;
begin
   img := GenImageColor(512, 240, ColorCreate(92, 148, 252, 255));
   FillRect(@img, 0, 210, 512, 30, ColorCreate(80, 160, 50, 255));
   FillRect(@img, 0, 218, 512, 22, ColorCreate(140, 100, 60, 255));
   for IX := 0 to 511 do
   begin
      for IY := 150 to 209 do
      begin
         if Sqr(IX - 80) + Sqr(IY - 210) <= Sqr(80) then
         begin
            ImageDrawPixel(@img, IX, IY, ColorCreate(50, 140, 30, 255))
         end;
         if Sqr(IX - 320) + Sqr(IY - 210) <= Sqr(110) then
         begin
            ImageDrawPixel(@img, IX, IY, ColorCreate(50, 140, 30, 255))
         end;
         if Sqr(IX - 460) + Sqr(IY - 210) <= Sqr(65) then
         begin
            ImageDrawPixel(@img, IX, IY, ColorCreate(50, 140, 30, 255))
         end;
      end
   end;
   DrawCircleImg(@img, 100, 60, 20, WHITE);
   DrawCircleImg(@img, 125, 55, 25, WHITE);
   DrawCircleImg(@img, 150, 60, 20, WHITE);
   DrawCircleImg(@img, 350, 40, 18, WHITE);
   DrawCircleImg(@img, 372, 35, 22, WHITE);
   DrawCircleImg(@img, 394, 40, 18, WHITE);
   TexBackground := LoadTextureFromImage(img);
   UnloadImage(img);
end;

{ ── Overworld near background (256×120) ──────────────────────────────────── }
procedure MakeBackground2;
var
   img: TImage;
   IX, IY: Integer;
begin
   img := GenImageColor(256, 120, ColorCreate(0, 0, 0, 0));
   for IX := 0 to 255 do
   begin
      for IY := 50 to 119 do
      begin
         if Sqr(IX - 50) + Sqr(IY - 120) <= Sqr(55) then
         begin
            ImageDrawPixel(@img, IX, IY, ColorCreate(40, 120, 20, 255))
         end;
         if Sqr(IX - 180) + Sqr(IY - 120) <= Sqr(70) then
         begin
            ImageDrawPixel(@img, IX, IY, ColorCreate(40, 120, 20, 255))
         end;
      end
   end;
   DrawCircleImg(@img, 115, 110, 10, ColorCreate(30, 110, 10, 255));
   DrawCircleImg(@img, 128, 107, 13, ColorCreate(30, 110, 10, 255));
   DrawCircleImg(@img, 141, 110, 10, ColorCreate(30, 110, 10, 255));
   DrawCircleImg(@img, 210, 113, 8, ColorCreate(30, 110, 10, 255));
   DrawCircleImg(@img, 222, 110, 11, ColorCreate(30, 110, 10, 255));
   DrawCircleImg(@img, 234, 113, 8, ColorCreate(30, 110, 10, 255));
   TexBackground2 := LoadTextureFromImage(img);
   UnloadImage(img);
end;

{ ── Underwater far background (512×240) ──────────────────────────────────── }
procedure MakeWaterBG;
var
   img: TImage;
   IX, IY: Integer;
   Depth: Single;
   R, G, B: Byte;
begin
  { Deep blue gradient — darker at the bottom, lighter at top (light rays) }
   img := GenImageColor(512, 240, ColorCreate(0, 40, 120, 255));
   for IY := 0 to 239 do
   begin
      Depth := IY / 239;          { 0 = surface, 1 = deep }
      R := Round(20 * (1 - Depth) + 5 * Depth);
      G := Round(80 * (1 - Depth) + 20 * Depth);
      B := Round(180 * (1 - Depth) + 60 * Depth);
      for IX := 0 to 511 do
      begin
         ImageDrawPixel(@img, IX, IY, ColorCreate(R, G, B, 255))
      end;
   end;

   DrawRay(@img, 80, 6);
   DrawRay(@img, 210, 4);
   DrawRay(@img, 360, 8);
   DrawRay(@img, 450, 5);

  { Sandy / rocky floor strip }
   FillRect(@img, 0, 210, 512, 30, ColorCreate(80, 70, 40, 255));
   FillRect(@img, 0, 220, 512, 20, ColorCreate(100, 85, 50, 255));

  { Distant coral silhouettes }
   DrawCircleImg(@img, 60, 215, 18, ColorCreate(160, 40, 60, 255));
   DrawCircleImg(@img, 75, 210, 12, ColorCreate(180, 50, 70, 255));
   DrawCircleImg(@img, 200, 212, 22, ColorCreate(140, 30, 50, 255));
   DrawCircleImg(@img, 380, 216, 15, ColorCreate(160, 40, 60, 255));
   DrawCircleImg(@img, 460, 210, 20, ColorCreate(150, 35, 55, 255));

  { Bubbles rising from the floor }
   DrawCircleImg(@img, 130, 80, 3, ColorCreate(200, 230, 255, 180));
   DrawCircleImg(@img, 135, 55, 2, ColorCreate(200, 230, 255, 160));
   DrawCircleImg(@img, 300, 100, 4, ColorCreate(200, 230, 255, 180));
   DrawCircleImg(@img, 305, 70, 2, ColorCreate(200, 230, 255, 140));
   DrawCircleImg(@img, 420, 90, 3, ColorCreate(200, 230, 255, 180));

   TexWaterBG := LoadTextureFromImage(img);
   UnloadImage(img);
end;

{ ── Underwater near background — seaweed + bubbles (256×120, alpha) ─────── }
procedure MakeWaterNear;
var
   img: TImage;
begin
   img := GenImageColor(256, 120, ColorCreate(0, 0, 0, 0));

  { Seaweed stems and leaves }
   Stem(@img, 20, 55, ColorCreate(20, 140, 60, 230));
   Leaf(@img, 20, 75, 7, 4, ColorCreate(30, 160, 70, 220));
   Stem(@img, 22, 40, ColorCreate(15, 120, 50, 230));
   Leaf(@img, 22, 90, 5, 3, ColorCreate(25, 140, 60, 210));
   Stem(@img, 80, 65, ColorCreate(20, 140, 60, 230));
   Leaf(@img, 85, 65, 8, 5, ColorCreate(30, 160, 70, 220));
   Leaf(@img, 75, 75, 6, 4, ColorCreate(25, 150, 65, 210));
   Stem(@img, 140, 50, ColorCreate(15, 130, 55, 230));
   Leaf(@img, 145, 80, 7, 4, ColorCreate(30, 160, 70, 220));
   Stem(@img, 200, 60, ColorCreate(20, 140, 60, 230));
   Leaf(@img, 200, 70, 9, 5, ColorCreate(30, 160, 70, 220));
   Leaf(@img, 195, 85, 6, 4, ColorCreate(25, 150, 65, 210));
   Stem(@img, 240, 45, ColorCreate(15, 120, 50, 230));
   Leaf(@img, 240, 85, 5, 3, ColorCreate(25, 140, 60, 210));

  { Bubbles }
   DrawCircleImg(@img, 50, 30, 4, ColorCreate(200, 230, 255, 150));
   DrawCircleImg(@img, 52, 15, 2, ColorCreate(200, 230, 255, 120));
   DrawCircleImg(@img, 160, 50, 3, ColorCreate(200, 230, 255, 150));
   DrawCircleImg(@img, 220, 20, 5, ColorCreate(200, 230, 255, 130));

   TexWaterNear := LoadTextureFromImage(img);
   UnloadImage(img);
end;

{ ── Coral tileset (64×16, 4 tiles 16×16) ─────────────────────────────────── }
procedure MakeCoralTiles;
var
   Img: TImage;
begin
   Img := GenImageColor(64, 16, ColorCreate(0, 0, 0, 0));

  { Tile 0 — sandy floor (TILE_SOLID) }
   FillRect(@Img, 0, 0, 16, 16, ColorCreate(90, 75, 45, 255));  { sand body    }
   FillRect(@Img, 0, 0, 16, 3, ColorCreate(120, 100, 60, 255));  { lighter top  }
   FillRect(@Img, 0, 3, 16, 1, ColorCreate(70, 55, 30, 255));  { border line  }

  { Tile 1 — coral wall (TILE_SOLID) — orange-pink coral block }
   FillRect(@Img, 16, 0, 16, 16, ColorCreate(180, 60, 70, 255));  { coral body   }
   FillRect(@Img, 16, 0, 16, 1, ColorCreate(210, 90, 100, 255));  { top shine    }
   FillRect(@Img, 16, 0, 1, 16, ColorCreate(210, 90, 100, 255));  { left shine   }
   FillRect(@Img, 31, 0, 1, 16, ColorCreate(130, 40, 50, 255));  { right shadow }
   FillRect(@Img, 16, 15, 16, 1, ColorCreate(130, 40, 50, 255));  { bottom shadow}
   DrawCircleImg(@Img, 22, 8, 3, ColorCreate(220, 100, 110, 255));  { coral polyp  }

  { Tile 2 — semi-solid coral platform (TILE_SEMI) }
   FillRect(@Img, 32, 0, 16, 16, ColorCreate(160, 50, 60, 200));  { semi body    }
   FillRect(@Img, 32, 0, 16, 4, ColorCreate(220, 110, 120, 255));  { bright top   }
   FillRect(@Img, 32, 4, 16, 1, ColorCreate(100, 30, 40, 255));  { top border   }

  { Tile 3 — starfish decoration (TILE_SOLID) }
   FillRect(@Img, 48, 0, 16, 16, ColorCreate(70, 60, 35, 255));  { same as sand }
   DrawCircleImg(@Img, 56, 8, 5, ColorCreate(220, 120, 0, 255));  { starfish     }
   DrawCircleImg(@Img, 56, 8, 2, ColorCreate(255, 180, 50, 255));  { center glow  }

   TexCoralTiles := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

{ ── Fish enemy (32×16, 2 frames) ─────────────────────────────────────────── }
procedure MakeFish;
var
   img: TImage;
   BX: Integer;
begin
   img := GenImageColor(32, 16, ColorCreate(0, 0, 0, 0));
   for BX := 0 to 1 do
   begin
    { Body — bright blue-green fish }
      FillRect(@img, BX * 16 + 2, 3, 10, 8, ColorCreate(30, 160, 180, 255));
      FillRect(@img, BX * 16 + 1, 5, 2, 4, ColorCreate(50, 190, 210, 255));
      FillRect(@img, BX * 16 + 12, 3, 3, 10, ColorCreate(20, 130, 150, 255));  { tail connect}
    { Tail — alternate frame for swimming motion }
      if BX = 0 then
      begin
         FillRect(@img, BX * 16 + 13, 1, 3, 5, ColorCreate(20, 130, 150, 255));
         FillRect(@img, BX * 16 + 13, 9, 3, 5, ColorCreate(20, 130, 150, 255));
      end
      else
      begin
         FillRect(@img, BX * 16 + 13, 3, 3, 4, ColorCreate(20, 130, 150, 255));
         FillRect(@img, BX * 16 + 13, 8, 3, 4, ColorCreate(20, 130, 150, 255));
      end;
    { Eye }
      FillRect(@img, BX * 16 + 3, 5, 2, 2, ColorCreate(255, 255, 255, 255));
      FillRect(@img, BX * 16 + 4, 6, 1, 1, ColorCreate(0, 0, 0, 255));
    { Fin }
      FillRect(@img, BX * 16 + 5, 2, 4, 2, ColorCreate(50, 190, 210, 220));
   end;
   TexFish := LoadTextureFromImage(img);
   UnloadImage(img);
end;

{ ── Public API ────────────────────────────────────────────────────────────── }
procedure GenerateAssets;
begin
   MakeEnemy;
   MakeTiles;
   MakeBackground;
   MakeBackground2;
   MakeWaterBG;
   MakeWaterNear;
   MakeCoralTiles;
   MakeFish;
end;

procedure UnloadAssets;
   procedure U(var T: TTexture2D);
   begin
      if T.Id > 0 then
      begin
         UnloadTexture(T)
      end;
   end;

begin
   U(TexEnemy);
   U(TexTiles);
   U(TexBackground);
   U(TexBackground2);
   U(TexWaterBG);
   U(TexWaterNear);
   U(TexCoralTiles);
   U(TexFish);
end;

end.
