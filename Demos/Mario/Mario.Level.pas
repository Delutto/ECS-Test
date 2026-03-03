unit Mario.Level;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, raylib,
   P2D.Core.World,
   Mario.ProceduralArt, Mario.Entities;

procedure LoadLevel(AWorld: TWorld);

implementation

procedure LoadLevel(AWorld: TWorld);
begin
   // Tilemap
   CreateTileMap(AWorld);

   // Player
   CreatePlayer(AWorld, 48, 150);

   // Goombas
   CreateGoomba(AWorld, 200, 192);
   CreateGoomba(AWorld, 380, 128);
   CreateGoomba(AWorld, 440, 192);

   // Coins
   CreateCoin(AWorld, 80,  192);
   CreateCoin(AWorld, 96,  192);
   CreateCoin(AWorld, 112, 192);
   CreateCoin(AWorld, 210, 50);
   CreateCoin(AWorld, 336, 50);
   CreateCoin(AWorld, 352, 50);

   // Camera
   CreateCamera(AWorld);
end;

end.
