program terraria_demo;

{$mode objfpc}{$H+}

uses
   {$IFDEF UNIX}cthreads,{$ENDIF}
   SysUtils,
   Terraria.Game in 'Terraria.Game.pas';

var
   Game: TTerrariaDemoGame;
begin
   Game := TTerrariaDemoGame.Create;
   try
      Game.Run;
   finally
      Game.Free;
   end;
end.
