unit P2D.Core.Types;

{$mode objfpc}{$H+}
{$modeswitch ADVANCEDRECORDS}

interface

uses
  SysUtils, Math, raylib;

// ---------------------------------------------------------------------------
// Basic scalar / identifier types
// ---------------------------------------------------------------------------
type
   TEntityID   = Cardinal;
   TComponentID = Cardinal;
   TSystemPriority = Integer;

   TVector2 = raylib.TVector2;
   //TRectF   = raylib.TRectangle;
   TRectangle = raylib.TRectangle;
   TColor   = raylib.TColor;

const
  INVALID_ENTITY : TEntityID = 0;

// ---------------------------------------------------------------------------
// Axis-aligned bounding rectangle
// ---------------------------------------------------------------------------
type
   TColliderTag = (ctNone, ctPlayer, ctEnemy, ctGround, ctPlatform, ctCoin, ctPowerUp, ctHazard, ctGoal);

   TRectF = record
      X, Y, W, H: Single;
      class function Create(AX, AY, AW, AH: Single): TRectF; static; inline;
      function Right: Single; inline;
      function Bottom: Single; inline;
      function Overlaps(const Other: TRectF): Boolean; inline;
      function Contains(const P: TVector2): Boolean; inline;
   end;

implementation

{ TRectF }
class function TRectF.Create(AX, AY, AW, AH: Single): TRectF;
begin
   Result.X := AX;
   Result.Y := AY;
   Result.W := AW;
   Result.H := AH;
end;

function TRectF.Right: Single;
begin
   Result := X + W;
end;

function TRectF.Bottom: Single;
begin
   Result := Y + H;
end;

function TRectF.Overlaps(const Other: TRectF): Boolean;
begin
   Result := (X < Other.Right) and (Right > Other.X) and (Y < Other.Bottom) and (Bottom > Other.Y);
end;

function TRectF.Contains(const P: TVector2): Boolean;
begin
   Result := (P.X >= X) and (P.X <= Right) and (P.Y >= Y) and (P.Y <= Bottom);
end;

end.
