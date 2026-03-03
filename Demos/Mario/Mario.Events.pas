unit Mario.Events;

{$mode objfpc}{$H+}

{ Eventos específicos do demo Mario.
  Definidos no nível do demo, não da engine — a engine não conhece
  regras de jogo. Sistemas publicam; outros sistemas/futuras features reagem. }

interface

uses
   P2D.Core.Event,
   P2D.Core.Types;

type
   { Jogador coletou uma moeda. }
   TCoinCollectedEvent = class(TEvent2D)
   public
      NewCoins: Integer; // total de moedas após a coleta
      NewScore: Integer; // pontuação após a coleta
      constructor Create(ACoins, AScore: Integer);
   end;

   { Jogador foi atingido por um inimigo. }
   TPlayerDamagedEvent = class(TEvent2D)
   public
      LivesRemaining: Integer;
      constructor Create(ALives: Integer);
   end;

   { Jogador pisou em um inimigo. }
   TEnemyStompedEvent = class(TEvent2D)
   public
      ScoreGained: Integer;
      NewScore   : Integer;
      constructor Create(AScoreGained, ANewScore: Integer);
   end;

   { Jogador perdeu todas as vidas. }
   TPlayerDiedEvent = class(TEvent2D)
   public
         constructor Create;
   end;

   { Jogador respawnou após perder uma vida. }
   TPlayerRespawnedEvent = class(TEvent2D)
   public
      LivesRemaining: Integer;
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
