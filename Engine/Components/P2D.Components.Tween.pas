unit P2D.Components.Tween;

{$mode objfpc}{$H+}

{ ─────────────────────────────────────────────────────────────────────────────
  TTweenComponent2D — property animation/interpolation system.

  DESIGN
  ──────
  • Each entity may carry one TTweenComponent2D, which holds up to
    MAX_TWEENS simultaneous tween tracks.
  • Each track drives a Single pointer (e.g. @Tr.Position.X, @Spr.Tint.A,
    @Cam.Zoom) from a start value to a target value over a given duration.
  • Easing functions are pluggable: assign any TEasingFunc procedure.
  • On completion, an optional OnComplete callback fires.
  • TTweenSystem2D iterates all tweens every frame and updates the pointer.
  ───────────────────────────────────────────────────────────────────────────── }

interface

uses
   SysUtils, Math,
   P2D.Core.Component;

const
  MAX_TWEENS = 8;

type
  // ── Easing function signature ─────────────────────────────────────────────
  // t = normalised time [0..1]; returns eased [0..1]
  TEasingFunc = function(t: Single): Single;

  TOnTweenComplete = procedure(AEntityID: Cardinal; const ATweenName: string) of object;

  TTweenTrack = record
    Name      : string[31];
    Target    : PSingle;        // pointer to the Single being animated
    StartVal  : Single;
    EndVal    : Single;
    Duration  : Single;
    Elapsed   : Single;
    Active    : Boolean;
    Loop      : Boolean;
    PingPong  : Boolean;
    Easing    : TEasingFunc;    // nil = linear
    OnComplete: TOnTweenComplete;
    OwnerID   : Cardinal;
  end;

  TTweenComponent2D = class(TComponent2D)
  private
    FTracks: array[0..MAX_TWEENS - 1] of TTweenTrack;
    FCount : Integer;
    FOwnerID: Cardinal;

    function FindTrack(const AName: string): Integer;
  public
    constructor Create; override;

    { Start or overwrite a named tween track.
      ATarget  → pointer to the Single property to animate.
      AFrom    → start value (use current value: ATarget^).
      ATo      → end value.
      ADur     → duration in seconds.
      AEasing  → easing function (nil = linear).
      ALoop    → restart on completion.
      APingPong→ animate back and forth (requires ALoop=True).
      AOnComplete → callback fired when tween ends (not called if ALoop=True). }
    procedure Start(const AName: string; ATarget: PSingle; AFrom, ATo: Single; ADur: Single; AEasing: TEasingFunc = nil; ALoop: Boolean = False; APingPong: Boolean = False; AOnComplete: TOnTweenComplete = nil);

    procedure Stop(const AName: string);
    function  IsActive(const AName: string): Boolean;
    procedure Tick(ADelta: Single; AOwnerEntityID: Cardinal);
  end;

// ── Built-in easing functions (standalone functions, assign directly) ─────────
function EaseLinear    (t: Single): Single;
function EaseInQuad    (t: Single): Single;
function EaseOutQuad   (t: Single): Single;
function EaseInOutQuad (t: Single): Single;
function EaseOutBounce (t: Single): Single;
function EaseOutElastic(t: Single): Single;

implementation

uses
   P2D.Core.ComponentRegistry;

// ─────────────────────────────────────────────────────────────────────────────
//  Easing functions
// ─────────────────────────────────────────────────────────────────────────────
function EaseLinear(t: Single): Single;
begin Result := t; end;

function EaseInQuad(t: Single): Single;
begin Result := t * t; end;

function EaseOutQuad(t: Single): Single;
begin Result := t * (2 - t); end;

function EaseInOutQuad(t: Single): Single;
begin
  if t < 0.5 then Result := 2 * t * t
  else Result := -1 + (4 - 2*t) * t;
end;

function EaseOutBounce(t: Single): Single;
begin
  if t < (1 / 2.75) then
    Result := 7.5625 * t * t
  else if t < (2 / 2.75) then
  begin
    t := t - (1.5 / 2.75);
    Result := 7.5625 * t * t + 0.75;
  end
  else if t < (2.5 / 2.75) then
  begin
    t := t - (2.25 / 2.75);
    Result := 7.5625 * t * t + 0.9375;
  end
  else
  begin
    t := t - (2.625 / 2.75);
    Result := 7.5625 * t * t + 0.984375;
  end;
end;

function EaseOutElastic(t: Single): Single;
const
  C4 = (2 * Pi) / 3;
begin
  if t <= 0 then Result := 0
  else if t >= 1 then Result := 1
  else Result := Power(2, -10*t) * Sin((t*10 - 0.75) * C4) + 1;
end;

// ─────────────────────────────────────────────────────────────────────────────
//  TTweenComponent2D
// ─────────────────────────────────────────────────────────────────────────────
constructor TTweenComponent2D.Create;
var
  I: Integer;
begin
  inherited Create;
  
  FCount   := 0;
  FOwnerID := 0;
  for I := 0 to MAX_TWEENS - 1 do
    FillChar(FTracks[I], SizeOf(FTracks[I]), 0);
end;

function TTweenComponent2D.FindTrack(const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FCount - 1 do
    if FTracks[I].Name = AName then
	begin
	  Result := I;
	  Exit;
	end;
end;

procedure TTweenComponent2D.Start(const AName: string; ATarget: PSingle; AFrom, ATo, ADur: Single; AEasing: TEasingFunc; ALoop, APingPong: Boolean; AOnComplete: TOnTweenComplete);
var
  Idx: Integer;
begin
  if not Assigned(ATarget) then
    raise EArgumentNilException.Create('TTweenComponent2D.Start: ATarget is nil');

  Idx := FindTrack(AName);
  if Idx < 0 then
  begin
    if FCount >= MAX_TWEENS then
      raise Exception.CreateFmt( 'TTweenComponent2D: max %d tweens reached. Cannot add "%s".', [MAX_TWEENS, AName]);
    Idx := FCount;
    Inc(FCount);
    FTracks[Idx].Name := AName;
  end;

  FTracks[Idx].Target     := ATarget;
  FTracks[Idx].StartVal   := AFrom;
  FTracks[Idx].EndVal     := ATo;
  FTracks[Idx].Duration   := Max(ADur, 0.001);
  FTracks[Idx].Elapsed    := 0;
  FTracks[Idx].Active     := True;
  FTracks[Idx].Loop       := ALoop;
  FTracks[Idx].PingPong   := APingPong;
  FTracks[Idx].Easing     := AEasing;
  FTracks[Idx].OnComplete := AOnComplete;
end;

procedure TTweenComponent2D.Stop(const AName: string);
var
  Idx: Integer;
begin
  Idx := FindTrack(AName);
  if Idx >= 0 then
    FTracks[Idx].Active := False;
end;

function TTweenComponent2D.IsActive(const AName: string): Boolean;
var
  Idx: Integer;
begin
  Idx := FindTrack(AName);
  Result := (Idx >= 0) and FTracks[Idx].Active;
end;

procedure TTweenComponent2D.Tick(ADelta: Single; AOwnerEntityID: Cardinal);
var
  I    : Integer;
  T    : Single;
  EasedT: Single;
  Sv, Ev: Single;
begin
  for I := 0 to FCount - 1 do
  begin
    if not FTracks[I].Active then
	  Continue;
    if not Assigned(FTracks[I].Target) then
	begin
	  FTracks[I].Active := False;
	  Continue;
	end;

    FTracks[I].Elapsed := FTracks[I].Elapsed + ADelta;
    T := Min(FTracks[I].Elapsed / FTracks[I].Duration, 1.0);

    // Apply easing
    if Assigned(FTracks[I].Easing) then
	  EasedT := FTracks[I].Easing(T)
    else
	  EasedT := T;

    Sv := FTracks[I].StartVal;
    Ev := FTracks[I].EndVal;

    // PingPong: alternate start/end on each loop
    if FTracks[I].PingPong and FTracks[I].Loop then
    begin
      // use EasedT as-is for forward pass; reverse will be handled by swapping
    end;

    FTracks[I].Target^ := Sv + (Ev - Sv) * EasedT;

    // Completion
    if T >= 1.0 then
    begin
      FTracks[I].Target^ := Ev; // ensure exact end value
      if FTracks[I].Loop then
      begin
        FTracks[I].Elapsed := 0;
        if FTracks[I].PingPong then
        begin
          // Swap start/end for reverse trip
          Sv := FTracks[I].StartVal;
          FTracks[I].StartVal := FTracks[I].EndVal;
          FTracks[I].EndVal   := Sv;
        end;
      end
      else
      begin
        FTracks[I].Active := False;
        if Assigned(FTracks[I].OnComplete) then
          FTracks[I].OnComplete(AOwnerEntityID, FTracks[I].Name);
      end;
    end;
  end;
end;

initialization
   ComponentRegistry.Register(TTweenComponent2D);

end.
