unit Mario.Events;

{$mode ObjFPC}
{$H+}

interface

uses
   P2D.Core.Event;

type
   TCoinCollectedEvent = class(TEvent2D)
   public
      NewCoins: Integer;
      NewScore: Integer;
      WorldX: Single;
      WorldY: Single;
      constructor Create(ACoins, AScore: Integer; AWorldX: Single = 0; AWorldY: Single = 0);
   end;

   TPlayerDamagedEvent = class(TEvent2D)
   public
      LivesRemaining: Integer;
      constructor Create(ALives: Integer);
   end;

   TPlayerJumpEvent = class(TEvent2D)
   public
      constructor Create;
   end;

   TPlayerSpinEvent = class(TEvent2D)
   public
      constructor Create;
   end;

   TPlayerDiedEvent = class(TEvent2D)
   public
      constructor Create;
   end;

   TEnemyStompedEvent = class(TEvent2D)
   public
      ScoreGained: Integer;
      NewScore: Integer;
      WorldX: Single;
      WorldY: Single;
      constructor Create(AScoreGained, ANewScore: Integer; AWorldX: Single = 0; AWorldY: Single = 0);
   end;

   TPlayerRespawnedEvent = class(TEvent2D)
   public
      LivesRemaining: Integer;
      constructor Create(ALives: Integer);
   end;

  { ── NEW: fired when the player reaches the level goal ───────────────────── }
   TLevelCompleteEvent = class(TEvent2D)
   public
      LevelNumber: Integer;  { 1 = overworld, 2 = underwater, etc. }
      constructor Create(ALevel: Integer);
   end;

implementation

constructor TCoinCollectedEvent.Create(ACoins, AScore: Integer; AWorldX, AWorldY: Single);
begin
   inherited Create;
   NewCoins := ACoins;
   NewScore := AScore;
   WorldX := AWorldX;
   WorldY := AWorldY;
end;

constructor TPlayerDamagedEvent.Create(ALives: Integer);
begin
   inherited Create;
   LivesRemaining := ALives;
end;

constructor TPlayerJumpEvent.Create;
begin
   inherited Create;
end;

constructor TPlayerSpinEvent.Create;
begin
   inherited Create;
end;

constructor TPlayerDiedEvent.Create;
begin
   inherited Create;
end;

constructor TEnemyStompedEvent.Create(AScoreGained, ANewScore: Integer; AWorldX, AWorldY: Single);
begin
   inherited Create;
   ScoreGained := AScoreGained;
   NewScore := ANewScore;
   WorldX := AWorldX;
   WorldY := AWorldY;
end;

constructor TPlayerRespawnedEvent.Create(ALives: Integer);
begin
   inherited Create;
   LivesRemaining := ALives;
end;

constructor TLevelCompleteEvent.Create(ALevel: Integer);
begin
   inherited Create;
   LevelNumber := ALevel;
end;

end.
