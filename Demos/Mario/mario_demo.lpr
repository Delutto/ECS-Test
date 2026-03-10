program mario_demo;

{$mode objfpc}{$H+}

uses
   {$IFDEF UNIX}cthreads,{$ENDIF}
   SysUtils,
   Mario.Game in 'Mario.Game.pas', Mario.Systems.Input;

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
