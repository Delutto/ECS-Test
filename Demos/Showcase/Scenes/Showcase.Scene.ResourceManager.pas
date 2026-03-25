unit Showcase.Scene.ResourceManager;

{$mode objfpc}{$H+}

{ Demo 25 - Resource Manager (TResourceManager2D)
  Singleton ref-counted asset cache. API:
    LoadTexture(path)   -> RefCount++; if new -> raylib.LoadTexture
    UnloadTexture(path) -> RefCount--; if 0   -> raylib.UnloadTexture, removed from cache
    LoadFont/Sound/Music/Shader follow the same pattern.
    GetResourceCount: Integer - cached resources total
    GetMemoryUsage: Int64    - estimated VRAM bytes
  Controls: L=load  U=unload  R=print stats to console }
interface

uses
   SysUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.ResourceManager,
   Showcase.Common;

type
   TResourceManagerDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FLoadCount, FUnloadCount: Integer;
      FDisplayTex: TTexture2D;
      FLog: array[0..9] of String;
      FLogN: Integer;
      function RM: TResourceManager2D;
      procedure Log(const S: String);
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
   TEX_PATH = 'assets/graphics/coin.png';

constructor TResourceManagerDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('ResourceManager');
   FScreenW := AW;
   FScreenH := AH;
end;

function TResourceManagerDemoScene.RM: TResourceManager2D;
begin
   Result := TResourceManager2D.Instance;
end;

procedure TResourceManagerDemoScene.Log(const S: String);
var
   I: Integer;
begin
   if FLogN < 10 then
   begin
      FLog[FLogN] := S;
      Inc(FLogN);
   end
   else
   begin
      for I := 0 to 8 do
         FLog[I] := FLog[I + 1];
      FLog[9] := S;
   end;
end;

procedure TResourceManagerDemoScene.DoLoad;
begin
end;

procedure TResourceManagerDemoScene.DoEnter;
begin
   FLoadCount := 0;
   FUnloadCount := 0;
   FLogN := 0;
   FillChar(FDisplayTex, SizeOf(FDisplayTex), 0);
   World.Init;
   Log('L=load  U=unload  R=stats');
   Log(Format('Resources cached at start: %d', [RM.GetResourceCount]));
end;

procedure TResourceManagerDemoScene.DoExit;
var
   I: Integer;
begin
   for I := 1 to FLoadCount - FUnloadCount do
      RM.UnloadTexture(TEX_PATH);
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TResourceManagerDemoScene.Update(ADelta: Single);
var
   Tex: TTexture2D;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_L) then
   begin
      Tex := RM.LoadTexture(TEX_PATH);
      Inc(FLoadCount);
      if Tex.Id > 0 then
         Log(Format('LOAD #%d -> RefCount=%d', [FLoadCount, FLoadCount - FUnloadCount]))
      else
         Log('LOAD failed (file not found)');
      FDisplayTex := Tex;
   end;
   if IsKeyPressed(KEY_U) then
   begin
      if FLoadCount > FUnloadCount then
      begin
         RM.UnloadTexture(TEX_PATH);
         Inc(FUnloadCount);
         Log(Format('UNLOAD #%d -> RefCount=%d', [FUnloadCount, FLoadCount - FUnloadCount]));
         if FLoadCount = FUnloadCount then
         begin
            FillChar(FDisplayTex, SizeOf(FDisplayTex), 0);
            Log('RefCount=0 -> texture FREED from GPU.');
         end;
      end
      else
         Log('Nothing to unload (RefCount already 0).');
   end;
   if IsKeyPressed(KEY_R) then
   begin
      Log(Format('Total cached: %d  VRAM~%d KB', [RM.GetResourceCount, RM.GetMemoryUsage div 1024]));
      RM.PrintResourceStats;
   end;
   World.Update(ADelta);
end;

procedure TResourceManagerDemoScene.Render;
var
   I: Integer;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 25 - Resource Manager (TResourceManager2D — ref-counted cache)');
   DrawFooter('L=load   U=unload   R=print stats to console');
   DrawPanel(30, DEMO_AREA_Y + 10, 480, 220, 'Reference Count Lifecycle');
   DrawText('LoadTexture(path):', 42, DEMO_AREA_Y + 34, 11, COL_ACCENT);
   DrawText('  1st call -> raylib.LoadTexture  RefCount = 1', 42, DEMO_AREA_Y + 50, 11, COL_DIMTEXT);
   DrawText('  2nd call -> (cached)            RefCount = 2', 42, DEMO_AREA_Y + 66, 11, COL_DIMTEXT);
   DrawText('UnloadTexture(path):', 42, DEMO_AREA_Y + 84, 11, COL_ACCENT);
   DrawText('  1st call ->                     RefCount = 1', 42, DEMO_AREA_Y + 100, 11, COL_DIMTEXT);
   DrawText('  2nd call -> raylib.UnloadTexture RefCount = 0', 42, DEMO_AREA_Y + 116, 11, COL_BAD);
   DrawText('           -> entry removed from cache.', 42, DEMO_AREA_Y + 132, 11, COL_DIMTEXT);
   DrawPanel(30, DEMO_AREA_Y + 240, 480, 120, 'Current State');
   DrawText(PChar('Path      : ' + TEX_PATH), 42, DEMO_AREA_Y + 264, 11, COL_DIMTEXT);
   DrawText(PChar('Loads     : ' + IntToStr(FLoadCount)), 42, DEMO_AREA_Y + 284, 12, COL_TEXT);
   DrawText(PChar('Unloads   : ' + IntToStr(FUnloadCount)), 42, DEMO_AREA_Y + 302, 12, COL_TEXT);
   DrawText(PChar('RefCount  : ' + IntToStr(Max(0, FLoadCount - FUnloadCount))), 42, DEMO_AREA_Y + 322, 14, IfThen(FLoadCount > FUnloadCount, COL_GOOD, COL_DIMTEXT));
   if FDisplayTex.Id > 0 then
   begin
      DrawPanel(540, DEMO_AREA_Y + 10, 200, 200, 'Loaded Texture');
      DrawTexture(FDisplayTex, 580, DEMO_AREA_Y + 40, WHITE);
      DrawText(PChar(Format('%dx%d px', [FDisplayTex.Width, FDisplayTex.Height])),
         552, DEMO_AREA_Y + 170, 11, COL_DIMTEXT);
   end
   else
   begin
      DrawPanel(540, DEMO_AREA_Y + 10, 200, 200, 'No Texture Loaded');
      DrawText('(freed / never loaded)', 548, DEMO_AREA_Y + 80, 11, COL_BAD);
   end;
   DrawPanel(30, DEMO_AREA_Y + 370, 900, 200, 'Log');
   for I := 0 to FLogN - 1 do
      DrawText(PChar(FLog[I]), 42, DEMO_AREA_Y + 394 + I * 17, 10, COL_TEXT);
end;

end.
