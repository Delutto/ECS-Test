unit Mario.Level;

{$mode ObjFPC}
{$H+}

interface

uses
   SysUtils,
   raylib,
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
  { ── Parallax backgrounds ─────────────────────────────────────────────── }
   CreateParallaxBackground(AWorld, TexBackground, 0.20, 0.0, 2.0, 0.0, 0, True, False);
   CreateParallaxBackground(AWorld, TexBackground2, 0.60, 0.0, 2.0, 360.0, 1, True, False);

  { ── World entities ────────────────────────────────────────────────────── }
   CreateTileMap(AWorld);

   Player := CreatePlayer(AWorld, 48, 150);

   CreateGoomba(AWorld, 200, 192);
   CreateGoomba(AWorld, 380, 128);
   CreateGoomba(AWorld, 440, 192);

   CreateCoin(AWorld, 80, 192);
   CreateCoin(AWorld, 96, 192);
   CreateCoin(AWorld, 112, 192);
   CreateCoin(AWorld, 210, 50);
   CreateCoin(AWorld, 336, 50);
   CreateCoin(AWorld, 352, 50);

  { ── Goal: pipe entity at the right end (tile col 37, row 11) ──────────── }
  { Touching it fires TLevelCompleteEvent → TGameplayScene transitions to the Underwater scene. }
   CreateGoal(AWorld, 592, 160);   { world X = 37*16 = 592 }

   CreateCamera(AWorld, Player);
   CreateMusicPlayer(AWorld, BGM_OVERWORLD);
end;

end.
