unit P2D.Core.Types;

{$mode objfpc}
{$H+}
{$modeswitch ADVANCEDRECORDS}

interface

uses
   SysUtils,
   Math,
   raylib;

   // ---------------------------------------------------------------------------
   // Basic scalar / identifier types
   // ---------------------------------------------------------------------------
type
   TEntityID = cardinal;
   TComponentID = cardinal;
   TSystemPriority = integer;

   TVector2 = raylib.TVector2;
   //TRectF   = raylib.TRectangle;
   TRectangle = raylib.TRectangle;
   TColor = raylib.TColor;

   // ---------------------------------------------------------------------------
   // Axis-aligned bounding rectangle
   // ---------------------------------------------------------------------------
type
   TColliderTag = (ctNone, ctPlayer, ctEnemy, ctGround, ctPlatform, ctCoin, ctPowerUp, ctHazard, ctGoal);

   TRectF = record
      X, Y, W, H: single;
      class function Create(AX, AY, AW, AH: single): TRectF; static; inline;
      function Right: single; inline;
      function Bottom: single; inline;
      function Overlaps(const Other: TRectF): boolean; inline;
      function Contains(const P: TVector2): boolean; inline;
   end;

const
   INVALID_ENTITY: TEntityID = 0;

implementation

{ TRectF }
class function TRectF.Create(AX, AY, AW, AH: single): TRectF;
begin
   Result.X := AX;
   Result.Y := AY;
   Result.W := AW;
   Result.H := AH;
end;

function TRectF.Right: single;
begin
   Result := X + W;
end;

function TRectF.Bottom: single;
begin
   Result := Y + H;
end;

function TRectF.Overlaps(const Other: TRectF): boolean;
begin
   Result := (X < Other.Right) and (Right > Other.X) and (Y < Other.Bottom) and (Bottom > Other.Y);
end;

function TRectF.Contains(const P: TVector2): boolean;
begin
   Result := (P.X >= X) and (P.X <= Right) and (P.Y >= Y) and (P.Y <= Bottom);
end;

end.
