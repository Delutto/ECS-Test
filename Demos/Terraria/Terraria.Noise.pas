unit Terraria.Noise;

{$mode objfpc}{$H+}

{ Value-noise library for terrain / cave generation.

  Provides:
    NoiseSeed(S)           – seed the hash table (call before generating)
    ValueNoise1D(X)        – 1D value noise, result in [-1, 1]
    ValueNoise2D(X,Y)      – 2D value noise, result in [-1, 1]
    FBM1D(X, Oct, L, G)   – 1D fractal Brownian motion
    FBM2D(X,Y, Oct, L, G) – 2D fractal Brownian motion }

interface

uses
   SysUtils, Math;

procedure NoiseSeed(ASeed: longint);

function ValueNoise1D(X: Single): Single;
function ValueNoise2D(X, Y: Single): Single;

function FBM1D(X: Single; Octaves: Integer; Lacunarity: Single = 2.0; Gain: Single = 0.5): Single;

function FBM2D(X, Y: Single; Octaves: Integer; Lacunarity: Single = 2.0; Gain: Single = 0.5): Single;

implementation

const
   PERM_SIZE = 512;

var
   FPerm: array[0..PERM_SIZE - 1] of Integer;
   FSeeded: boolean = False;

   { ── Seed / permutation table ─────────────────────────────────────────────── }

procedure NoiseSeed(ASeed: longint);
var
   I, J, Tmp: Integer;
   RState: longint;

   function RandNext: Integer;
   begin
      RState := RState xor (RState shl 13);
      RState := RState xor (RState shr 17);
      RState := RState xor (RState shl 5);
      Result := Abs(RState);
   end;

begin
   RState := ASeed or 1;
   { Fill 0..PERM_SIZE-1 then Fisher-Yates shuffle }
   for I := 0 to PERM_SIZE - 1 do
      FPerm[I] := I;
   for I := PERM_SIZE - 1 downto 1 do
   begin
      J := RandNext mod (I + 1);
      Tmp := FPerm[I];
      FPerm[I] := FPerm[J];
      FPerm[J] := Tmp;
   end;
   FSeeded := True;
end;

{ ── Internal helpers ─────────────────────────────────────────────────────── }

{ Quintic smoothstep – used for seamless interpolation }
function SmStep(T: Single): Single; inline;
begin
   Result := T * T * T * (T * (T * 6.0 - 15.0) + 10.0);
end;

function Lerp(A, B, T: Single): Single; inline;
begin
   Result := A + (B - A) * T;
end;

{ 32-bit hash from two integers (seeded via permutation table) }
function Hash2(IX, IY: Integer): Single;
var
   H: Integer;
begin
   if not FSeeded then
      NoiseSeed(12345);
   H := FPerm[(IX and 255)];
   H := FPerm[(H + IY) and 255];
   H := FPerm[(H + IX shr 8) and 255];
   { Map H ∈ [0,255] → [-1, 1] }
   Result := (H / 127.5) - 1.0;
end;

function Hash1(IX: Integer): Single;
begin
   Result := Hash2(IX, IX * 7 + 13);
end;

{ ── Public noise functions ─────────────────────────────────────────────── }

function ValueNoise1D(X: Single): Single;
var
   IX: Integer;
   FX, A, B: Single;
begin
   IX := Floor(X);
   FX := SmStep(X - IX);
   A := Hash1(IX);
   B := Hash1(IX + 1);
   Result := Lerp(A, B, FX);
end;

function ValueNoise2D(X, Y: Single): Single;
var
   IX, IY: Integer;
   FX, FY: Single;
   AA, BA, AB, BB: Single;
begin
   IX := Floor(X);
   FX := SmStep(X - IX);
   IY := Floor(Y);
   FY := SmStep(Y - IY);
   AA := Hash2(IX, IY);
   BA := Hash2(IX + 1, IY);
   AB := Hash2(IX, IY + 1);
   BB := Hash2(IX + 1, IY + 1);
   Result := Lerp(Lerp(AA, BA, FX), Lerp(AB, BB, FX), FY);
end;

function FBM1D(X: Single; Octaves: Integer; Lacunarity: Single; Gain: Single): Single;
var
   I: Integer;
   Freq, Amp, Sum: Single;
begin
   Sum := 0;
   Freq := 1.0;
   Amp := 1.0;
   for I := 0 to Octaves - 1 do
   begin
      Sum := Sum + ValueNoise1D(X * Freq) * Amp;
      Freq := Freq * Lacunarity;
      Amp := Amp * Gain;
   end;
   { Normalise: geometric series sum = (1-Gain^N)/(1-Gain) for Gain<>1 }
   if Abs(Gain - 1.0) > 0.001 then
      Result := Sum * (1.0 - Gain) / (1.0 - Power(Gain, Octaves))
   else
      Result := Sum / Octaves;
end;

function FBM2D(X, Y: Single; Octaves: Integer; Lacunarity: Single; Gain: Single): Single;
var
   I: Integer;
   Freq, Amp, Sum: Single;
begin
   Sum := 0;
   Freq := 1.0;
   Amp := 1.0;
   for I := 0 to Octaves - 1 do
   begin
      Sum := Sum + ValueNoise2D(X * Freq, Y * Freq) * Amp;
      Freq := Freq * Lacunarity;
      Amp := Amp * Gain;
   end;
   if Abs(Gain - 1.0) > 0.001 then
      Result := Sum * (1.0 - Gain) / (1.0 - Power(Gain, Octaves))
   else
      Result := Sum / Octaves;
end;

end.
