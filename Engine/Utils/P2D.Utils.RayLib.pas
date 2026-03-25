unit P2D.Utils.RayLib;

{$mode objfpc}{$H+}

interface

uses
   SysUtils,
   StrUtils,
   P2D.Core.Types;
   
function IfThen(B: Boolean; const T, F: TColor): TColor; overload;   

implementation

function IfThen(B: Boolean; const T, F: TColor): TColor;
begin
   if B then
      Result := T
   else
      Result := F;
end;

end.
