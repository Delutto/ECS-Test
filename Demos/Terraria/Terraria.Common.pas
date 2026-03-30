unit Terraria.Common;

{$mode objfpc}{$H+}

interface

type
   TRect4 = record
      X, Y, W, H, R, G, B: Integer;
   end;

const
   { ── World dimensions ─────────────────────────────────────────────────── }
   MAP_WIDTH = 2048;
   MAP_HEIGHT = 256;
   TILE_SIZE = 8;

   { ── Surface generation parameters ───────────────────────────────────── }
   BASE_SURFACE = 48;
   SURFACE_AMP = 14;
   MIN_SURFACE = 20;
   MAX_SURFACE = 70;

   { ── Depth thresholds ─────────────────────────────────────────────────── }
   DEPTH_DIRT = 6;
   DEPTH_DIRT_STONE = 22;
   DEPTH_STONE = 80;

   { ── Cave parameters ──────────────────────────────────────────────────── }
   CAVE_START_DEPTH = 6;
   CAVE_THRESHOLD = 0.14;

   { =========================================================================
     TERRAIN TILE TYPE BYTE CODES
     =========================================================================
     IDs 1–13 are SOLID terrain tiles rendered via the soil spritesheet.
     TILE_SHRUB (14) is the decoration boundary — every ID >= TILE_SHRUB is
     a transparent decoration tile rendered via procedurally-generated textures.
     ========================================================================= }

   TILE_AIR = 0;

   { ── Solid terrain (IDs 1–13) — rendered from soils_better_16x16.png ─── }
   TILE_DIRT = 1;
   TILE_GRASS = 2;
   TILE_STONE = 3;
   TILE_SAND = 4;
   TILE_SANDSTONE = 5;
   TILE_GRANITE = 6;
   TILE_MARBLE = 7;
   TILE_CLAY = 8;
   TILE_GRAVEL = 9;
   TILE_BEDROCK = 10;

   { New solid tiles — also rendered from the spritesheet }
   TILE_MUD = 11;   { muddy ground (swamp/cave transition zones) }
   TILE_SNOW = 12;   { surface snow (snow biome)                  }
   TILE_ICE = 13;   { solid ice (deep snow biome)                }

   { ── Decoration boundary ─────────────────────────────────────────────── }
   { Every tile ID >= TILE_SHRUB is a decoration (semi-transparent,
     rendered from procedurally-generated CPU textures). }
   TILE_SHRUB = 14;   { small bush / grass tuft (plains)           }

   { ── Surface vegetation (IDs 15–19) ──────────────────────────────────── }
   TILE_TREE_TRUNK = 15;
   TILE_TREE_LEAF = 16;
   TILE_CACTUS = 17;
   TILE_CACTUS_TOP = 18;
   TILE_FERN = 19;

   { ── Cave decorations (IDs 20–25) ────────────────────────────────────── }
   TILE_ROOT = 20;
   TILE_VINE = 21;
   TILE_STALACTITE = 22;
   TILE_STALAGMITE = 23;
   TILE_MUSHROOM = 24;
   TILE_MOSS = 25;

   TILE_COUNT = 26;   { total number of tile types }

   { =========================================================================
     SOIL SPRITESHEET — soils_better_16x16.png
     =========================================================================
     Layout: 4 columns × 13 rows, each cell is 16×16 pixels.
       Columns 0–3  = four visual variations of the same soil type.
       Rows 0–12    = one soil type per row (see SOIL_SHEET_ROW below).

     Each solid tile is rendered by picking one of the four variation columns
     using a deterministic hash of its world-tile coordinates, producing a
     natural, non-repeating appearance with zero extra memory cost.
     ========================================================================= }
   SOIL_SHEET_PATH = 'assets/graphics/soils_better_16x16.png';
   SOIL_SHEET_TILE = 16;   { pixel size of each cell in the spritesheet   }
   SOIL_SHEET_COLS = 4;    { variation columns per soil type               }
   SOIL_SHEET_ROWS = 13;   { number of soil-type rows in the spritesheet   }

   { Maps tile ID → spritesheet row.
     -1 = tile is not in the spritesheet (decoration or air) — use FTex/FTexBG. }
   SOIL_SHEET_ROW: array[0..TILE_COUNT - 1] of shortint = (
      -1,   {  0: TILE_AIR        — not rendered                  }
      1,    {  1: TILE_DIRT       — row  1  DIRT                  }
      0,    {  2: TILE_GRASS      — row  0  DIRTGRASS             }
      2,    {  3: TILE_STONE      — row  2  STONE                 }
      3,    {  4: TILE_SAND       — row  3  SAND                  }
      4,    {  5: TILE_SANDSTONE  — row  4  SANDSTONE             }
      5,    {  6: TILE_GRANITE    — row  5  GRANITE               }
      6,    {  7: TILE_MARBLE     — row  6  MARBLE                }
      7,    {  8: TILE_CLAY       — row  7  CLAY                  }
      9,    {  9: TILE_GRAVEL     — row  9  GRAVEL                }
      12,   { 10: TILE_BEDROCK    — row 12  BEDROCK               }
      8,    { 11: TILE_MUD        — row  8  MUD                   }
      10,   { 12: TILE_SNOW       — row 10  SNOW                  }
      11,   { 13: TILE_ICE        — row 11  ICE                   }
      -1,   { 14: TILE_SHRUB      — decoration (procedural)       }
      -1,   { 15: TILE_TREE_TRUNK — decoration                    }
      -1,   { 16: TILE_TREE_LEAF  — decoration                    }
      -1,   { 17: TILE_CACTUS     — decoration                    }
      -1,   { 18: TILE_CACTUS_TOP — decoration                    }
      -1,   { 19: TILE_FERN       — decoration                    }
      -1,   { 20: TILE_ROOT       — decoration                    }
      -1,   { 21: TILE_VINE       — decoration                    }
      -1,   { 22: TILE_STALACTITE — decoration                    }
      -1,   { 23: TILE_STALAGMITE — decoration                    }
      -1,   { 24: TILE_MUSHROOM   — decoration                    }
      -1    { 25: TILE_MOSS       — decoration                    }
      );

   { ── Background dim factor for soil sheet tiles ───────────────────────── }
   { Background (wall) soil tiles are rendered from the same spritesheet but with this multiplier applied to all RGB channels of the computed tint. }
   SOIL_BG_DIM: Single = 0.60;

   { =========================================================================
     DECORATION TILE PALETTE DATA
     Used by TChunkRenderSystem.GenTileTextures to build procedural CPU
     textures for decoration tiles (TILE_SHRUB and above).
     Soil tile palette arrays are kept for reference but are no longer used
     by the renderer — the spritesheet replaces them.
     ========================================================================= }

   { ── TILE_SHRUB (14) — leafy green bush ───────────────────────────────── }
   TILE_SHRUB_RGB: array[0..3] of TRect4 = (
      (X: 1; Y: 3; W: 6; H: 4; R: 50; G: 150; B: 40),
      (X: 0; Y: 4; W: 8; H: 3; R: 60; G: 170; B: 50),
      (X: 2; Y: 2; W: 4; H: 2; R: 70; G: 160; B: 44),
      (X: 3; Y: 6; W: 2; H: 2; R: 100; G: 70; B: 40));

   { ── TILE_TREE_TRUNK (15) ─────────────────────────────────────────────── }
   TILE_TREE_TRUNK_RGB: array[0..3] of TRect4 = (
      (X: 2; Y: 0; W: 4; H: 8; R: 120; G: 80; B: 46),
      (X: 3; Y: 0; W: 2; H: 8; R: 130; G: 90; B: 52),
      (X: 2; Y: 2; W: 1; H: 2; R: 90; G: 58; B: 32),
      (X: 5; Y: 5; W: 1; H: 2; R: 90; G: 58; B: 32));

   { ── TILE_TREE_LEAF (16) ──────────────────────────────────────────────── }
   TILE_TREE_LEAF_RGB: array[0..0] of TRect4 = (
      (X: 0; Y: 0; W: 8; H: 8; R: 40; G: 130; B: 36));

   { ── TILE_CACTUS (17) ─────────────────────────────────────────────────── }
   TILE_CACTUS_RGB: array[0..3] of TRect4 = (
      (X: 2; Y: 0; W: 4; H: 8; R: 50; G: 140; B: 50),
      (X: 1; Y: 2; W: 1; H: 1; R: 40; G: 120; B: 40),
      (X: 6; Y: 5; W: 1; H: 1; R: 40; G: 120; B: 40),
      (X: 3; Y: 0; W: 2; H: 8; R: 60; G: 160; B: 58));

   { ── TILE_CACTUS_TOP (18) ─────────────────────────────────────────────── }
   TILE_CACTUS_TOP_RGB: array[0..2] of TRect4 = (
      (X: 2; Y: 2; W: 4; H: 6; R: 50; G: 140; B: 50),
      (X: 3; Y: 0; W: 2; H: 3; R: 60; G: 160; B: 58),
      (X: 3; Y: 0; W: 2; H: 1; R: 80; G: 180; B: 70));

   { ── TILE_FERN (19) ───────────────────────────────────────────────────── }
   TILE_FERN_RGB: array[0..3] of TRect4 = (
      (X: 3; Y: 5; W: 2; H: 3; R: 80; G: 110; B: 40),
      (X: 1; Y: 3; W: 3; H: 3; R: 60; G: 140; B: 40),
      (X: 4; Y: 2; W: 3; H: 4; R: 55; G: 135; B: 38),
      (X: 2; Y: 1; W: 2; H: 2; R: 70; G: 150; B: 44));

   { ── TILE_ROOT (20) ───────────────────────────────────────────────────── }
   TILE_ROOT_RGB: array[0..2] of TRect4 = (
      (X: 3; Y: 0; W: 2; H: 8; R: 120; G: 80; B: 44),
      (X: 2; Y: 2; W: 1; H: 2; R: 100; G: 64; B: 34),
      (X: 5; Y: 5; W: 1; H: 2; R: 100; G: 64; B: 34));

   { ── TILE_VINE (21) ───────────────────────────────────────────────────── }
   TILE_VINE_RGB: array[0..2] of TRect4 = (
      (X: 3; Y: 0; W: 2; H: 8; R: 44; G: 130; B: 44),
      (X: 1; Y: 3; W: 2; H: 2; R: 36; G: 110; B: 36),
      (X: 5; Y: 6; W: 2; H: 1; R: 36; G: 110; B: 36));

   { ── TILE_STALACTITE (22) ─────────────────────────────────────────────── }
   TILE_STALACTITE_RGB: array[0..2] of TRect4 = (
      (X: 3; Y: 0; W: 2; H: 5; R: 130; G: 128; B: 140),
      (X: 3; Y: 5; W: 2; H: 2; R: 110; G: 108; B: 120),
      (X: 3; Y: 7; W: 2; H: 1; R: 90; G: 88; B: 100));

   { ── TILE_STALAGMITE (23) ─────────────────────────────────────────────── }
   TILE_STALAGMITE_RGB: array[0..2] of TRect4 = (
      (X: 3; Y: 3; W: 2; H: 5; R: 130; G: 128; B: 140),
      (X: 3; Y: 1; W: 2; H: 2; R: 110; G: 108; B: 120),
      (X: 3; Y: 0; W: 2; H: 1; R: 90; G: 88; B: 100));

   { ── TILE_MUSHROOM (24) ───────────────────────────────────────────────── }
   TILE_MUSHROOM_RGB: array[0..4] of TRect4 = (
      (X: 2; Y: 3; W: 4; H: 5; R: 200; G: 60; B: 140),
      (X: 1; Y: 2; W: 6; H: 3; R: 220; G: 80; B: 160),
      (X: 0; Y: 3; W: 8; H: 2; R: 240; G: 100; B: 180),
      (X: 3; Y: 1; W: 2; H: 2; R: 200; G: 60; B: 140),
      (X: 2; Y: 6; W: 4; H: 2; R: 180; G: 170; B: 175));

   { ── TILE_MOSS (25) ───────────────────────────────────────────────────── }
   TILE_MOSS_RGB: array[0..2] of TRect4 = (
      (X: 0; Y: 0; W: 8; H: 3; R: 38; G: 110; B: 38),
      (X: 1; Y: 1; W: 2; H: 2; R: 50; G: 130; B: 48),
      (X: 5; Y: 0; W: 2; H: 2; R: 44; G: 120; B: 42));

   { ── Biome identifiers ───────────────────────────────────────────────── }
   BIOME_PLAINS = 0;
   BIOME_DESERT = 1;
   BIOME_FOREST = 2;

   { ── Demo camera defaults ────────────────────────────────────────────── }
   DEMO_ZOOM_WIDE = 0.25;
   DEMO_ZOOM_MIN = 0.08;
   DEMO_ZOOM_MAX = 2.0;
   DEMO_SCROLL_SPD = 320;

   { ── Virtual canvas ──────────────────────────────────────────────────── }
   VIRT_W = 1280;
   VIRT_H = 720;

   CHUNK_TILES_W = 32;
   CHUNK_TILES_H = 32;
   CHUNK_PIXEL_W = CHUNK_TILES_W * TILE_SIZE;
   CHUNK_PIXEL_H = CHUNK_TILES_H * TILE_SIZE;

   { ── Light system ────────────────────────────────────────────────────── }
   LM_HASH_BUCKETS = 1024;
   LM_HASH_P1 = 73856093;
   LM_HASH_P2 = 19349663;
   LM_QUEUE_CAP = 1048576;
   MAX_ALL_CHUNKS = 512;

implementation

end.
