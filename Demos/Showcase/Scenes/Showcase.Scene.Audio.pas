unit Showcase.Scene.Audio;

{$mode objfpc}{$H+}

{ Demo 23 - Audio System (TAudioSystem + TMusicPlayerComponent)
  TAudioSystem subscribes to audio events in Init:
    TAudioPlaySoundEvent(path,vol,pitch,pan) -> LoadSound -> PlaySound
    TAudioPlayMusicEvent(path,vol) -> StopAllMusic -> LoadMusic -> PlayMusicStream
    TAudioStopMusicEvent -> StopMusicStream
    TAudioSetVolumeEvent(vol) -> SetMasterVolume
  UpdateMusicStream called each Update for active music.
  Asset paths relative to bin/ (working dir of the executable).
  Controls: 1=coin SFX  2=jump SFX  3=stomp SFX
            M=music  N=stop music  +/-=master volume }
interface

uses
   SysUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.MusicPlayer,
   P2D.Systems.Audio,
   Showcase.Common;

type
   TAudioDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FAudioSys: TAudioSystem;
      FMasterVolume: Single;
      FLog: array[0..9] of String;
      FLogN: Integer;
      procedure Log(const S: String);
      procedure PlaySFX(const APath: String; AVol: Single = 1; APitch: Single = 1);
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
   SFX_COIN = 'assets/audio/sfx/coin.wav';
   SFX_JUMP = 'assets/audio/sfx/jump.wav';
   SFX_STOMP = 'assets/audio/sfx/stomp.wav';
   BGM_OVER = 'assets/audio/bgm/overworld.mp3';

constructor TAudioDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('Audio');
   FScreenW := AW;
   FScreenH := AH;
   FMasterVolume := 1;
end;

procedure TAudioDemoScene.Log(const S: String);
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

procedure TAudioDemoScene.PlaySFX(const APath: String; AVol, APitch: Single);
begin
   { Publish event; TAudioSystem handles it. Bus owns the event object. }
   World.EventBus.Publish(TAudioPlaySoundEvent.Create(APath, AVol, APitch));
   Log(Format('[SFX] %s (vol=%.1f)', [ExtractFileName(APath), AVol]));
end;

procedure TAudioDemoScene.DoLoad;
begin
   FAudioSys := TAudioSystem(World.AddSystem(TAudioSystem.Create(World)));
end;

procedure TAudioDemoScene.DoEnter;
var
   ME: TEntity;
   Tr: TTransformComponent;
   MP: TMusicPlayerComponent;
begin
   FLogN := 0;
   FMasterVolume := 1;
   ME := World.CreateEntity('MusicPlayer');
   Tr := TTransformComponent.Create;
   ME.AddComponent(Tr);
   MP := TMusicPlayerComponent.Create;
   MP.Volume := 0.7;
   MP.AutoPlay := False;
   MP.Loop := True;
   ME.AddComponent(MP);
   World.Init;
   Log('Audio system ready. 1/2/3=SFX  M=music  N=stop  +/-=vol');
end;

procedure TAudioDemoScene.DoExit;
begin
   World.EventBus.Publish(TAudioStopMusicEvent.Create);
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TAudioDemoScene.Update(ADelta: Single);
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_ONE) then
      PlaySFX(SFX_COIN, 1.0);
   if IsKeyPressed(KEY_TWO) then
      PlaySFX(SFX_JUMP, 1.0);
   if IsKeyPressed(KEY_THREE) then
      PlaySFX(SFX_STOMP, 0.9);
   if IsKeyPressed(KEY_M) then
   begin
      World.EventBus.Publish(TAudioPlayMusicEvent.Create(BGM_OVER, 0.7));
      Log('[MUSIC] Starting BGM');
   end;
   if IsKeyPressed(KEY_N) then
   begin
      World.EventBus.Publish(TAudioStopMusicEvent.Create);
      Log('[MUSIC] Stopped');
   end;
   if IsKeyDown(KEY_EQUAL) then
   begin
      FMasterVolume := Min(1, FMasterVolume + ADelta * 0.5);
      World.EventBus.Publish(TAudioSetVolumeEvent.Create(FMasterVolume));
   end;
   if IsKeyDown(KEY_MINUS) then
   begin
      FMasterVolume := Max(0, FMasterVolume - ADelta * 0.5);
      World.EventBus.Publish(TAudioSetVolumeEvent.Create(FMasterVolume));
   end;
   World.Update(ADelta);
end;

procedure TAudioDemoScene.Render;
var
   I: Integer;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 23 - Audio System (TAudioSystem + TMusicPlayerComponent)');
   DrawFooter('1=coin  2=jump  3=stomp  M=music  N=stop  +/-=master volume');
   DrawPanel(30, DEMO_AREA_Y + 10, 450, 200, 'Event-Driven Audio');
   DrawText('World.EventBus.Publish(', 42, DEMO_AREA_Y + 34, 11, COL_TEXT);
   DrawText('  TAudioPlaySoundEvent.Create(path));', 42, DEMO_AREA_Y + 50, 11, COL_DIMTEXT);
   DrawText('-> TAudioSystem.OnPlaySound fires.', 42, DEMO_AREA_Y + 66, 11, COL_DIMTEXT);
   DrawText('-> ResourceManager caches TSound.', 42, DEMO_AREA_Y + 82, 11, COL_DIMTEXT);
   DrawText('-> PlaySound(Snd) executes.', 42, DEMO_AREA_Y + 98, 11, COL_DIMTEXT);
   DrawText('Music: TAudioPlayMusicEvent.', 42, DEMO_AREA_Y + 118, 11, COL_DIMTEXT);
   DrawText('-> Finds TMusicPlayerComponent.', 42, DEMO_AREA_Y + 134, 11, COL_DIMTEXT);
   DrawText('-> Streams via UpdateMusicStream.', 42, DEMO_AREA_Y + 150, 11, COL_DIMTEXT);
   DrawPanel(30, DEMO_AREA_Y + 220, 450, 60, 'Master Volume');
   DrawRectangle(42, DEMO_AREA_Y + 244, 420, 18, ColorCreate(40, 40, 55, 255));
   DrawRectangle(42, DEMO_AREA_Y + 244, Round(420 * FMasterVolume), 18, COL_GOOD);
   DrawText(PChar(Format('%.0f%%', [FMasterVolume * 100])), 470, DEMO_AREA_Y + 244, 13, COL_TEXT);
   DrawPanel(30, DEMO_AREA_Y + 290, 450, 270, 'Event Log');
   for I := 0 to FLogN - 1 do
      DrawText(PChar(FLog[I]), 42, DEMO_AREA_Y + 314 + I * 22, 11,
         IfThen(Pos('[SFX]', FLog[I]) > 0, COL_GOOD, IfThen(Pos('[MUSIC]', FLog[I]) > 0, COL_ACCENT, COL_DIMTEXT)));
end;

end.
