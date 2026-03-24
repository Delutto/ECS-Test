program mario_demo;

{$mode objfpc}
{$H+}

uses
   {$IFDEF UNIX}
   cthreads,
   {$ENDIF}
   SysUtils,
   Mario.Game In 'Mario.Game.pas';

var
   Game: TMarioGame;
begin
   Game := TMarioGame.Create;
   try
      Game.Run;
   finally
      Game.Free;
   end;
end.
