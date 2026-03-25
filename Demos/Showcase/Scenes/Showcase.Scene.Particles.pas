unit Showcase.Scene.Particles;

{$mode objfpc}{$H+}

{ Demo 17 - Particle Emitter (TParticleEmitterComponent + TParticleSystem)
  Shows all 4 emitter shapes, burst vs continuous, gravity, colour lerp.
  TParticleSystem: FixedUpdate calls Emitter.Update(dt), Render calls
  Emitter.RenderAt(Transform.Position) drawing filled circles.
  Controls: 1=Point  2=Circle  3=Rect  4=Cone  B=Burst  G=Gravity
            P=Play/Stop  LMB=move emitter }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.ParticleEmitter,
   P2D.Systems.Particles,
   Showcase.Common;

type
   TParticleDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FEmitE: TEntity;
      FPartSys: TParticleSystem;
      FTRID, FPEID: Integer;
      FUseGravity: boolean;
      function Emitter: TParticleEmitterComponent;
      function EmitTr: TTransformComponent;
      procedure SetShape(AShape: TEmitterShape2D);
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AW, AH: Integer);
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Systems.SceneManager;

const
   SNAMES: array[TEmitterShape2D] of String = ('esPoint', 'esCircle', 'esRectangle', 'esCone');

constructor TParticleDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('Particles');
   FScreenW := AW;
   FScreenH := AH;
   FUseGravity := False;
end;

function TParticleDemoScene.Emitter: TParticleEmitterComponent;
begin
   Result := TParticleEmitterComponent(FEmitE.GetComponentByID(FPEID));
end;

function TParticleDemoScene.EmitTr: TTransformComponent;
begin
   Result := TTransformComponent(FEmitE.GetComponentByID(FTRID));
end;

procedure TParticleDemoScene.SetShape(AShape: TEmitterShape2D);
var
   E: TParticleEmitterComponent;
begin
   E := Emitter;
   E.EmitterShape := AShape;
   case AShape of
      esCircle:
         E.EmitterSize := Vector2Create(60, 60);
      esRectangle:
         E.EmitterSize := Vector2Create(80, 80);
      esCone:
      begin
         E.EmitterAngle := -90;
         E.EmitterSpread := 45;
      end;
      else
         E.EmitterSize := Vector2Create(0, 0);
   end;
end;

procedure TParticleDemoScene.DoLoad;
begin
   FPartSys := TParticleSystem(World.AddSystem(TParticleSystem.Create(World)));
end;

procedure TParticleDemoScene.DoEnter;
var
   Tr: TTransformComponent;
   PE: TParticleEmitterComponent;
begin
   FUseGravity := False;
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FPEID := ComponentRegistry.GetComponentID(TParticleEmitterComponent);
   FEmitE := World.CreateEntity('Emitter');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(DEMO_AREA_CX, DEMO_AREA_CY);
   FEmitE.AddComponent(Tr);
   PE := TParticleEmitterComponent.Create;
   PE.EmitterShape := esPoint;
   PE.EmissionRate := 60;
   PE.ParticleLifeMin := 0.8;
   PE.ParticleLifeMax := 2.0;
   PE.ParticleSpeedMin := 50;
   PE.ParticleSpeedMax := 150;
   PE.ParticleSizeMin := 3;
   PE.ParticleSizeMax := 8;
   PE.ParticleColorStart := ColorCreate(255, 220, 60, 255);
   PE.ParticleColorEnd := ColorCreate(255, 80, 30, 0);
   PE.Gravity := Vector2Create(0, 0);
   PE.Burst := False;
   PE.Play;
   FEmitE.AddComponent(PE);
   World.Init;
end;

procedure TParticleDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TParticleDemoScene.Update(ADelta: Single);
var
   PE: TParticleEmitterComponent;
   Tr: TTransformComponent;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   PE := Emitter;
   if IsKeyPressed(KEY_ONE) then
      SetShape(esPoint);
   if IsKeyPressed(KEY_TWO) then
      SetShape(esCircle);
   if IsKeyPressed(KEY_THREE) then
      SetShape(esRectangle);
   if IsKeyPressed(KEY_FOUR) then
      SetShape(esCone);
   if IsKeyPressed(KEY_B) then
   begin
      PE.Burst := True;
      PE.Play;
      PE.Burst := False;
   end;
   if IsKeyPressed(KEY_G) then
   begin
      FUseGravity := not FUseGravity;
      if FUseGravity then
         PE.Gravity := Vector2Create(0, 200)
      else
         PE.Gravity := Vector2Create(0, 0);
   end;
   if IsKeyPressed(KEY_P) then
   begin
      if PE.IsEmitting then
         PE.Stop
      else
         PE.Play;
   end;
   if IsMouseButtonDown(MOUSE_BUTTON_LEFT) then
   begin
      Tr := EmitTr;
      Tr.Position.X := GetMouseX;
      Tr.Position.Y := GetMouseY;
   end;
   World.Update(ADelta);
end;

procedure TParticleDemoScene.Render;
var
   PE: TParticleEmitterComponent;
   Tr: TTransformComponent;
begin
   ClearBackground(ColorCreate(12, 12, 20, 255));
   World.Render;
   PE := Emitter;
   Tr := EmitTr;
   case PE.EmitterShape of
      esCircle:
         DrawCircleLines(Round(Tr.Position.X), Round(Tr.Position.Y), PE.EmitterSize.X, COL_DIMTEXT);
      esRectangle:
         DrawRectangleLinesEx(RectangleCreate(Tr.Position.X - PE.EmitterSize.X * 0.5, Tr.Position.Y - PE.EmitterSize.Y * 0.5, PE.EmitterSize.X, PE.EmitterSize.Y), 1, COL_DIMTEXT);
   end;
   DrawCircle(Round(Tr.Position.X), Round(Tr.Position.Y), 4, COL_ACCENT);
   DrawHeader('Demo 17 - Particle Emitter (TParticleEmitterComponent + TParticleSystem)');
   DrawFooter('1=Point 2=Circle 3=Rect 4=Cone  B=Burst  G=Gravity  P=Play/Stop  LMB=Move');
   DrawPanel(SCR_W - 295, DEMO_AREA_Y + 10, 285, 240, 'Emitter State');
   DrawText(PChar('Shape     : ' + SNAMES[PE.EmitterShape]), SCR_W - 285, DEMO_AREA_Y + 34, 12, COL_ACCENT);
   DrawText(PChar('Emitting  : ' + IfThen(PE.IsEmitting, 'YES', 'STOPPED')), SCR_W - 285, DEMO_AREA_Y + 54, 12, IfThen(PE.IsEmitting, COL_GOOD, COL_BAD));
   DrawText(PChar('Gravity   : ' + IfThen(FUseGravity, 'ON (0,200)', 'OFF')), SCR_W - 285, DEMO_AREA_Y + 74, 12, COL_TEXT);
   DrawText(PChar(Format('Rate      : %.0f /s', [PE.EmissionRate])), SCR_W - 285, DEMO_AREA_Y + 94, 12, COL_TEXT);
   DrawText(PChar(Format('Life      : %.1f..%.1f s', [PE.ParticleLifeMin, PE.ParticleLifeMax])), SCR_W - 285, DEMO_AREA_Y + 114, 12, COL_TEXT);
   DrawText(PChar(Format('Speed     : %.0f..%.0f', [PE.ParticleSpeedMin, PE.ParticleSpeedMax])), SCR_W - 285, DEMO_AREA_Y + 134, 12, COL_TEXT);
   DrawText('ColorStart : GOLD', SCR_W - 285, DEMO_AREA_Y + 154, 12, COL_WARN);
   DrawText('ColorEnd   : EMBER', SCR_W - 285, DEMO_AREA_Y + 174, 12, COL_BAD);
end;

end.
