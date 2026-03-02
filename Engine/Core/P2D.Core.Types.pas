unit P2D.Core.Types;

{$mode objfpc}{$H+}
{$modeswitch ADVANCEDRECORDS}

interface

uses
  SysUtils, Math;

// ---------------------------------------------------------------------------
// Basic scalar / identifier types
// ---------------------------------------------------------------------------
type
  TEntityID   = Cardinal;
  TComponentID = Cardinal;
  TSystemPriority = Integer;

const
  INVALID_ENTITY : TEntityID = 0;

// ---------------------------------------------------------------------------
// 2-D vector
// ---------------------------------------------------------------------------
type
  TVector2 = record
    X, Y: Single;
    class function Create(AX, AY: Single): TVector2; static; inline;
    function Add(const V: TVector2): TVector2; inline;
    function Sub(const V: TVector2): TVector2; inline;
    function Scale(S: Single): TVector2; inline;
    function Length: Single; inline;
    function Normalize: TVector2; inline;
    function Dot(const V: TVector2): Single; inline;
  end;

// ---------------------------------------------------------------------------
// Axis-aligned bounding rectangle
// ---------------------------------------------------------------------------
type
  TRectF = record
    X, Y, W, H: Single;
    class function Create(AX, AY, AW, AH: Single): TRectF; static; inline;
    function Right: Single; inline;
    function Bottom: Single; inline;
    function Overlaps(const Other: TRectF): Boolean; inline;
    function Contains(const P: TVector2): Boolean; inline;
  end;

// ---------------------------------------------------------------------------
// Colour (RGBA bytes, matches raylib TColor)
// ---------------------------------------------------------------------------
type
  TColor = record
    R, G, B, A: Byte;
    class function Create(AR, AG, AB: Byte; AA: Byte = 255): TColor; static; inline;
  end;

// ---------------------------------------------------------------------------
// Common colours
// ---------------------------------------------------------------------------
const
  clWhite   : TColor = (R:255; G:255; B:255; A:255);
  clBlack   : TColor = (R:0;   G:0;   B:0;   A:255);
  clRed     : TColor = (R:230; G:41;  B:55;  A:255);
  clGreen   : TColor = (R:0;   G:228; B:48;  A:255);
  clBlue    : TColor = (R:0;   G:121; B:241; A:255);
  clYellow  : TColor = (R:253; G:249; B:0;   A:255);
  clSkyBlue : TColor = (R:102; G:191; B:255; A:255);
  clTransp  : TColor = (R:0;   G:0;   B:0;   A:0);

implementation

// TVector2
class function TVector2.Create(AX, AY: Single): TVector2;
begin Result.X := AX; Result.Y := AY; end;

function TVector2.Add(const V: TVector2): TVector2;
begin Result.X := X + V.X; Result.Y := Y + V.Y; end;

function TVector2.Sub(const V: TVector2): TVector2;
begin Result.X := X - V.X; Result.Y := Y - V.Y; end;

function TVector2.Scale(S: Single): TVector2;
begin Result.X := X * S; Result.Y := Y * S; end;

function TVector2.Length: Single;
begin Result := Sqrt(X*X + Y*Y); end;

function TVector2.Normalize: TVector2;
var L: Single;
begin
  L := Length;
  if L > 0 then begin Result.X := X/L; Result.Y := Y/L; end
  else Result := Self;
end;

function TVector2.Dot(const V: TVector2): Single;
begin Result := X*V.X + Y*V.Y; end;

// TRectF
class function TRectF.Create(AX, AY, AW, AH: Single): TRectF;
begin Result.X := AX; Result.Y := AY; Result.W := AW; Result.H := AH; end;

function TRectF.Right: Single;  begin Result := X + W; end;
function TRectF.Bottom: Single; begin Result := Y + H; end;

function TRectF.Overlaps(const Other: TRectF): Boolean;
begin
  Result := (X < Other.Right) and (Right > Other.X) and
            (Y < Other.Bottom) and (Bottom > Other.Y);
end;

function TRectF.Contains(const P: TVector2): Boolean;
begin
  Result := (P.X >= X) and (P.X <= Right) and (P.Y >= Y) and (P.Y <= Bottom);
end;

// TColor
class function TColor.Create(AR, AG, AB: Byte; AA: Byte): TColor;
begin
	Result.R := AR; Result.G := AG; Result.B := AB; Result.A := AA;
end;

end.
