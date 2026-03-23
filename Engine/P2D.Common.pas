unit P2D.Common;

{$mode ObjFPC}{$H+}

interface

const
   // P2D.Core.Engine
   FIXED_DT  = 1.0 / 60.0; // passo físico fixo (60 Hz)
   MAX_DELTA = 0.25;       // teto de delta — evita "spiral of death"

   // P2D.Components.TileMap
   TILE_NONE   = 0;
   TILE_SOLID  = 1;
   TILE_SEMI   = 2;  { One-way / semi-solid: blocks only when falling DOWN onto the top surface }
   TILE_HAZARD = 3;
   TILE_COIN   = 4;
   TILE_GOAL   = 5;

   // P2D.Systems.Physics
   GRAVITY = 980.0; // pixels per second squared

   // P2D.Core.Entity
   MAX_COMPONENT_TYPES = 64;  // Limite de tipos de componentes (0-63)

   // P2D.Components.RigidBody
   DEFAULT_COYOTE_TIME  : Single = 10 / 60; { Default coyote-time window: 10 frames at 60 Hz = 0.1667 s }
   DEFAULT_JUMP_BUFFER  : Single = 8 / 60;  { Default jump-buffer window: 8 frames at 60 Hz = 0.1333 s }

implementation

end.
