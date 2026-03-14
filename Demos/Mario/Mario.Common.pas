unit Mario.Common;

{$mode ObjFPC}{$H+}

interface

const
   { ── Audio assets ──────────────────────────────────────────────────────── }
   SFX_COIN      = 'assets/audio/sfx/coin.wav';
   SFX_STOMP     = 'assets/audio/sfx/stomp.wav';
   SFX_DAMAGE    = 'assets/audio/sfx/damage.wav';
   SFX_GAMEOVER  = 'assets/audio/sfx/gameover.wav';
   SFX_JUMP      = 'assets/audio/sfx/jump.wav';
   SFX_SPIN      = 'assets/audio/sfx/spinjump.wav';
   BGM_OVERWORLD = 'assets/audio/bgm/overworld.mp3';

   { ── Font assets ───────────────────────────────────────────────────────────
    The HUD System attempts to load FONT_HUD at FONT_HUD_SIZE pixels via
    TResourceManager2D.  If the file is absent the engine falls back to
    raylib's built-in default font automatically — the game still runs. }
   FONT_HUD      = 'assets/fonts/pressstart2p.ttf';
   FONT_HUD_SIZE = 8;  { Rasterisation size in pixels (scaled at draw time)  }

   { ── Shader assets ────────────────────────────────────────────────────────
    SHADER_VS_CRT  : empty string  → raylib uses its own default vertex shader
                     (compatible with FS_CRT_VIGNETTE inputs: fragTexCoord,
                     fragColor).  Supply a real path here only if you write
                     a custom vertex shader.

    SHADER_FS_CRT  : path to the fragment shader file on disk.
                     The ResourceManager returns Default(TShader) and logs
                     an error if the file is missing; IsShaderReady() will
                     return False and the overlay is silently skipped.

    SHADER_KEY_CRT : cache key used inside TResourceManager2D.               }
   SHADER_VS_CRT  = '';
   SHADER_FS_CRT  = 'assets/shaders/crt_vignette.fs';
   SHADER_KEY_CRT = 'crt_vignette_scanline';

   { ── Player sprite sheet ──────────────────────────────────────────────── }
   PLAYER_SHEET_PATH = 'assets/graphics/mario.png';
   FRAME_W           = 16;
   FRAME_H           = 24;

   { ── Coin sprite sheet ────────────────────────────────────────────────── }
   COIN_SHEET_PATH = 'assets/graphics/coin.png';

   { ── Input map name ───────────────────────────────────────────────────── }
   PLAYER_MAP = 'Player1';

   { ── Player movement constants ────────────────────────────────────────── }
   ACCEL_WALK     = 400.0;
   ACCEL_RUN      = 600.0;
   ACCEL_AIR      = 300.0;
   FRICTION_GND   = 500.0;
   FRICTION_SKID  = 550.0;
   FRICTION_AIR   = 50.0;
   SKID_THRESHOLD = 50.0;
   CHECK_DIST     = 10.0;

   { ── Player spawn / kill zone ─────────────────────────────────────────── }
   PLAYER_SPAWN_X   : Single = 48.0;
   PLAYER_SPAWN_Y   : Single = 100.0;
   PLAYER_KILL_ZONE : Single = 400.0;
   RESPAWN_INV_TIME : Single = 2.5;

   { ── Enemy constants ──────────────────────────────────────────────────── }
   GOOMBA_WALL_COOLDOWN = 0.25;

   { ── Level map ────────────────────────────────────────────────────────────
    0 = air          1 = solid ground
    2 = semi-solid   3 = ? block (solid)                                    }
   LEVEL_MAP: array[0..14] of string = (
                              { Row  0 } '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
                              { Row  1 } '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
                              { Row  2 } '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
                              { Row  3 } '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
                              { Row  4 } '0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,0,0,0,0,0,0,0,0,3,3,3,0,0,0',
                              { Row  5 } '0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
                              { Row  6 } '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0',
                              { Row  7 } '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
                              { Row  8 } '0,0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
                              { Row  9 } '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
                              { Row 10 } '0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0',
                              { Row 11 } '1,1,1,1,1,0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0,0,0,1,1',
                              { Row 12 } '1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1',
                              { Row 13 } '1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1',
                              { Row 14 } '1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1');

implementation

end.

