unit Showcase.Scene.EventBus;

{$mode objfpc}{$H+}

{ Demo 24 - Event Bus (TEventBus)
  Double-buffered deferred dispatch: Publish adds to FWriteQueue.
  World.Update -> EventBus.Dispatch swaps queues, iterates FReadQueue.
  For each event: walk class hierarchy (exact class first -> parents).
  If AEvent.Handled = True -> stops chain (specific handlers before catch-all).
  Events published IN handlers -> deferred to next Dispatch (no re-entrancy).
  Local event types defined in implementation section (local use only).
  Controls: 1=ScoreEvent  2=DamageEvent  3=ItemEvent  H=handle-mode  C=clear }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.Event,
   Showcase.Common;

type
   TEventBusDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FHandleMode: boolean;
      FScore, FHP: Integer;
      FLog: array[0..11] of String;
      FLogN: Integer;
      procedure LogEntry(const S: String);
      procedure OnScore(AEvent: TEvent2D);
      procedure OnDamage(AEvent: TEvent2D);
      procedure OnItem(AEvent: TEvent2D);
      procedure OnAny(AEvent: TEvent2D);
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
   { Local event classes — only needed inside this unit }
type
   TScoreEvent = class(TEvent2D)
   public
      Points: Integer;
      constructor Create(P: Integer);
   end;

   TDamageEvent = class(TEvent2D)
   public
      Damage: Integer;
      constructor Create(D: Integer);
   end;

   TItemEvent = class(TEvent2D)
   public
      ItemName: String;
      constructor Create(const N: String);
   end;

constructor TScoreEvent.Create(P: Integer);
begin
   inherited Create;
   Points := P;
end;

constructor TDamageEvent.Create(D: Integer);
begin
   inherited Create;
   Damage := D;
end;

constructor TItemEvent.Create(const N: String);
begin
   inherited Create;
   ItemName := N;
end;

constructor TEventBusDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('EventBus');
   FScreenW := AW;
   FScreenH := AH;
   FHandleMode := False;
   FScore := 0;
   FHP := 100;
end;

procedure TEventBusDemoScene.LogEntry(const S: String);
var
   I: Integer;
begin
   if FLogN < 12 then
   begin
      FLog[FLogN] := S;
      Inc(FLogN);
   end
   else
   begin
      for I := 0 to 10 do
         FLog[I] := FLog[I + 1];
      FLog[11] := S;
   end;
end;

procedure TEventBusDemoScene.OnScore(AEvent: TEvent2D);
var
   Ev: TScoreEvent;
begin
   Ev := TScoreEvent(AEvent);
   Inc(FScore, Ev.Points);
   LogEntry(Format('[OnScore] +%d -> Score=%d', [Ev.Points, FScore]));
   if FHandleMode then
   begin
      Ev.Handled := True;
      LogEntry('  (Handled=True -> chain STOPS)');
   end;
end;

procedure TEventBusDemoScene.OnDamage(AEvent: TEvent2D);
var
   Ev: TDamageEvent;
begin
   Ev := TDamageEvent(AEvent);
   Dec(FHP, Ev.Damage);
   if FHP < 0 then
      FHP := 100;
   LogEntry(Format('[OnDamage] -%d -> HP=%d', [Ev.Damage, FHP]));
   if FHandleMode then
      Ev.Handled := True;
end;

procedure TEventBusDemoScene.OnItem(AEvent: TEvent2D);
var
   Ev: TItemEvent;
begin
   Ev := TItemEvent(AEvent);
   LogEntry(Format('[OnItem] Picked up "%s"', [Ev.ItemName]));
   if FHandleMode then
      Ev.Handled := True;
end;
{ Subscribed to base TEvent2D — receives ALL events unless Handled=True stops the chain }
procedure TEventBusDemoScene.OnAny(AEvent: TEvent2D);
begin
   LogEntry(Format('  [Catch-all] %s reached base handler.', [AEvent.ClassName]));
end;

procedure TEventBusDemoScene.DoLoad;
begin
end;

procedure TEventBusDemoScene.DoEnter;
begin
   FLogN := 0;
   FScore := 0;
   FHP := 100;
   FHandleMode := False;
   World.Init;
   World.EventBus.Subscribe(TScoreEvent, @OnScore);
   World.EventBus.Subscribe(TDamageEvent, @OnDamage);
   World.EventBus.Subscribe(TItemEvent, @OnItem);
   World.EventBus.Subscribe(TEvent2D, @OnAny);  { catch-all }
   LogEntry('EventBus ready. Press 1/2/3 to publish events.');
end;

procedure TEventBusDemoScene.DoExit;
begin
   World.EventBus.Unsubscribe(TScoreEvent, @OnScore);
   World.EventBus.Unsubscribe(TDamageEvent, @OnDamage);
   World.EventBus.Unsubscribe(TItemEvent, @OnItem);
   World.EventBus.Unsubscribe(TEvent2D, @OnAny);
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TEventBusDemoScene.Update(ADelta: Single);
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_ONE) then
   begin
      World.EventBus.Publish(TScoreEvent.Create(10));
      LogEntry('>> Published TScoreEvent(10) — dispatches next frame.');
   end;
   if IsKeyPressed(KEY_TWO) then
   begin
      World.EventBus.Publish(TDamageEvent.Create(15));
      LogEntry('>> Published TDamageEvent(15)');
   end;
   if IsKeyPressed(KEY_THREE) then
   begin
      World.EventBus.Publish(TItemEvent.Create('HealthPotion'));
      LogEntry('>> Published TItemEvent(HealthPotion)');
   end;
   if IsKeyPressed(KEY_H) then
   begin
      FHandleMode := not FHandleMode;
      LogEntry(IfThen(FHandleMode, '** Handle mode ON — stops chain.', '** Handle mode OFF.'));
   end;
   if IsKeyPressed(KEY_C) then
      FLogN := 0;
   World.Update(ADelta);
end;

procedure TEventBusDemoScene.Render;
var
   I: Integer;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 24 - Event Bus (TEventBus — hierarchy dispatch, Handled flag)');
   DrawFooter('1=Score  2=Damage  3=Item  H=toggle handle-mode  C=clear log');
   DrawPanel(30, DEMO_AREA_Y + 10, 440, 200, 'Dispatch Flow (per frame)');
   DrawText('1. EventBus.Publish(Ev) -> Ev added to FWriteQueue.', 42, DEMO_AREA_Y + 34, 11, COL_TEXT);
   DrawText('2. World.Update() calls Dispatch().', 42, DEMO_AREA_Y + 50, 11, COL_TEXT);
   DrawText('3. FWriteQueue <-> FReadQueue (swap).', 42, DEMO_AREA_Y + 66, 11, COL_TEXT);
   DrawText('4. Walk class hierarchy: exact class first.', 42, DEMO_AREA_Y + 82, 11, COL_DIMTEXT);
   DrawText('5. If Ev.Handled=True -> stop, TEvent2D skipped.', 42, DEMO_AREA_Y + 98, 11, COL_DIMTEXT);
   DrawText('6. Events published in handlers -> next Dispatch.', 42, DEMO_AREA_Y + 114, 11, COL_DIMTEXT);
   DrawPanel(30, DEMO_AREA_Y + 220, 200, 80, 'Game State');
   DrawText(PChar('Score : ' + IntToStr(FScore)), 42, DEMO_AREA_Y + 244, 13, COL_GOOD);
   DrawText(PChar('HP    : ' + IntToStr(FHP)), 42, DEMO_AREA_Y + 266, 13, IfThen(FHP > 50, COL_GOOD, COL_BAD));
   DrawPanel(240, DEMO_AREA_Y + 220, 230, 80, 'Handle Mode');
   DrawText(PChar(IfThen(FHandleMode, 'ON — stops chain', 'OFF — catch-all fires')),
      252, DEMO_AREA_Y + 244, 12, IfThen(FHandleMode, COL_BAD, COL_GOOD));
   DrawPanel(30, DEMO_AREA_Y + 310, 900, 260, 'Dispatch Log');
   for I := 0 to FLogN - 1 do
      DrawText(PChar(FLog[I]), 42, DEMO_AREA_Y + 334 + I * 16, 10,
         IfThen(Pos('>>', FLog[I]) > 0, COL_ACCENT, IfThen(Pos('[Catch', FLog[I]) > 0, COL_WARN, IfThen(Pos('Handled', FLog[I]) > 0, COL_BAD, IfThen(Pos('**', FLog[I]) > 0, COL_DIMTEXT, COL_TEXT)))));
end;

end.
