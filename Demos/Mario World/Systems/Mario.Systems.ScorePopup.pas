unit Mario.Systems.ScorePopup;

{$mode objfpc}{$H+}

{ ── Score popup system ──────────────────────────────────────────────────────
  Spawns short-lived floating text entities (+100, +200, COIN!) over
  the world position of stomped enemies and collected coins.

  Depends on the four new engine components:
    TTextComponent2D       (P2D.Components.Text)
    TLifetimeComponent2D   (P2D.Components.Lifetime)
    TTweenComponent2D      (P2D.Components.Tween)
    TTransformComponent    (already in the engine)
  ─────────────────────────────────────────────────────────────────────────── }

interface

uses
  SysUtils, raylib,
  Mario.Events,
  Mario.Common,
  P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World, P2D.Core.Event,
  P2D.Components.Transform, P2D.Components.Text, P2D.Components.Lifetime, P2D.Components.Tween;

type
  TScorePopupSystem = class(TSystem2D)
  private
    procedure OnEnemyStomp(AEvent: TEvent2D);
    procedure OnCoinCollected(AEvent: TEvent2D);
    procedure SpawnPopup(AWorldX, AWorldY: Single; const AText: string; AColor: TColor);
  public
    constructor Create(AWorld: TWorldBase); override;
    procedure Init; override;
    procedure Shutdown; override;
  end;

implementation

constructor TScorePopupSystem.Create(AWorld: TWorldBase);
begin
  inherited Create(AWorld);

  Priority    := 26;    // after TGameRulesSystem (25), before TTileMapSystem (30)
  Name        := 'ScorePopupSystem';
  RenderLayer := rlWorld; // popups live in world space
end;

procedure TScorePopupSystem.Init;
begin
  inherited;
  // No RequireComponent — this system works entirely through events.
  World.EventBus.Subscribe(TEnemyStompedEvent,  @OnEnemyStomp);
  World.EventBus.Subscribe(TCoinCollectedEvent, @OnCoinCollected);
end;

procedure TScorePopupSystem.Shutdown;
begin
  World.EventBus.Unsubscribe(TEnemyStompedEvent,  @OnEnemyStomp);
  World.EventBus.Unsubscribe(TCoinCollectedEvent, @OnCoinCollected);

  inherited;
end;

// ─────────────────────────────────────────────────────────────────────────────
// SpawnPopup — creates a self-contained, auto-destroying text entity.
// ─────────────────────────────────────────────────────────────────────────────
procedure TScorePopupSystem.SpawnPopup(AWorldX, AWorldY: Single; const AText: string; AColor: TColor);
const
  POPUP_DURATION = 0.85;   // seconds the label is visible
  POPUP_RISE     = 24.0;   // pixels it rises upward during its lifetime
var
  E  : TEntity;
  Tr : TTransformComponent;
  TC : TTextComponent2D;
  LT : TLifetimeComponent2D;
  TW : TTweenComponent2D;
begin
  E := World.CreateEntity('ScorePopup');

  // ── Transform: world position of the source (enemy/coin) ─────────────────
  Tr            := TTransformComponent.Create;
  Tr.Position.X := AWorldX;
  Tr.Position.Y := AWorldY;
  Tr.Scale.X    := 1.0;
  Tr.Scale.Y    := 1.0;
  E.AddComponent(Tr);

  // ── Text: the label to display ────────────────────────────────────────────
  TC           := TTextComponent2D.Create;
  TC.Text      := AText;
  TC.FontKey   := FONT_HUD;      // reuses the same pixel font as the HUD
  TC.FontSize  := 8.0;
  TC.Color     := AColor;
  TC.Alignment := taCenter;
  TC.ZOrder    := 150;           // above sprites (Z=10) but below HUD (rlScreen)
  TC.Shadow    := True;
  E.AddComponent(TC);

  // ── Lifetime: entity auto-destroys after POPUP_DURATION seconds ───────────
  LT           := TLifetimeComponent2D.Create;
  LT.Duration  := POPUP_DURATION;
  LT.Remaining := POPUP_DURATION;
  E.AddComponent(LT);

  // ── Tween: animate upward rise with an ease-out curve ────────────────────
  // We tween Position.Y from current Y to (Y - POPUP_RISE).
  // The pointer @Tr.Position.Y is valid for the lifetime of Tr (this entity).
  TW := TTweenComponent2D.Create;
  TW.Start('rise',
            @Tr.Position.Y,
            AWorldY,
            AWorldY - POPUP_RISE,
            POPUP_DURATION,
            @EaseOutQuad,
            {Loop=}False, {PingPong=}False, {OnComplete=}nil);
  E.AddComponent(TW);
end;

// ─────────────────────────────────────────────────────────────────────────────
procedure TScorePopupSystem.OnEnemyStomp(AEvent: TEvent2D);
var
  Ev: TEnemyStompedEvent;
begin
  Ev := TEnemyStompedEvent(AEvent);
  SpawnPopup(Ev.WorldX, Ev.WorldY,
             '+' + IntToStr(Ev.ScoreGained),
             ColorCreate(255, 240, 50, 255));   // bright yellow
end;

procedure TScorePopupSystem.OnCoinCollected(AEvent: TEvent2D);
begin
  SpawnPopup(TCoinCollectedEvent(AEvent).WorldX,
             TCoinCollectedEvent(AEvent).WorldY,
             'COIN!',
             ColorCreate(255, 215, 0, 255));    // gold
end;

end.
