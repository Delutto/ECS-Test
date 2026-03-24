unit Mario.Components.Swimmer;

{$mode objfpc}
{$H+}

{ =============================================================================
  TSwimmerComponent — marks an entity as subject to underwater physics.

  PHYSICS EXPANSION FEATURES DEMONSTRATED
  ─────────────────────────────────────────
  • LinearDragX / LinearDragY  — water resistance (high drag ≈ thick medium)
  • GravityScale               — near-zero: gentle buoyancy sinking
  • MaxFallSpeed               — low terminal velocity underwater
  • MaxSpeedX                  — capped swimming speed
  • AddForce                   — swim-up / swim-down thrust (continuous force)
  • Restitution                — slight bounce off coral walls

  The component stores the ORIGINAL land physics so TSwimSystem can restore
  them when the entity exits the water (future extension).
  ============================================================================= }

interface

uses
   P2D.Core.Component;

type
   TSwimmerComponent = class(TComponent2D)
   public
      { ── Underwater physics overrides ─────────────────────────────────────── }
      UnderwaterGravityScale: Single;  { ~0.12  — gentle sink              }
      UnderwaterDragX: Single;  { ~5.0   — strong horizontal drag   }
      UnderwaterDragY: Single;  { ~4.0   — strong vertical drag     }
      UnderwaterMaxFallSpeed: Single;  { ~60    — slow terminal velocity   }
      UnderwaterMaxSpeedX: Single;  { ~90    — capped swim speed        }
      UnderwaterRestitution: Single;  { ~0.15  — slight bounce off coral  }

      { ── Swim thrust forces ───────────────────────────────────────────────── }
      SwimUpForce: Single;  { applied every FixedUpdate while WantsJump  }
      SwimDownForce: Single;  { applied every FixedUpdate while WantsDuck  }

      { ── Saved land physics (for future surface-exit restore) ─────────────── }
      SavedGravityScale: Single;
      SavedDragX: Single;
      SavedDragY: Single;
      SavedMaxFallSpeed: Single;
      SavedMaxSpeedX: Single;
      SavedRestitution: Single;

      constructor Create; override;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TSwimmerComponent.Create;
begin
   inherited Create;

   UnderwaterGravityScale := 0.12;
   UnderwaterDragX := 5.0;
   UnderwaterDragY := 4.0;
   UnderwaterMaxFallSpeed := 60.0;
   UnderwaterMaxSpeedX := 90.0;
   UnderwaterRestitution := 0.15;
   SwimUpForce := -980.0;  { same magnitude as GRAVITY — neutral buoyancy when held }
   SwimDownForce := 600.0;
   SavedGravityScale := 1.0;
   SavedDragX := 0.0;
   SavedDragY := 0.0;
   SavedMaxFallSpeed := 600.0;
   SavedMaxSpeedX := 0.0;
   SavedRestitution := 0.0;
end;

initialization
   ComponentRegistry.Register(TSwimmerComponent);

end.
