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
   { Parallax layers (created before world entities so their entity IDs are lower, but ZOrder guarantees correct draw order regardless) }

   { Layer 0 — far sky, distant hills and clouds }
   CreateParallaxBackground(AWorld,
                            TexBackground,   { 512×240                     }
                            0.20,            { ScrollFactorX — very slow   }
                            0.0,             { ScrollFactorY — no vertical }
                            2.0,             { scale — pixel-doubled       }
                            0.0,             { ScreenY — fills from top    }
                            0,               { ZOrder — drawn first        }
                            True,            { TileH                       }
                            False);          { TileV                       }

   { Layer 1 — near hills and bushes (transparent background) }
   CreateParallaxBackground(AWorld,
                            TexBackground2,  { 256×120                           }
                            0.60,            { ScrollFactorX — noticeably faster }
                            0.0,             { ScrollFactorY                     }
                            2.0,             { scale                             }
                            360.0,           { ScreenY — sits above ground row   }
                            1,               { ZOrder — drawn on top of layer 0  }
                            True,            { TileH                             }
                            False);          { TileV                             }

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
   CreateMusicPlayer(AWorld, BGM_OVERWORLD);
end;

end.
