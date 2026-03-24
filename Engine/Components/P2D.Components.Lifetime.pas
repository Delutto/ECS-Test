unit P2D.Components.Lifetime;

{$mode objfpc}
{$H+}

interface

uses
   P2D.Core.Component;

type
  // ── Callbacks ──────────────────────────────────────────────────────────────
   TOnExpiredProc = procedure(AEntityID: Cardinal) of object;

  // ── Component ─────────────────────────────────────────────────────────────
  { TLifetimeComponent2D
    Attach to any entity that should be automatically destroyed after a
    given number of seconds.  The TLifetimeSystem reads this component
    every frame, decrements Remaining, and calls World.DestroyEntity when
    it reaches zero.

    Optional OnExpired callback fires BEFORE destruction, allowing the game
    to publish events (e.g. spawn score popup, play SFX) without coupling
    the system to game-specific logic. }
   TLifetimeComponent2D = class(TComponent2D)
   public
      Duration: Single;         // total lifetime in seconds  (set once)
      Remaining: Single;         // seconds left (decremented by system)
      Paused: Boolean;        // when True the countdown stops
      OnExpired: TOnExpiredProc; // optional; called just before DestroyEntity

      constructor Create; override;
      procedure Reset;            // restores Remaining := Duration
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TLifetimeComponent2D.Create;
begin
   inherited Create;

   Duration := 1.0;
   Remaining := 1.0;
   Paused := False;
   OnExpired := nil;
end;

procedure TLifetimeComponent2D.Reset;
begin
   Remaining := Duration;
   Paused := False;
end;

initialization
   ComponentRegistry.Register(TLifetimeComponent2D);

end.
