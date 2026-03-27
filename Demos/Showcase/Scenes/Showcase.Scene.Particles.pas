unit Showcase.Scene.Particles;

{$mode objfpc}{$H+}

{ Demo 17 - Particles  NEW: dungeon-wall backdrop + torch sprite at emitter. }
interface

uses
   SysUtils, StrUtils, Math, raylib, P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.ParticleEmitter, P2D.Systems.Particles, Showcase.Common;

type
   TParticleDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FEmitE: TEntity;
      FPartSys: TParticleSystem;
      FTRID, FPEID: integer;
      FUseGravity: boolean;
      FTexWall, FTexTorch: TTexture2D;
      procedure GenEmitterTextures;
      procedure FreeEmitterTextures;
      function Emitter: TParticleEmitterComponent;
      function EmitTr: TTransformComponent;
      procedure SetShape(AShape: TEmitterShape2D);
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AW, AH: integer);
      procedure Update(ADelta: single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Systems.SceneManager;

const
   SNAMES: array[TEmitterShape2D] of string = ('esPoint', 'esCircle', 'esRectangle', 'esCone');

function IfStr(B: boolean; const T, F: string): string;
begin
   if B then
      Result := T
   else
      Result := F;
end;

function IfCol(B: boolean; const T, F: TColor): TColor;
begin
   if B then
      Result := T
   else
      Result := F;
end;

constructor TParticleDemoScene.Create(AW, AH: integer);
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

procedure TParticleDemoScene.GenEmitterTextures;
var
   Img: TImage;
begin
   Img := GenImageColor(64, 64, ColorCreate(48, 42, 36, 255));
   ImageDrawRectangle(@Img, 1, 1, 62, 62, ColorCreate(58, 52, 44, 255));
   ImageDrawRectangle(@Img, 0, 32, 64, 2, ColorCreate(38, 34, 28, 255));
   ImageDrawRectangle(@Img, 32, 0, 2, 32, ColorCreate(38, 34, 28, 255));
   ImageDrawRectangle(@Img, 1, 1, 62, 2, ColorCreate(72, 66, 56, 200));
   FTexWall := LoadTextureFromImage(Img);
   UnloadImage(Img);
   Img := GenImageColor(32, 48, ColorCreate(0, 0, 0, 0));
   ImageDrawRectangle(@Img, 13, 24, 6, 24, ColorCreate(110, 80, 38, 255));
   ImageDrawRectangle(@Img, 8, 18, 16, 8, ColorCreate(130, 100, 50, 255));
   ImageDrawRectangle(@Img, 9, 8, 14, 14, ColorCreate(255, 150, 20, 220));
   ImageDrawRectangle(@Img, 11, 4, 10, 10, ColorCreate(255, 200, 40, 200));
   ImageDrawRectangle(@Img, 13, 0, 6, 8, ColorCreate(255, 240, 120, 180));
   FTexTorch := LoadTextureFromImage(Img);
   UnloadImage(Img);
end;

procedure TParticleDemoScene.FreeEmitterTextures;

   procedure U(var T: TTexture2D);
   begin
      if T.Id > 0 then
      begin
         UnloadTexture(T);
         T.Id := 0;
      end;
   end;

begin
   U(FTexWall);
   U(FTexTorch);
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
   GenEmitterTextures;
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
   FreeEmitterTextures;
end;

procedure TParticleDemoScene.Update(ADelta: single);
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
      if PE.IsEmitting then
         PE.Stop
      else
         PE.Play;
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
   TX, TY: integer;
begin
   ClearBackground(ColorCreate(10, 10, 18, 255));
   if FTexWall.Id > 0 then
   begin
      TY := DEMO_AREA_Y;
      while TY < SCR_H - FOOTER_H do
      begin
         TX := 0;
         while TX < SCR_W do
         begin
            DrawTexturePro(FTexWall, RectangleCreate(0, 0, 64, 64), RectangleCreate(TX, TY, 64, 64), Vector2Create(0, 0), 0, ColorCreate(255, 255, 255, 200));
            Inc(TX, 64);
         end;
         Inc(TY, 64);
      end;
   end;
   World.Render;
   PE := Emitter;
   Tr := EmitTr;
   if FTexTorch.Id > 0 then
      DrawTexturePro(FTexTorch, RectangleCreate(0, 0, 32, 48),
         RectangleCreate(Round(Tr.Position.X) - 16, Round(Tr.Position.Y) - 36, 32, 48), Vector2Create(0, 0), 0, WHITE)
   else
      DrawCircle(Round(Tr.Position.X), Round(Tr.Position.Y), 6, COL_ACCENT);
   case PE.EmitterShape of
      esCircle:
         DrawCircleLines(Round(Tr.Position.X), Round(Tr.Position.Y), PE.EmitterSize.X, COL_DIMTEXT);
      esRectangle:
         DrawRectangleLinesEx(RectangleCreate(Tr.Position.X - PE.EmitterSize.X * 0.5, Tr.Position.Y - PE.EmitterSize.Y * 0.5, PE.EmitterSize.X, PE.EmitterSize.Y), 1, COL_DIMTEXT);
   end;
   DrawHeader('Demo 17 - Particle Emitter (TParticleEmitterComponent + TParticleSystem)');
   DrawFooter('1=Point 2=Circle 3=Rect 4=Cone  B=Burst  G=Gravity  P=Play/Stop  LMB=Move');
   DrawPanel(SCR_W - 298, DEMO_AREA_Y + 10, 288, 266, 'Emitter State');
   DrawText(PChar('Shape    : ' + SNAMES[PE.EmitterShape]), SCR_W - 288, DEMO_AREA_Y + 34, 12, COL_ACCENT);
   DrawText(PChar('Emitting : ' + IfStr(PE.IsEmitting, 'YES', 'STOPPED')), SCR_W - 288, DEMO_AREA_Y + 54, 12, IfCol(PE.IsEmitting, COL_GOOD, COL_BAD));
   DrawText(PChar('Gravity  : ' + IfStr(FUseGravity, 'ON (0,200)', 'OFF')), SCR_W - 288, DEMO_AREA_Y + 74, 12, COL_TEXT);
   DrawText(PChar(Format('Rate     : %.0f /s', [PE.EmissionRate])), SCR_W - 288, DEMO_AREA_Y + 94, 12, COL_TEXT);
   DrawText(PChar(Format('Life     : %.1f..%.1f s', [PE.ParticleLifeMin, PE.ParticleLifeMax])), SCR_W - 288, DEMO_AREA_Y + 114, 12, COL_TEXT);
   DrawText(PChar(Format('Speed    : %.0f..%.0f', [PE.ParticleSpeedMin, PE.ParticleSpeedMax])), SCR_W - 288, DEMO_AREA_Y + 134, 12, COL_TEXT);
   DrawText('ColorStart: GOLD', SCR_W - 288, DEMO_AREA_Y + 154, 12, COL_WARN);
   DrawText('ColorEnd  : EMBER', SCR_W - 288, DEMO_AREA_Y + 174, 12, COL_BAD);
   if FTexTorch.Id > 0 then
      DrawTexturePro(FTexTorch, RectangleCreate(0, 0, 32, 48),
         RectangleCreate(SCR_W - 68, DEMO_AREA_Y + 186, 32, 48), Vector2Create(0, 0), 0, WHITE);
end;

end.
