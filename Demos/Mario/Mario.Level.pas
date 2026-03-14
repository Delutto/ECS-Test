unit Mario.Level;

{$mode ObjFPC}{$H+}

interface

uses
   SysUtils, raylib,
   P2D.Core.World,
   P2D.Core.ResourceManager,
   Mario.Entities,
   Mario.Common;

procedure LoadLevel(AWorld: TWorld);

implementation

uses
   P2D.Core.Entity,
   Mario.Assets;

procedure LoadLevel(AWorld: TWorld);
var
   Player: TEntity;
begin
   { Tilemap }
   CreateTileMap(AWorld);

   { Player }
   Player := CreatePlayer(AWorld, 48, 150);

   { Goombas }
   CreateGoomba(AWorld, 200, 192);
   CreateGoomba(AWorld, 380, 128);
   CreateGoomba(AWorld, 440, 192);

   { Coins }
   CreateCoin(AWorld, 80,  192);
   CreateCoin(AWorld, 96,  192);
   CreateCoin(AWorld, 112, 192);
   CreateCoin(AWorld, 210, 50);
   CreateCoin(AWorld, 336, 50);
   CreateCoin(AWorld, 352, 50);

   { Camera }
   CreateCamera(AWorld, Player);

   { Entidade de música de fundo: carrega o asset via TResourceManager2D e cria a entidade com TMusicPlayerComponent; TAudioSystem detecta AutoPlay=True no Init. }
   CreateMusicPlayer(AWorld, BGM_OVERWORLD, 1, True);
end;

end.
