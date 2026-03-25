unit Showcase.Game;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, raylib,
   P2D.Core.Engine, P2D.Core.Scene,
   Showcase.Common,
   Showcase.Scene.Menu, Showcase.Scene.Health,
   Showcase.Scene.Tag, Showcase.Scene.Inventory,
   Showcase.Scene.Projectile, Showcase.Scene.Interaction,
   Showcase.Scene.Lighting, Showcase.Scene.DayNight,
   Showcase.Scene.Dialog, Showcase.Scene.Pathfinding,
   Showcase.Scene.Chunk, Showcase.Scene.Builder;

type
   TShowcaseGame = class(TEngine2D)
   private
      FMenu: TMenuScene;
      FHealth: THealthDemoScene;
      FTag: TTagDemoScene;
      FInv: TInventoryDemoScene;
      FProj: TProjectileDemoScene;
      FInter: TInteractionDemoScene;
      FLight: TLightingDemoScene;
      FDN: TDayNightDemoScene;
      FDialog: TDialogDemoScene;
      FPath: TPathfindingDemoScene;
      FChunk: TChunkDemoScene;
      FBuilder: TBuilderDemoScene;
   protected
      procedure OnInit; override;
      procedure OnUpdate(ADelta: single); override;
      procedure OnRender; override;
      procedure OnShutdown; override;
   public
      constructor Create;
   end;

implementation

uses
   P2D.Systems.SceneManager;

constructor TShowcaseGame.Create;
begin
   inherited Create(1280, 720, 'Pascal 2D Game Engine - Showcase', 60, SCR_W, SCR_H);
end;

procedure TShowcaseGame.OnInit;
begin
   FMenu := TMenuScene.Create(ScreenW, ScreenH);
   FHealth := THealthDemoScene.Create(ScreenW, ScreenH);
   FTag := TTagDemoScene.Create(ScreenW, ScreenH);
   FInv := TInventoryDemoScene.Create(ScreenW, ScreenH);
   FProj := TProjectileDemoScene.Create(ScreenW, ScreenH);
   FInter := TInteractionDemoScene.Create(ScreenW, ScreenH);
   FLight := TLightingDemoScene.Create(ScreenW, ScreenH);
   FDN := TDayNightDemoScene.Create(ScreenW, ScreenH);
   FDialog := TDialogDemoScene.Create(ScreenW, ScreenH);
   FPath := TPathfindingDemoScene.Create(ScreenW, ScreenH);
   FChunk := TChunkDemoScene.Create(ScreenW, ScreenH);
   FBuilder := TBuilderDemoScene.Create(ScreenW, ScreenH);

   SceneManager.RegisterScene(FMenu);
   SceneManager.RegisterScene(FHealth);
   SceneManager.RegisterScene(FTag);
   SceneManager.RegisterScene(FInv);
   SceneManager.RegisterScene(FProj);
   SceneManager.RegisterScene(FInter);
   SceneManager.RegisterScene(FLight);
   SceneManager.RegisterScene(FDN);
   SceneManager.RegisterScene(FDialog);
   SceneManager.RegisterScene(FPath);
   SceneManager.RegisterScene(FChunk);
   SceneManager.RegisterScene(FBuilder);

   SceneManager.ChangeSceneImmediate('Menu');
end;

procedure TShowcaseGame.OnUpdate(ADelta: single);
begin
   SceneManager.Update(ADelta);
end;

procedure TShowcaseGame.OnRender;
begin
   SceneManager.Render;
end;

procedure TShowcaseGame.OnShutdown;
begin
   SceneManager.UnregisterScene('Builder');
   SceneManager.UnregisterScene('Chunk');
   SceneManager.UnregisterScene('Pathfinding');
   SceneManager.UnregisterScene('Dialog');
   SceneManager.UnregisterScene('DayNight');
   SceneManager.UnregisterScene('Lighting');
   SceneManager.UnregisterScene('Interaction');
   SceneManager.UnregisterScene('Projectile');
   SceneManager.UnregisterScene('Inventory');
   SceneManager.UnregisterScene('Tag');
   SceneManager.UnregisterScene('Health');
   SceneManager.UnregisterScene('Menu');

   FBuilder.Free;
   FChunk.Free;
   FPath.Free;
   FDialog.Free;
   FDN.Free;
   FLight.Free;
   FInter.Free;
   FProj.Free;
   FInv.Free;
   FTag.Free;
   FHealth.Free;
   FMenu.Free;
end;

end.
