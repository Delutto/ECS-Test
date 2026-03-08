unit Mario.Events;

{$mode ObjFPC}{$H+}

{ ============================================================================
  Eventos específicos do demo Mario.
  Todos herdam de TEvent2D e carregam apenas dados imutáveis.
  O TAudioSystem reage aos eventos de gameplay publicando os eventos de
  áudio correspondentes — sem acoplamento entre gameplay e áudio.
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
    constructor Create(ACoins, AScore: Integer);
  end;

  TPlayerDamagedEvent = class(TEvent2D)
  public
    LivesRemaining : Integer;
    constructor Create(ALives: Integer);
  end;

  { TPlayerJumpEvent }

  TPlayerJumpEvent = class(TEvent2D)
  public
    constructor Create;
  end;

  TEnemyStompedEvent = class(TEvent2D)
  public
    ScoreGained : Integer;
    NewScore    : Integer;
    constructor Create(AScoreGained, ANewScore: Integer);
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

constructor TCoinCollectedEvent.Create(ACoins, AScore: Integer);
begin
  inherited Create;
  NewCoins := ACoins;
  NewScore := AScore;
end;

constructor TPlayerDamagedEvent.Create(ALives: Integer);
begin
  inherited Create;
  LivesRemaining := ALives;
end;

{ TPlayerJumpEvent }

constructor TPlayerJumpEvent.Create;
begin
   inherited Create;
end;

constructor TEnemyStompedEvent.Create(AScoreGained, ANewScore: Integer);
begin
  inherited Create;
  ScoreGained := AScoreGained;
  NewScore    := ANewScore;
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
