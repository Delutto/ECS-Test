unit Mario.Common;

{$mode ObjFPC}{$H+}

interface

const
   { Áudios do demo }
   SFX_COIN     = 'assets/audio/sfx/coin.wav';
   SFX_STOMP    = 'assets/audio/sfx/stomp.wav';
   SFX_DAMAGE   = 'assets/audio/sfx/damage.wav';
   SFX_GAMEOVER = 'assets/audio/sfx/gameover.wav';
   SFX_JUMP     = 'assets/audio/sfx/jump.wav';
   BGM_OVERWORLD = 'assets/audio/bgm/Overworld.mp3';

   { Player Sprite sheet }
   PLAYER_SHEET_PATH = 'assets/graphics/mario.png';
   { Configurações do Sprite Sheet }
   FRAME_W = 16;
   FRAME_H = 24;

   { Nome do mapa — referenciado ao criar a entidade Player }
   PLAYER_MAP = 'Player1';
  
   MOVE_SPEED = 120.0;
   RUN_SPEED  = 200.0;
   JUMP_FORCE = -350.0;

   // Increased tolerance to prevent flickering when on ground
   // Gravity is constantly pushing down, so Y might be small positive number.
   VEL_EPSILON_X = 5.0;
   VEL_EPSILON_Y = 10.0;

   // How long (in seconds) Y velocity must be non-zero to consider "Airborne"
   // 0.05s is about 3 frames at 60fps. Filters out 1-frame glitches.
   COYOTE_TIME = 0.05;

   // !!! Check ground !!!
   CHECK_DIST = 10.0;

   PLAYER_SPAWN_X   : Single = 48.0;
   PLAYER_SPAWN_Y   : Single = 100.0;
   PLAYER_KILL_ZONE : Single = 400.0;
   RESPAWN_INV_TIME : Single = 2.5;

   { Minimum time (seconds) before the Goomba is allowed to flip direction again after hitting a wall. Prevents rapid
   oscillation when the physics solver keeps the collider touching the tile surface for more than one Update frame. }
   GOOMBA_WALL_COOLDOWN = 0.25;
  

implementation

end.
