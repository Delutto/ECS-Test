unit P2D.Utils.Math;

{$mode objfpc}{$H+}

interface

uses
   SysUtils,
   Math,
   P2D.Core.Types;

function Lerp(A, B, T: Single): Single; inline;
function Clamp(V, Lo, Hi: Single): Single; overload; inline;
function Clamp(V, Lo, Hi: Integer): Integer; overload; inline;
function Vec2Lerp(const A, B: TVector2; T: Single): TVector2;
function Vec2Distance(const A, B: TVector2): Single;
function SignF(V: Single): Single; inline;
function ApproachF(Current, Target, Step: Single): Single;

implementation

function Lerp(A, B, T: Single): Single;
begin
   Result := A + (B - A) * T;
end;

function Clamp(V, Lo, Hi: Single): Single;
begin
   if V < Lo then
   begin
      Result := Lo;
   end
   else
   if V > Hi then
   begin
      Result := Hi;
   end
   else
   begin
      Result := V;
   end;
end;

function Clamp(V, Lo, Hi: Integer): Integer;
begin
   if V < Lo then
   begin
      Result := Lo;
   end
   else
   if V > Hi then
   begin
      Result := Hi;
   end
   else
   begin
      Result := V;
   end;
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
   begin
      Result := 1;
   end
   else
   if V < 0 then
   begin
      Result := -1;
   end
   else
   begin
      Result := 0;
   end;
end;

function ApproachF(Current, Target, Step: Single): Single;
begin
   if Current < Target then
   begin
      Result := Min(Current + Step, Target);
   end
   else
   begin
      Result := Max(Current - Step, Target);
   end;
end;

end.
