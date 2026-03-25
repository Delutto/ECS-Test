unit Mario.Level2;

{$mode ObjFPC}{$H+}

interface

uses
   SysUtils,
   raylib,
   P2D.Core.World,
   P2D.Core.ResourceManager,
   Mario.Entities,
   Mario.Common;

procedure LoadLevel2(AWorld: TWorld);

implementation

uses
   P2D.Core.Entity,
   Mario.Assets;

procedure LoadLevel2(AWorld: TWorld);
var
   Player: TEntity;
begin
   { ── Underwater parallax backgrounds ──────────────────────────────────── }
   CreateParallaxBackground(AWorld, TexWaterBG, 0.15, 0.0, 2.0, 0.0, 0, True, False);
   CreateParallaxBackground(AWorld, TexWaterNear, 0.45, 0.0, 2.0, 360.0, 1, True, False);

   { ── Underwater tilemap (coral tileset) ───────────────────────────────── }
   CreateUnderwaterTileMap(AWorld);

   { ── Player with swimmer physics ──────────────────────────────────────── }
   Player := CreateUnderwaterPlayer(AWorld, WATER_SPAWN_X, WATER_SPAWN_Y);

   { ── Fish enemies at various heights ──────────────────────────────────── }
   CreateFish(AWorld, 120, 60, 55, -1, 0.7);  { top corridor, fast           }
   CreateFish(AWorld, 250, 110, 45, 1, 0.9);  { mid passage, slow            }
   CreateFish(AWorld, 180, 160, 60, -1, 1.1); { lower area, different freq   }
   CreateFish(AWorld, 350, 55, 50, 1, 0.6);   { upper right                  }
   CreateFish(AWorld, 450, 130, 55, -1, 0.8); { mid right                    }
   CreateFish(AWorld, 520, 175, 40, 1, 1.2);  { low right                    }

   { ── Coins (scattered in open water passages) ────────────────────────── }
   CreateCoin(AWorld, 60, 50);
   CreateCoin(AWorld, 75, 50);
   CreateCoin(AWorld, 90, 50);
   CreateCoin(AWorld, 160, 100);
   CreateCoin(AWorld, 200, 155);
   CreateCoin(AWorld, 240, 155);
   CreateCoin(AWorld, 310, 65);
   CreateCoin(AWorld, 325, 65);
   CreateCoin(AWorld, 420, 100);
   CreateCoin(AWorld, 500, 55);
   CreateCoin(AWorld, 515, 55);

   { ── Goal at the far right ────────────────────────────────────────────── }
   CreateGoal(AWorld, 592, 100);

   CreateCamera(AWorld, Player);
   CreateMusicPlayer(AWorld, BGM_UNDERWATER);
end;

end.
