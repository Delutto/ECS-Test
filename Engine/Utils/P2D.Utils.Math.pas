unit P2D.Utils.Math;

{$mode objfpc}{$H+}

interface

uses SysUtils, Math, P2D.Core.Types;

function  Lerp(A, B, T: Single): Single; inline;
function  Clamp(V, Lo, Hi: Single): Single; overload; inline;
function  Clamp(V, Lo, Hi: Integer): Integer; overload; inline;
function  Vec2Lerp(const A, B: TVector2; T: Single): TVector2;
function  Vec2Distance(const A, B: TVector2): Single;
function  SignF(V: Single): Single; inline;
function  ApproachF(Current, Target, Step: Single): Single;

implementation

function Lerp(A, B, T: Single): Single;
begin
   Result := A + (B - A) * T;
end;

function Clamp(V, Lo, Hi: Single): Single;
begin
   if V < Lo then
      Result := Lo
   else if V > Hi then
      Result := Hi
   else
      Result := V;
end;

function Clamp(V, Lo, Hi: Integer): Integer;
begin
   if V < Lo then
      Result := Lo
   else if V > Hi then
      Result := Hi
   else
      Result := V;
end;

function Vec2Lerp(const A, B: TVector2; T: Single): TVector2;
begin
   Result.X := Lerp(A.X, B.X, T);
   Result.Y := Lerp(A.Y, B.Y, T);
end;

function Vec2Distance(const A, B: TVector2): Single;
begin
   Result := Sqrt(Sqr(A.X - B.X) + Sqr(A.Y - B.Y));
end;

function SignF(V: Single): Single;
begin
   if V > 0 then
      Result := 1
   else if V < 0 then
      Result := -1
   else
      Result := 0;
end;

function ApproachF(Current, Target, Step: Single): Single;
begin
   if Current < Target then
      Result := Min(Current + Step, Target)
   else
      Result := Max(Current - Step, Target);
end;

end.
