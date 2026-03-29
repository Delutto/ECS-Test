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

   { ── Terrain tile type byte codes ─────────────────────────────────────── }
   TILE_AIR = 0;
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

   { ── Vegetation / decoration tile type byte codes ─────────────────────── }
   { Surface vegetation — foreground layer }
   TILE_SHRUB = 11;   { small bush / grass tuft (plains)           }
   TILE_TREE_TRUNK = 12;   { tree trunk segment                         }
   TILE_TREE_LEAF = 13;   { tree leaf / canopy block                   }
   TILE_CACTUS = 14;   { cactus segment (desert)                    }
   TILE_CACTUS_TOP = 15;   { cactus top / arm                           }
   TILE_FERN = 16;   { forest fern / undergrowth                  }

   { Cave decorations — foreground layer (hang/grow on solid tiles) }
   TILE_ROOT = 17;   { root hanging down from ceiling             }
   TILE_VINE = 18;   { vine hanging down from ceiling             }
   TILE_STALACTITE = 19;   { mineral spike hanging from ceiling         }
   TILE_STALAGMITE = 20;   { mineral spike growing from floor           }
   TILE_MUSHROOM = 21;   { cave mushroom growing on floor             }
   TILE_MOSS = 22;   { moss patch on wall / ceiling               }

   TILE_COUNT = 23;  { total number of tile types                         }

   { ── Tile palette data (terrain tiles) ───────────────────────────────── }
   TILE_DIRT_RGB: array[0..2] of TRect4 = (
      (X: 2; Y: 2; W: 3; H: 2; R: 142; G: 100; B: 62),
      (X: 0; Y: 5; W: 2; H: 2; R: 112; G: 76; B: 44),
      (X: 5; Y: 4; W: 3; H: 3; R: 138; G: 95; B: 58));

   TILE_STONE_RGB: array[0..3] of TRect4 = (
      (X: 1; Y: 2; W: 2; H: 1; R: 98; G: 98; B: 98),
      (X: 4; Y: 1; W: 3; H: 2; R: 136; G: 136; B: 136),
      (X: 0; Y: 5; W: 2; H: 3; R: 102; G: 102; B: 102),
      (X: 5; Y: 5; W: 3; H: 2; R: 130; G: 130; B: 130));

   TILE_SAND_RGB: array[0..2] of TRect4 = (
      (X: 1; Y: 2; W: 4; H: 1; R: 210; G: 190; B: 128),
      (X: 3; Y: 4; W: 3; H: 2; R: 180; G: 158; B: 96),
      (X: 0; Y: 6; W: 2; H: 2; R: 204; G: 182; B: 118));

   TILE_SANDSTONE_RGB: array[0..2] of TRect4 = (
      (X: 0; Y: 2; W: 8; H: 1; R: 148; G: 122; B: 68),
      (X: 0; Y: 5; W: 8; H: 1; R: 148; G: 122; B: 68),
      (X: 2; Y: 3; W: 3; H: 1; R: 180; G: 156; B: 100));

   TILE_GRANITE_RGB: array[0..2] of TRect4 = (
      (X: 2; Y: 1; W: 2; H: 2; R: 152; G: 148; B: 170),
      (X: 5; Y: 4; W: 1; H: 1; R: 158; G: 154; B: 176),
      (X: 1; Y: 5; W: 2; H: 2; R: 68; G: 64; B: 80));

   TILE_MARBLE_RGB: array[0..2] of TRect4 = (
      (X: 1; Y: 2; W: 1; H: 5; R: 172; G: 164; B: 180),
      (X: 4; Y: 1; W: 1; H: 4; R: 160; G: 152; B: 170),
      (X: 6; Y: 4; W: 2; H: 3; R: 194; G: 188; B: 202));

   TILE_CLAY_RGB: array[0..2] of TRect4 = (
      (X: 1; Y: 1; W: 3; H: 2; R: 168; G: 96; B: 72),
      (X: 4; Y: 4; W: 3; H: 3; R: 140; G: 74; B: 54),
      (X: 0; Y: 5; W: 2; H: 2; R: 130; G: 68; B: 50));

   TILE_GRAVEL_RGB: array[0..3] of TRect4 = (
      (X: 0; Y: 0; W: 3; H: 3; R: 124; G: 120; B: 116),
      (X: 4; Y: 0; W: 4; H: 4; R: 100; G: 96; B: 92),
      (X: 1; Y: 4; W: 3; H: 4; R: 118; G: 114; B: 110),
      (X: 5; Y: 5; W: 3; H: 3; R: 96; G: 92; B: 88));

   TILE_BEDROCK_RGB: array[0..2] of TRect4 = (
      (X: 2; Y: 1; W: 2; H: 2; R: 42; G: 38; B: 48),
      (X: 5; Y: 3; W: 2; H: 2; R: 38; G: 34; B: 44),
      (X: 1; Y: 5; W: 3; H: 2; R: 20; G: 18; B: 24));

   { ── Vegetation and Cave decoration ──────────────────────────────────── }
   { TILE_SHRUB (11) — leafy green bush }
   TILE_SHRUB_RGB: array[0..3] of TRect4 = (
      (X: 1; Y: 3; W: 6; H: 4; R: 50; G: 150; B: 40),
      (X: 0; Y: 4; W: 8; H: 3; R: 60; G: 170; B: 50),
      (X: 2; Y: 2; W: 4; H: 2; R: 70; G: 160; B: 44),
      (X: 3; Y: 6; W: 2; H: 2; R: 100; G: 70; B: 40));

   { TILE_TREE_TRUNK (12) — brown wood column }
   TILE_TREE_TRUNK_RGB: array[0..3] of TRect4 = (
      (X: 2; Y: 0; W: 4; H: 8; R: 120; G: 80; B: 46),
      (X: 3; Y: 0; W: 2; H: 8; R: 130; G: 90; B: 52),
      (X: 2; Y: 2; W: 1; H: 2; R: 90; G: 58; B: 32),
      (X: 5; Y: 5; W: 1; H: 2; R: 90; G: 58; B: 32));

   { TILE_TREE_LEAF (13) — leafy green canopy }
   TILE_TREE_LEAF_RGB: array[0..0] of TRect4 = ((X: 0; Y: 0; W: 8; H: 8; R: 40; G: 130; B: 36));

   { TILE_CACTUS (14) — green spiky column }
   TILE_CACTUS_RGB: array[0..3] of TRect4 = (
      (X: 2; Y: 0; W: 4; H: 8; R: 50; G: 140; B: 50),
      (X: 1; Y: 2; W: 1; H: 1; R: 40; G: 120; B: 40),
      (X: 6; Y: 5; W: 1; H: 1; R: 40; G: 120; B: 40),
      (X: 3; Y: 0; W: 2; H: 8; R: 60; G: 160; B: 58));

   { TILE_CACTUS_TOP (15) — cactus top / arm end }
   TILE_CACTUS_TOP_RGB: array[0..2] of TRect4 = (
      (X: 2; Y: 2; W: 4; H: 6; R: 50; G: 140; B: 50),
      (X: 3; Y: 0; W: 2; H: 3; R: 60; G: 160; B: 58),
      (X: 3; Y: 0; W: 2; H: 1; R: 80; G: 180; B: 70));

   { TILE_FERN (16) — small forest fern }
   TILE_FERN_RGB: array[0..3] of TRect4 = (
      (X: 3; Y: 5; W: 2; H: 3; R: 80; G: 110; B: 40),
      (X: 1; Y: 3; W: 3; H: 3; R: 60; G: 140; B: 40),
      (X: 4; Y: 2; W: 3; H: 4; R: 55; G: 135; B: 38),
      (X: 2; Y: 1; W: 2; H: 2; R: 70; G: 150; B: 44));

   { TILE_ROOT (17) — brown root hanging from dirt ceiling }
   TILE_ROOT_RGB: array[0..2] of TRect4 = (
      (X: 3; Y: 0; W: 2; H: 8; R: 120; G: 80; B: 44),
      (X: 2; Y: 2; W: 1; H: 2; R: 100; G: 64; B: 34),
      (X: 5; Y: 5; W: 1; H: 2; R: 100; G: 64; B: 34));

   { TILE_VINE (18) — green vine hanging from stone }
   TILE_VINE_RGB: array[0..2] of TRect4 = (
      (X: 3; Y: 0; W: 2; H: 8; R: 44; G: 130; B: 44),
      (X: 1; Y: 3; W: 2; H: 2; R: 36; G: 110; B: 36),
      (X: 5; Y: 6; W: 2; H: 1; R: 36; G: 110; B: 36));

   { TILE_STALACTITE (19) — grey mineral spike from ceiling }
   TILE_STALACTITE_RGB: array[0..2] of TRect4 = (
      (X: 3; Y: 0; W: 2; H: 5; R: 130; G: 128; B: 140),
      (X: 3; Y: 5; W: 2; H: 2; R: 110; G: 108; B: 120),
      (X: 3; Y: 7; W: 2; H: 1; R: 90; G: 88; B: 100));

   { TILE_STALAGMITE (20) — grey spike growing from floor }
   TILE_STALAGMITE_RGB: array[0..2] of TRect4 = (
      (X: 3; Y: 3; W: 2; H: 5; R: 130; G: 128; B: 140),
      (X: 3; Y: 1; W: 2; H: 2; R: 110; G: 108; B: 120),
      (X: 3; Y: 0; W: 2; H: 1; R: 90; G: 88; B: 100));

   { TILE_MUSHROOM (21) — cave mushroom on floo }
   TILE_MUSHROOM_RGB: array[0..4] of TRect4 = (
      (X: 2; Y: 3; W: 4; H: 5; R: 200; G: 60; B: 140),   { stem }
      (X: 1; Y: 2; W: 6; H: 3; R: 220; G: 80; B: 160),   { cap }
      (X: 0; Y: 3; W: 8; H: 2; R: 240; G: 100; B: 180),  { cap brim }
      (X: 3; Y: 1; W: 2; H: 2; R: 200; G: 60; B: 140),   { cap top }
      (X: 2; Y: 6; W: 4; H: 2; R: 180; G: 170; B: 175)); { root base }

   { TILE_MOSS (22) — green moss patch on stone }
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

   CHUNK_TILES_W = 32;   { tiles per chunk, horizontal }
   CHUNK_TILES_H = 32;   { tiles per chunk, vertical   }
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
