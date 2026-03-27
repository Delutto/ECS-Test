unit Terraria.Common;

{$mode objfpc}{$H+}

{ Shared constants, tile type definitions and palette colours
  for the Terraria procedural map demo. }
interface

type
   { ── Helpers ─────────────────────────────────────────────────────────────── }
   { Build one 8×8 tile image with a base colour and a 1-pixel highlight/shadow on the top-left.  AVar rectangles add visual texture. }
   TRect4 = record
      X, Y, W, H, R, G, B: Integer;
   end;

const
   { ── World dimensions ──────────────────────────────────────────────────── }
   MAP_WIDTH = 2048;   { tiles horizontally }
   MAP_HEIGHT = 256;   { tiles vertically   }
   TILE_SIZE = 8;     { pixels per tile in world space }

   { ── Surface generation parameters ────────────────────────────────────── }
   BASE_SURFACE = 48;    { average surface row (tiles from top) }
   SURFACE_AMP = 14;    { ±amplitude of surface variation (tiles) }
   MIN_SURFACE = 20;    { hard ceiling for surface height }
   MAX_SURFACE = 70;    { hard floor for surface height }

   { ── Depth thresholds (rows BELOW surfaceY) ────────────────────────────── }
   DEPTH_DIRT = 6;    { dirt above this depth }
   DEPTH_DIRT_STONE = 22;   { mixed dirt+stone up to here }
   DEPTH_STONE = 80;   { pure stone zone }
   { below DEPTH_STONE: granite / marble / bedrock }

   { ── Cave parameters ──────────────────────────────────────────────────── }
   CAVE_START_DEPTH = 6;    { caves only below this many tiles under surface }
   CAVE_THRESHOLD = 0.14; { absolute noise threshold for worm-cave carving }

   { ── Tile type byte codes ──────────────────────────────────────────────── }
   TILE_AIR = 0;
   TILE_DIRT = 1;
   TILE_GRASS = 2;   { dirt with grass on the exposed top face }
   TILE_STONE = 3;
   TILE_SAND = 4;
   TILE_SANDSTONE = 5;
   TILE_GRANITE = 6;
   TILE_MARBLE = 7;
   TILE_CLAY = 8;
   TILE_GRAVEL = 9;
   TILE_BEDROCK = 10;
   TILE_COUNT = 11;

   TILE_DIRT_RGB: array[0..2] of TRect4 =      ((X: 2; Y: 2; W: 3; H: 2; R: 142; G: 100; B: 62),
                                                (X: 0; Y: 5; W: 2; H: 2; R: 112; G: 76; B: 44),
                                                (X: 5; Y: 4; W: 3; H: 3; R: 138; G: 95; B: 58));

   TILE_STONE_RGB: array[0..3] of TRect4 =     ((X: 1; Y: 2; W: 2; H: 1; R: 98; G: 98; B: 98),
                                                (X: 4; Y: 1; W: 3; H: 2; R: 136; G: 136; B: 136),
                                                (X: 0; Y: 5; W: 2; H: 3; R: 102; G: 102; B: 102),
                                                (X: 5; Y: 5; W: 3; H: 2; R: 130; G: 130; B: 130));

   TILE_SAND_RGB: array[0..2] of TRect4 =      ((X: 1; Y: 2; W: 4; H: 1; R: 210; G: 190; B: 128),
                                                (X: 3; Y: 4; W: 3; H: 2; R: 180; G: 158; B: 96),
                                                (X: 0; Y: 6; W: 2; H: 2; R: 204; G: 182; B: 118));

   TILE_SANDSTONE_RGB: array[0..2] of TRect4 = ((X: 0; Y: 2; W: 8; H: 1; R: 148; G: 122; B: 68),   { horizontal strata }
                                                (X: 0; Y: 5; W: 8; H: 1; R: 148; G: 122; B: 68),
                                                (X: 2; Y: 3; W: 3; H: 1; R: 180; G: 156; B: 100));

   TILE_GRANITE_RGB: array[0..2] of TRect4 =   ((X: 2; Y: 1; W: 2; H: 2; R: 152; G: 148; B: 170),   { sparkle }
                                                (X: 5; Y: 4; W: 1; H: 1; R: 158; G: 154; B: 176),
                                                (X: 1; Y: 5; W: 2; H: 2; R: 68; G: 64; B: 80));

   TILE_MARBLE_RGB: array[0..2] of TRect4 =    ((X: 1; Y: 2; W: 1; H: 5; R: 172; G: 164; B: 180),   { vein }
                                                (X: 4; Y: 1; W: 1; H: 4; R: 160; G: 152; B: 170),
                                                (X: 6; Y: 4; W: 2; H: 3; R: 194; G: 188; B: 202));

   TILE_CLAY_RGB: array[0..2] of TRect4 =      ((X: 1; Y: 1; W: 3; H: 2; R: 168; G: 96; B: 72),
                                                (X: 4; Y: 4; W: 3; H: 3; R: 140; G: 74; B: 54),
                                                (X: 0; Y: 5; W: 2; H: 2; R: 130; G: 68; B: 50));

   TILE_GRAVEL_RGB: array[0..3] of TRect4 =    ((X: 0; Y: 0; W: 3; H: 3; R: 124; G: 120; B: 116),
                                                (X: 4; Y: 0; W: 4; H: 4; R: 100; G: 96; B: 92),
                                                (X: 1; Y: 4; W: 3; H: 4; R: 118; G: 114; B: 110),
                                                (X: 5; Y: 5; W: 3; H: 3; R: 96; G: 92; B: 88));

   TILE_BEDROCK_RGB: array[0..2] of TRect4 =   ((X: 2; Y: 1; W: 2; H: 2; R: 42; G: 38; B: 48),
                                                (X: 5; Y: 3; W: 2; H: 2; R: 38; G: 34; B: 44),
                                                (X: 1; Y: 5; W: 3; H: 2; R: 20; G: 18; B: 24));


   { ── Biome identifiers ─────────────────────────────────────────────────── }
   BIOME_PLAINS = 0;
   BIOME_DESERT = 1;
   BIOME_FOREST = 2;

   { ── Demo camera defaults ─────────────────────────────────────────────── }
   DEMO_ZOOM_WIDE = 0.25;  { initial zoom to see the full map }
   DEMO_ZOOM_MIN = 0.08;
   DEMO_ZOOM_MAX = 2.0;
   DEMO_SCROLL_SPD = 320;   { world-pixels / second camera pan speed }

   { ── Virtual canvas resolution for the Terraria demo ─────────────────── }
   VIRT_W = 1280;
   VIRT_H = 720;

implementation

end.
