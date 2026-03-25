unit Showcase.Scene.Chunk;

{$mode objfpc}{$H+}

{ Demo 10 - Infinite Chunk System
  WASD = move camera; chunks load and unload automatically }
interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.Event, P2D.Core.Events,
   P2D.Components.Transform, P2D.Components.Camera2D, P2D.Components.Chunk,
   P2D.Systems.Chunk, P2D.Common, Showcase.Common;

type
   TChunkDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FCamE: TEntity;
      FChunkSys: TChunkSystem2D;
      FLoaded, FTotal: integer;
      FTRID, FCHID: integer;
      FLog: array[0..7] of string;
      FLogN: integer;
      procedure GenChunk(CX, CY: integer; AChunk: TChunkComponent2D);
      procedure OnCL(AEvent: TEvent2D);
      procedure OnCU(AEvent: TEvent2D);
      procedure Log(const S: string);
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

constructor TChunkDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Chunk');
   FScreenW := AW;
   FScreenH := AH;
end;

procedure TChunkDemoScene.Log(const S: string);
var
   I: integer;
begin
   if FLogN < 8 then
   begin
      FLog[FLogN] := S;
      Inc(FLogN);
   end
   else
   begin
      for I := 0 to 6 do
         FLog[I] := FLog[I + 1];
      FLog[7] := S;
   end;
end;

procedure TChunkDemoScene.GenChunk(CX, CY: integer; AChunk: TChunkComponent2D);
var
   R, C: integer;
begin
   for R := 0 to CHUNK_SIZE - 1 do
      for C := 0 to CHUNK_SIZE - 1 do
         if ((CX * CHUNK_SIZE + C) + (CY * CHUNK_SIZE + R)) mod 7 = 0 then
            AChunk.SetTile(C, R, 1)
         else
            AChunk.SetTile(C, R, 0);
end;

procedure TChunkDemoScene.OnCL(AEvent: TEvent2D);
var
   Ev: TChunkLoadedEvent2D;
begin
   Ev := TChunkLoadedEvent2D(AEvent);
   Inc(FLoaded);
   Inc(FTotal);
   Log(Format('+ Chunk (%d,%d) loaded', [Ev.ChunkX, Ev.ChunkY]));
end;

procedure TChunkDemoScene.OnCU(AEvent: TEvent2D);
var
   Ev: TChunkUnloadedEvent2D;
begin
   Ev := TChunkUnloadedEvent2D(AEvent);
   Dec(FLoaded);
   Log(Format('- Chunk (%d,%d) unloaded', [Ev.ChunkX, Ev.ChunkY]));
end;

procedure TChunkDemoScene.DoLoad;
begin
   FChunkSys := TChunkSystem2D(World.AddSystem(TChunkSystem2D.Create(World, 16, 1)));
   FChunkSys.OnGenerateChunk := @GenChunk;
end;

procedure TChunkDemoScene.DoEnter;
var
   Tr: TTransformComponent;
   Cam: TCamera2DComponent;
begin
   FLoaded := 0;
   FTotal := 0;
   FLogN := 0;
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FCHID := ComponentRegistry.GetComponentID(TChunkComponent2D);
   FCamE := World.CreateEntity('Camera');
   Tr := TTransformComponent.Create;
   Tr.Position.X := 0;
   Tr.Position.Y := 0;
   FCamE.AddComponent(Tr);
   Cam := TCamera2DComponent.Create;
   FCamE.AddComponent(Cam);
   World.Init;
   World.EventBus.Subscribe(TChunkLoadedEvent2D, @OnCL);
   World.EventBus.Subscribe(TChunkUnloadedEvent2D, @OnCU);
end;

procedure TChunkDemoScene.DoExit;
begin
   World.EventBus.Unsubscribe(TChunkLoadedEvent2D, @OnCL);
   World.EventBus.Unsubscribe(TChunkUnloadedEvent2D, @OnCU);
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TChunkDemoScene.Update(ADelta: single);
var
   Tr: TTransformComponent;
   Spd: single;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   Tr := TTransformComponent(FCamE.GetComponentByID(FTRID));
   Spd := 200 * ADelta;
   if IsKeyDown(KEY_W) then
      Tr.Position.Y := Tr.Position.Y - Spd;
   if IsKeyDown(KEY_S) then
      Tr.Position.Y := Tr.Position.Y + Spd;
   if IsKeyDown(KEY_A) then
      Tr.Position.X := Tr.Position.X - Spd;
   if IsKeyDown(KEY_D) then
      Tr.Position.X := Tr.Position.X + Spd;
   World.Update(ADelta);
end;

procedure TChunkDemoScene.Render;
const
   CP = 14;
   DR = 4;
var
   Tr: TTransformComponent;
   CamX, CamY: single;
   CCX, CCY, I: integer;
   E: TEntity;
   Ch: TChunkComponent2D;
   ChTr: TTransformComponent;
   GX, GY, C, R, TV: integer;
begin
   ClearBackground(ColorCreate(15, 10, 20, 255));
   DrawHeader('Demo 10 - Infinite Chunk System (TChunkSystem2D)');
   DrawFooter('WASD = scroll camera   chunks load and unload automatically');
   Tr := TTransformComponent(FCamE.GetComponentByID(FTRID));
   CamX := Tr.Position.X;
   CamY := Tr.Position.Y;
   CCX := Trunc(CamX / (CHUNK_SIZE * 16));
   CCY := Trunc(CamY / (CHUNK_SIZE * 16));
   for E in World.Entities.GetAll do
   begin
      if not E.Alive then
         Continue;
      Ch := TChunkComponent2D(E.GetComponentByID(FCHID));
      if not Assigned(Ch) then
         Continue;
      ChTr := TTransformComponent(E.GetComponentByID(FTRID));
      if not Assigned(ChTr) then
         Continue;
      if (Abs(Ch.ChunkX - CCX) > DR) or (Abs(Ch.ChunkY - CCY) > DR) then
         Continue;
      for R := 0 to CHUNK_SIZE - 1 do
         for C := 0 to CHUNK_SIZE - 1 do
         begin
            TV := Ch.GetTile(C, R);
            GX := Round(DEMO_AREA_CX + (ChTr.Position.X + C * 16 - CamX) * 0.5);
            GY := Round(DEMO_AREA_CY + (ChTr.Position.Y + R * 16 - CamY) * 0.5);
            if TV = 1 then
               DrawRectangle(GX, GY, CP, CP, ColorCreate(80, 60, 40, 255))
            else
               DrawRectangle(GX, GY, CP, CP,
                  ColorCreate(30 + ((Ch.ChunkX mod 5) * 12), 30 + ((Ch.ChunkY mod 5) * 12), 50, 255));
         end;
      GX := Round(DEMO_AREA_CX + (ChTr.Position.X - CamX) * 0.5);
      GY := Round(DEMO_AREA_CY + (ChTr.Position.Y - CamY) * 0.5);
      DrawRectangleLinesEx(RectangleCreate(GX, GY, CHUNK_SIZE * CP, CHUNK_SIZE * CP),
         1, ColorCreate(80, 80, 120, 80));
      DrawText(PChar(Format('%d,%d', [Ch.ChunkX, Ch.ChunkY])), GX + 2, GY + 2, 8, ColorCreate(120, 120, 160, 180));
   end;
   DrawLine(DEMO_AREA_CX - 12, DEMO_AREA_CY, DEMO_AREA_CX + 12, DEMO_AREA_CY, COL_ACCENT);
   DrawLine(DEMO_AREA_CX, DEMO_AREA_CY - 12, DEMO_AREA_CX, DEMO_AREA_CY + 12, COL_ACCENT);
   DrawCircleLines(DEMO_AREA_CX, DEMO_AREA_CY, 6, COL_ACCENT);
   DrawPanel(SCR_W - 280, DEMO_AREA_Y + 10, 270, 130, 'Stats');
   DrawText(PChar('Loaded: ' + IntToStr(FLoaded)), SCR_W - 270, DEMO_AREA_Y + 34, 13, COL_GOOD);
   DrawText(PChar('Total ever: ' + IntToStr(FTotal)), SCR_W - 270, DEMO_AREA_Y + 54, 13, COL_TEXT);
   DrawText(PChar(Format('Cam: (%.0f,%.0f)', [CamX, CamY])), SCR_W - 270, DEMO_AREA_Y + 74, 12, COL_DIMTEXT);
   DrawText(PChar(Format('ChunkCoord: (%d,%d)', [CCX, CCY])), SCR_W - 270, DEMO_AREA_Y + 92, 12, COL_DIMTEXT);
   DrawPanel(SCR_W - 280, DEMO_AREA_Y + 148, 270, 200, 'Event Log');
   for I := 0 to FLogN - 1 do
      DrawText(PChar(FLog[I]), SCR_W - 270, DEMO_AREA_Y + 172 + I * 22, 10, COL_TEXT);
end;

end.
