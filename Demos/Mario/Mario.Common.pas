unit Mario.Common;

{$mode ObjFPC}{$H+}

interface

const
   { Áudios do demo }
   SFX_COIN      = 'assets/audio/sfx/coin.wav';
   SFX_STOMP     = 'assets/audio/sfx/stomp.wav';
   SFX_DAMAGE    = 'assets/audio/sfx/damage.wav';
   SFX_GAMEOVER  = 'assets/audio/sfx/gameover.wav';
   SFX_JUMP      = 'assets/audio/sfx/jump.wav';
   SFX_SPIN      = 'assets/audio/sfx/spinjump.wav';
   BGM_OVERWORLD = 'assets/audio/bgm/overworld.mp3';

   { Player Sprite sheet }
   PLAYER_SHEET_PATH = 'assets/graphics/mario.png';
   { Configurações do Sprite Sheet }
   FRAME_W = 16;
   FRAME_H = 24;

   { Nome do mapa — referenciado ao criar a entidade Player }
   PLAYER_MAP = 'Player1';

   ACCEL_WALK     = 400.0;
   ACCEL_RUN      = 600.0;
   ACCEL_AIR      = 300.0;
   FRICTION_GND   = 500.0;
   FRICTION_SKID  = 550.0; // Friction when turning around
   FRICTION_AIR   = 50.0;
   SKID_THRESHOLD = 50.0;   // Min speed to trigger skid state

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
