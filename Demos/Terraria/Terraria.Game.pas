unit Terraria.Game;

{$mode objfpc}{$H+}

{ TTerrariaDemoGame — TEngine2D subclass.

  Virtual canvas: 1280 × 720 (HD, gives comfortable screen-to-world ratio).
  The engine renders into this canvas and scales to the physical window while
  preserving aspect ratio (letter/pillar-boxing handled by TEngine2D). }

interface

uses
   SysUtils, raylib,
   P2D.Core.Engine,
   P2D.Core.Scene,
   Terraria.Common,
   Terraria.Scene.World;

type
   TTerrariaDemoGame = class(TEngine2D)
   private
      FWorldScene: TWorldScene;
   protected
      procedure OnInit; override;
      procedure OnUpdate(ADelta: Single); override;
      procedure OnRender; override;
      procedure OnShutdown; override;
   public
      constructor Create;
   end;

implementation

uses
   P2D.Systems.SceneManager;

constructor TTerrariaDemoGame.Create;
begin
   inherited Create(
      { window W/H } 1280, 720,
      { title      } 'Pascal 2D Game Engine — Terraria Demo (Procedural Map)',
      { FPS        } 60,
      { virtual W  } VIRT_W,
      { virtual H  } VIRT_H);
end;

procedure TTerrariaDemoGame.OnInit;
begin
   FWorldScene := TWorldScene.Create(ScreenW, ScreenH);
   SceneManager.RegisterScene(FWorldScene);
   SceneManager.ChangeSceneImmediate('TerrainWorld');
end;

procedure TTerrariaDemoGame.OnUpdate(ADelta: Single);
begin
   SceneManager.Update(ADelta);
end;

procedure TTerrariaDemoGame.OnRender;
begin
   SceneManager.Render;
end;

procedure TTerrariaDemoGame.OnShutdown;
begin
   SceneManager.UnregisterScene('TerrainWorld');
   FWorldScene.Free;
end;

end.
