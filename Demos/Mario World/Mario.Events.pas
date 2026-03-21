unit Mario.Events;

{$mode ObjFPC}{$H+}

{ ============================================================================
  Eventos específicos do demo Mario.
  Todos herdam de TEvent2D e carregam apenas dados imutáveis.
  ============================================================================ }

interface

uses
   P2D.Core.Event;

type
   { ── Eventos de gameplay ─────────────────────────────────────────────── }
   TCoinCollectedEvent = class(TEvent2D)
   public
      NewCoins : Integer;
      NewScore : Integer;
      { Position of the coin in world space — used by TScorePopupSystem. }
      WorldX   : Single;
      WorldY   : Single;
      constructor Create(ACoins, AScore: Integer; AWorldX: Single = 0; AWorldY: Single = 0);
   end;

   TPlayerDamagedEvent = class(TEvent2D)
   public
      LivesRemaining : Integer;
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

   TEnemyStompedEvent = class(TEvent2D)
   public
      ScoreGained : Integer;
      NewScore    : Integer;
      { Position of the stomped enemy in world space — used by TScorePopupSystem. }
      WorldX      : Single;
      WorldY      : Single;
      constructor Create(AScoreGained, ANewScore: Integer; AWorldX: Single = 0; AWorldY: Single = 0);
   end;

   TPlayerDiedEvent = class(TEvent2D)
   public
      constructor Create;
   end;

   TPlayerRespawnedEvent = class(TEvent2D)
   public
      LivesRemaining : Integer;
      constructor Create(ALives: Integer);
   end;

implementation

constructor TCoinCollectedEvent.Create(ACoins, AScore: Integer; AWorldX, AWorldY: Single);
begin
   inherited Create;

   NewCoins := ACoins;
   NewScore := AScore;
   WorldX   := AWorldX;
   WorldY   := AWorldY;
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

constructor TEnemyStompedEvent.Create(AScoreGained, ANewScore: Integer; AWorldX, AWorldY: Single);
begin
   inherited Create;

   ScoreGained := AScoreGained;
   NewScore    := ANewScore;
   WorldX      := AWorldX;
   WorldY      := AWorldY;
end;

constructor TPlayerDiedEvent.Create;
begin
  inherited Create;
end;

constructor TPlayerRespawnedEvent.Create(ALives: Integer);
begin
  inherited Create;

  LivesRemaining := ALives;
end;

end.
