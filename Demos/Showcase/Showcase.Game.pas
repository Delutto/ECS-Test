unit Showcase.Game;

{$mode objfpc}{$H+}

{ TShowcaseGame - top-level TEngine2D subclass.
  Creates and registers all 26 demo scenes. }
interface

uses
   SysUtils, raylib, P2D.Core.Engine, P2D.Core.Scene, Showcase.Common,
   Showcase.Scene.Menu, Showcase.Scene.Health, Showcase.Scene.Tag,
   Showcase.Scene.Inventory, Showcase.Scene.Projectile, Showcase.Scene.Interaction,
   Showcase.Scene.Lighting, Showcase.Scene.DayNight, Showcase.Scene.Dialog,
   Showcase.Scene.Pathfinding, Showcase.Scene.Chunk, Showcase.Scene.Builder,
   Showcase.Scene.Sprite, Showcase.Scene.Animation, Showcase.Scene.Physics,
   Showcase.Scene.Camera, Showcase.Scene.Parallax, Showcase.Scene.Particles,
   Showcase.Scene.StateMachine, Showcase.Scene.Timer, Showcase.Scene.Tween,
   Showcase.Scene.Text, Showcase.Scene.Input, Showcase.Scene.Audio,
   Showcase.Scene.EventBus, Showcase.Scene.ResourceManager, Showcase.Scene.Debug;

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
      FSprite: TSpriteRenderDemoScene;
      FAnim: TAnimationDemoScene;
      FPhysics: TPhysicsDemoScene;
      FCamera: TCameraDemoScene;
      FParallax: TParallaxDemoScene;
      FParticles: TParticleDemoScene;
      FSM: TStateMachineDemoScene;
      FTimer: TTimerDemoScene;
      FTween: TTweenDemoScene;
      FText: TTextDemoScene;
      FInput: TInputDemoScene;
      FAudio: TAudioDemoScene;
      FEventBus: TEventBusDemoScene;
      FResMgr: TResourceManagerDemoScene;
      FDebug: TDebugDemoScene;
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

constructor TShowcaseGame.Create;
begin
   inherited Create(800, 600, 'Pascal 2D Game Engine - Showcase', 60, SCR_W, SCR_H);
end;

procedure TShowcaseGame.OnInit;

   procedure Reg(AScene: TScene2D);
   begin
      SceneManager.RegisterScene(AScene);
   end;

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
   FSprite := TSpriteRenderDemoScene.Create(ScreenW, ScreenH);
   FAnim := TAnimationDemoScene.Create(ScreenW, ScreenH);
   FPhysics := TPhysicsDemoScene.Create(ScreenW, ScreenH);
   FCamera := TCameraDemoScene.Create(ScreenW, ScreenH);
   FParallax := TParallaxDemoScene.Create(ScreenW, ScreenH);
   FParticles := TParticleDemoScene.Create(ScreenW, ScreenH);
   FSM := TStateMachineDemoScene.Create(ScreenW, ScreenH);
   FTimer := TTimerDemoScene.Create(ScreenW, ScreenH);
   FTween := TTweenDemoScene.Create(ScreenW, ScreenH);
   FText := TTextDemoScene.Create(ScreenW, ScreenH);
   FInput := TInputDemoScene.Create(ScreenW, ScreenH);
   FAudio := TAudioDemoScene.Create(ScreenW, ScreenH);
   FEventBus := TEventBusDemoScene.Create(ScreenW, ScreenH);
   FResMgr := TResourceManagerDemoScene.Create(ScreenW, ScreenH);
   FDebug := TDebugDemoScene.Create(ScreenW, ScreenH);
   Reg(FMenu);
   Reg(FHealth);
   Reg(FTag);
   Reg(FInv);
   Reg(FProj);
   Reg(FInter);
   Reg(FLight);
   Reg(FDN);
   Reg(FDialog);
   Reg(FPath);
   Reg(FChunk);
   Reg(FBuilder);
   Reg(FSprite);
   Reg(FAnim);
   Reg(FPhysics);
   Reg(FCamera);
   Reg(FParallax);
   Reg(FParticles);
   Reg(FSM);
   Reg(FTimer);
   Reg(FTween);
   Reg(FText);
   Reg(FInput);
   Reg(FAudio);
   Reg(FEventBus);
   Reg(FResMgr);
   Reg(FDebug);
   SceneManager.ChangeSceneImmediate('Menu');
end;

procedure TShowcaseGame.OnUpdate(ADelta: Single);
begin
   SceneManager.Update(ADelta);
end;

procedure TShowcaseGame.OnRender;
begin
   SceneManager.Render;
end;

procedure TShowcaseGame.OnShutdown;

   procedure U(const N: String);
   begin
      SceneManager.UnregisterScene(N);
   end;

begin
   U('Debug');
   U('ResourceManager');
   U('EventBus');
   U('Audio');
   U('Input');
   U('Text');
   U('Tween');
   U('Timer');
   U('StateMachine');
   U('Particles');
   U('Parallax');
   U('Camera');
   U('Physics');
   U('Animation');
   U('Sprite');
   U('Builder');
   U('Chunk');
   U('Pathfinding');
   U('Dialog');
   U('DayNight');
   U('Lighting');
   U('Interaction');
   U('Projectile');
   U('Inventory');
   U('Tag');
   U('Health');
   U('Menu');
   FDebug.Free;
   FResMgr.Free;
   FEventBus.Free;
   FAudio.Free;
   FInput.Free;
   FText.Free;
   FTween.Free;
   FTimer.Free;
   FSM.Free;
   FParticles.Free;
   FParallax.Free;
   FCamera.Free;
   FPhysics.Free;
   FAnim.Free;
   FSprite.Free;
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
