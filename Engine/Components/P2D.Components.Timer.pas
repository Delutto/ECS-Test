unit P2D.Components.Timer;

{$mode objfpc}{$H+}

{ ─────────────────────────────────────────────────────────────────────────────
  TTimerComponent2D — general-purpose multi-timer component.

  MOTIVATION
  ──────────
  The current codebase contains hand-rolled cooldown counters scattered
  across domain components (TGoombaComponent.WallCooldown, TPlayerComponent.InvFrames,
  etc.). Each uses a slightly different pattern, making the code harder to
  reuse and test.

  TTimerComponent2D centralises this pattern into a single, reusable
  component. A single entity may carry multiple named timers simultaneously.

  DESIGN
  ──────
  • Timers are stored in a fixed-length open array, keyed by a short string.
  • The array is intentionally small (MAX_TIMERS = 8) — components should be
    lightweight data bags, not general-purpose data structures.
  • TTimerSystem2D decrements all active timers every Update frame and fires
    the optional OnFired callback when a timer expires.
  • Timers can be one-shot (fires once, auto-stops) or repeating (auto-resets).
  ───────────────────────────────────────────────────────────────────────────── }

interface

uses
  SysUtils, P2D.Core.Component;

const
  MAX_TIMERS = 8;

type
  TOnTimerFiredProc = procedure(const ATimerName: string) of object;

  TTimerEntry = record
    Name     : string[31];   // short string for O(1) compare
    Duration : Single;
    Remaining: Single;
    Active   : Boolean;
    Repeat_  : Boolean;      // True = auto-reset on expiry
    OnFired  : TOnTimerFiredProc;
  end;

  TTimerComponent2D = class(TComponent2D)
  private
    FTimers: array[0..MAX_TIMERS - 1] of TTimerEntry;
    FCount : Integer;

    function FindTimer(const AName: string): Integer;
  public
    constructor Create; override;

    { Start or restart a named timer.
      ARepeat=True → auto-resets on expiry (good for recurring cooldowns).
      AOnFired     → optional callback; nil = no callback. }
    procedure Start(const AName: string; ADuration: Single; ARepeat: Boolean = False; AOnFired: TOnTimerFiredProc = nil);

    { Stop the timer without firing the callback. }
    procedure Stop(const AName: string);

    { Returns True while the timer is running (Remaining > 0). }
    function  IsActive(const AName: string): Boolean;

    { Returns the normalised progress [0..1] of a named timer.
      0.0 = just started; 1.0 = expired. }
    function  Progress(const AName: string): Single;

    { Returns remaining seconds; 0 if timer not found or inactive. }
    function  Remaining(const AName: string): Single;

    { Internal — called by TTimerSystem2D every frame. }
    procedure Tick(ADelta: Single);
  end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TTimerComponent2D.Create;
var
  I: Integer;
begin
  inherited Create;
  
  FCount := 0;
  for I := 0 to MAX_TIMERS - 1 do
    FillChar(FTimers[I], SizeOf(FTimers[I]), 0);
end;

function TTimerComponent2D.FindTimer(const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FCount - 1 do
    if FTimers[I].Name = AName then
    begin
      Result := I;
      Exit;
    end;
end;

procedure TTimerComponent2D.Start(const AName: string; ADuration: Single; ARepeat: Boolean; AOnFired: TOnTimerFiredProc);
var
  Idx: Integer;
begin
  Idx := FindTimer(AName);
  if Idx < 0 then
  begin
    if FCount >= MAX_TIMERS then
      raise Exception.CreateFmt('TTimerComponent2D: max %d timers reached. Cannot add "%s".', [MAX_TIMERS, AName]);
    Idx := FCount;
    Inc(FCount);
    FTimers[Idx].Name := AName;
  end;

  FTimers[Idx].Duration  := ADuration;
  FTimers[Idx].Remaining := ADuration;
  FTimers[Idx].Active    := True;
  FTimers[Idx].Repeat_   := ARepeat;
  FTimers[Idx].OnFired   := AOnFired;
end;

procedure TTimerComponent2D.Stop(const AName: string);
var
  Idx: Integer;
begin
  Idx := FindTimer(AName);
  if Idx >= 0 then
    FTimers[Idx].Active := False;
end;

function TTimerComponent2D.IsActive(const AName: string): Boolean;
var
  Idx: Integer;
begin
  Idx := FindTimer(AName);
  Result := (Idx >= 0) and FTimers[Idx].Active;
end;

function TTimerComponent2D.Progress(const AName: string): Single;
var
  Idx: Integer;
begin
  Idx := FindTimer(AName);
  if (Idx < 0) or (FTimers[Idx].Duration <= 0) then
    Result := 0
  else
    Result := 1.0 - (FTimers[Idx].Remaining / FTimers[Idx].Duration);
end;

function TTimerComponent2D.Remaining(const AName: string): Single;
var
  Idx: Integer;
begin
  Idx := FindTimer(AName);
  if (Idx < 0) or not FTimers[Idx].Active then
    Result := 0
  else
    Result := FTimers[Idx].Remaining;
end;

procedure TTimerComponent2D.Tick(ADelta: Single);
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
  begin
    if not FTimers[I].Active then Continue;

    FTimers[I].Remaining := FTimers[I].Remaining - ADelta;
    if FTimers[I].Remaining <= 0 then
    begin
      FTimers[I].Remaining := 0;

      if Assigned(FTimers[I].OnFired) then
        FTimers[I].OnFired(FTimers[I].Name);

      if FTimers[I].Repeat_ then
        FTimers[I].Remaining := FTimers[I].Duration   // auto-reset
      else
        FTimers[I].Active := False;                   // one-shot: stop
    end;
  end;
end;

initialization
   ComponentRegistry.Register(TTimerComponent2D);

end.
