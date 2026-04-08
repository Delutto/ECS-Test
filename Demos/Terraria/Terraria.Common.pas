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
     TILE_SHRUB (14) is the decoration boundary — every ID >= TILE_SHRUB and
     < TILE_WATER is a transparent decoration tile rendered via procedurally-
     generated textures.

     IDs 26–28 are LIQUID tiles. They are rendered by TLiquidRenderer as
     coloured, semi-transparent quads with optional animation. They are NOT
     in the soil spritesheet (SOIL_SHEET_ROW = -1 for all liquid IDs) and
     NOT in the FTex/FTexBG procedural-texture arrays used for decorations.
     TChunkRenderSystem skips liquid IDs in its standard tile loop; the
     liquid rendering is handled by TLiquidRenderer.RenderChunk.
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
   TILE_MUD = 11;
   TILE_SNOW = 12;
   TILE_ICE = 13;

   { ── Decoration boundary ─────────────────────────────────────────────── }
   TILE_SHRUB = 14;

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

   { ── LIQUID tiles (IDs 26–28) ─────────────────────────────────────────
     These tiles occupy foreground cells (SetFG/GetFG) and are rendered
     as coloured transparent quads by TLiquidRenderer, NOT by the standard
     soil/decor tile pipeline.

     TILE_LIQUID_BOUNDARY marks the first liquid ID so the renderer and
     collision systems can quickly identify liquid tiles with a single
     comparison: TileID >= TILE_LIQUID_BOUNDARY.

     Liquid tiles BLOCK neither pathfinding nor player collision by default;
     game systems that want "swimming" behaviour should check for them
     explicitly using HasComponent(TLiquidTrigger) or similar.
     ──────────────────────────────────────────────────────────────────── }
   TILE_LIQUID_BOUNDARY = 26;   { first liquid tile ID                      }
   TILE_WATER = 26;       { fresh water (surface lakes, cave lakes)   }
   TILE_LAVA = 27;        { molten lava (deep zone pools)             }
   TILE_MUD_WATER = 28;   { muddy/swampy water (forest biome)         }

   TILE_COUNT = 29;   { total number of tile types (updated from 26)        }

   { =========================================================================
     BIOME CONSTANTS
     ========================================================================= }
   BIOME_PLAINS = 0;
   BIOME_DESERT = 1;
   BIOME_FOREST = 2;

   { =========================================================================
     CHUNK DIMENSIONS
     =========================================================================
     These constants define the tile dimensions of each TWorldChunk.
     CHUNK_PIXEL_W and CHUNK_PIXEL_H are the pixel dimensions used by the
     renderer to compute world-space positions.
     ========================================================================= }
   CHUNK_TILES_W = 32;
   CHUNK_TILES_H = 32;
   CHUNK_PIXEL_W = CHUNK_TILES_W * TILE_SIZE;
   CHUNK_PIXEL_H = CHUNK_TILES_H * TILE_SIZE;

   { Virtual screen dimensions (must match TTerrariaDemoGame.Create) }
   VIRT_W = 1280;
   VIRT_H = 720;

   { =========================================================================
     SOIL SPRITESHEET — soils_better_16x16.png
     =========================================================================
     Layout: 4 columns × 13 rows, each cell is 16×16 pixels.
       Columns 0–3  = four visual variations of the same soil type.
       Rows 0–12    = one soil type per row (see SOIL_SHEET_ROW below).
     ========================================================================= }
   SOIL_SHEET_PATH = 'assets/graphics/soils_better_16x16.png';
   SOIL_SHEET_TILE = 16;
   SOIL_SHEET_COLS = 4;
   SOIL_SHEET_ROWS = 13;

   { Background dim factor for soil tiles rendered in the wall layer }
   SOIL_BG_DIM: Single = 0.45;

   { Maps tile ID → spritesheet row.
     -1 = tile is not in the spritesheet.
     Liquid tiles (26–28) are also -1 because they use TLiquidRenderer. }
   SOIL_SHEET_ROW: array[0..TILE_COUNT - 1] of shortint = (-1,   {  0: TILE_AIR        }
      1,    {  1: TILE_DIRT       }
      0,    {  2: TILE_GRASS      }
      2,    {  3: TILE_STONE      }
      3,    {  4: TILE_SAND       }
      4,    {  5: TILE_SANDSTONE  }
      5,    {  6: TILE_GRANITE    }
      6,    {  7: TILE_MARBLE     }
      7,    {  8: TILE_CLAY       }
      9,    {  9: TILE_GRAVEL     }
      12,   { 10: TILE_BEDROCK    }
      8,    { 11: TILE_MUD        }
      10,   { 12: TILE_SNOW       }
      11,   { 13: TILE_ICE        } -1,   { 14: TILE_SHRUB      } -1,   { 15: TILE_TREE_TRUNK } -1,   { 16: TILE_TREE_LEAF  } -1,   { 17: TILE_CACTUS     } -1,
      { 18: TILE_CACTUS_TOP } -1,   { 19: TILE_FERN       } -1,   { 20: TILE_ROOT       } -1,   { 21: TILE_VINE       } -1,   { 22: TILE_STALACTITE } -1,
      { 23: TILE_STALAGMITE } -1,   { 24: TILE_MUSHROOM   } -1,   { 25: TILE_MOSS       } -1,   { 26: TILE_WATER      — rendered by TLiquidRenderer } -1,
      { 27: TILE_LAVA       — rendered by TLiquidRenderer } -1    { 28: TILE_MUD_WATER  — rendered by TLiquidRenderer }
      );

   { =========================================================================
     DECORATION SPRITE DATA (unchanged from original)
     RGB detail rectangles for procedural decor textures.
     ========================================================================= }

   TILE_SHRUB_RGB: array[0..2] of TRect4 = (
      (X: 1; Y: 2; W: 6; H: 4; R: 60; G: 160; B: 40),
      (X: 2; Y: 0; W: 4; H: 3; R: 50; G: 140; B: 30),
      (X: 3; Y: 4; W: 2; H: 2; R: 70; G: 180; B: 50)
      );

   TILE_TREE_TRUNK_RGB: array[0..1] of TRect4 = (
      (X: 2; Y: 0; W: 4; H: 8; R: 110; G: 72; B: 40),
      (X: 3; Y: 2; W: 1; H: 4; R: 90; G: 55; B: 28)
      );

   TILE_TREE_LEAF_RGB: array[0..2] of TRect4 = (
      (X: 0; Y: 1; W: 8; H: 6; R: 40; G: 130; B: 36),
      (X: 1; Y: 0; W: 6; H: 2; R: 55; G: 150; B: 45),
      (X: 2; Y: 5; W: 4; H: 2; R: 30; G: 110; B: 28)
      );

   TILE_CACTUS_RGB: array[0..1] of TRect4 = (
      (X: 2; Y: 0; W: 4; H: 8; R: 60; G: 140; B: 40),
      (X: 1; Y: 1; W: 1; H: 6; R: 80; G: 160; B: 50)
      );

   TILE_CACTUS_TOP_RGB: array[0..0] of TRect4 = (
      (X: 1; Y: 0; W: 6; H: 8; R: 60; G: 140; B: 40)
      );

   TILE_FERN_RGB: array[0..2] of TRect4 = (
      (X: 0; Y: 3; W: 8; H: 5; R: 40; G: 120; B: 30),
      (X: 2; Y: 1; W: 4; H: 3; R: 55; G: 140; B: 40),
      (X: 1; Y: 0; W: 2; H: 2; R: 35; G: 100; B: 25)
      );

   TILE_ROOT_RGB: array[0..1] of TRect4 = (
      (X: 3; Y: 0; W: 2; H: 8; R: 100; G: 65; B: 30),
      (X: 1; Y: 3; W: 2; H: 3; R: 80; G: 50; B: 22)
      );

   TILE_VINE_RGB: array[0..1] of TRect4 = (
      (X: 3; Y: 0; W: 2; H: 8; R: 40; G: 130; B: 35),
      (X: 1; Y: 2; W: 2; H: 2; R: 55; G: 150; B: 45)
      );

   TILE_STALACTITE_RGB: array[0..1] of TRect4 = (
      (X: 2; Y: 0; W: 4; H: 6; R: 150; G: 140; B: 130),
      (X: 3; Y: 5; W: 2; H: 3; R: 120; G: 110; B: 100)
      );

   TILE_STALAGMITE_RGB: array[0..1] of TRect4 = (
      (X: 2; Y: 2; W: 4; H: 6; R: 150; G: 140; B: 130),
      (X: 3; Y: 1; W: 2; H: 3; R: 120; G: 110; B: 100)
      );

   TILE_MUSHROOM_RGB: array[0..2] of TRect4 = (
      (X: 2; Y: 4; W: 4; H: 4; R: 200; G: 80; B: 160),
      (X: 1; Y: 2; W: 6; H: 3; R: 220; G: 100; B: 180),
      (X: 3; Y: 6; W: 2; H: 2; R: 80; G: 200; B: 255)
      );

   TILE_MOSS_RGB: array[0..1] of TRect4 = (
      (X: 0; Y: 0; W: 8; H: 3; R: 40; G: 160; B: 50),
      (X: 1; Y: 2; W: 6; H: 2; R: 55; G: 180; B: 60)
      );

   { =========================================================================
     LIGHTING HASH TABLE CONSTANTS (used by Terraria.Lighting)
     ========================================================================= }
   LM_HASH_BUCKETS = 1024;
   LM_HASH_P1 = 73856093;
   LM_HASH_P2 = 19349663;
   LM_QUEUE_CAP = 131072;
   MAX_ALL_CHUNKS = 4096;

implementation

end.
