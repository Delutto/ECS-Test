unit Showcase.Scene.StateMachine;

{$mode objfpc}{$H+}

{ Demo 18 - Finite State Machine (TStateMachineComponent2D + TStateMachineSystem2D)
  TStateMachineSystem2D (prio 6): calls FSM.Tick(dt) each frame.
  FSM.Tick: if pending transition -> OnExit(old) then OnEnter(new) then OnUpdate(cur,dt).
  SetInitialState: set starting state WITHOUT callbacks (use in construction).
  RequestTransition(newState): schedule transition; applied next Tick.
  Same-state transitions are silently ignored.
  Controls: 1=IDLE  2=WALK  3=RUN  4=ATTACK  5=HURT  A=auto-cycle }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.StateMachine,
   P2D.Systems.StateMachine, Showcase.Common;

const
   ST_IDLE = 0;
   ST_WALK = 1;
   ST_RUN = 2;
   ST_ATTACK = 3;
   ST_HURT = 4;

type
   TStateMachineDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FEntity: TEntity;
      FSMSys: TStateMachineSystem2D;
      FTRID, FSID: Integer;
      FCurrentStateName: String;
      FAutoMode: boolean;
      FAutoTimer: Single;
      FAutoStep: Integer;
      FStateTimer: Single;
      FEnterLog: array[0..7] of String;
      FEnterLogN: Integer;
      FEntityColor: TColor;
      FEntityScale: Single;
      procedure OnEnter(AEntityID: cardinal; AStateID: TStateID);
      procedure OnExit(AEntityID: cardinal; AStateID: TStateID);
      procedure OnUpdate(AEntityID: cardinal; AStateID: TStateID; ADelta: Single);
      procedure LogEntry(const S: String);
      function FSM: TStateMachineComponent2D;
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
   STATE_NAMES: array[0..4] of String = ('IDLE', 'WALK', 'RUN', 'ATTACK', 'HURT');
   STATE_COLS: array[0..4] of TColor = (
      (R: 80; G: 160; B: 255; A: 255), (R: 80; G: 220; B: 100; A: 255), (R: 255; G: 160; B: 60; A: 255),
      (R: 220; G: 60; B: 220; A: 255), (R: 255; G: 60; B: 60; A: 255));

constructor TStateMachineDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('StateMachine');
   FScreenW := AW;
   FScreenH := AH;
   FAutoMode := False;
end;

function TStateMachineDemoScene.FSM: TStateMachineComponent2D;
begin
   Result := TStateMachineComponent2D(FEntity.GetComponentByID(FSID));
end;

procedure TStateMachineDemoScene.LogEntry(const S: String);
var
   I: Integer;
begin
   if FEnterLogN < 8 then
   begin
      FEnterLog[FEnterLogN] := S;
      Inc(FEnterLogN);
   end
   else
   begin
      for I := 0 to 6 do
         FEnterLog[I] := FEnterLog[I + 1];
      FEnterLog[7] := S;
   end;
end;

procedure TStateMachineDemoScene.OnEnter(AEntityID: cardinal; AStateID: TStateID);
begin
   FCurrentStateName := STATE_NAMES[AStateID mod 5];
   FEntityColor := STATE_COLS[AStateID mod 5];
   FStateTimer := 0;
   case AStateID of
      ST_ATTACK:
         FEntityScale := 1.8;
      ST_HURT:
         FEntityScale := 0.8;
      else
         FEntityScale := 1;
   end;
   LogEntry('ENTER  ' + STATE_NAMES[AStateID mod 5]);
end;

procedure TStateMachineDemoScene.OnExit(AEntityID: cardinal; AStateID: TStateID);
begin
   LogEntry('  EXIT ' + STATE_NAMES[AStateID mod 5]);
   FEntityScale := 1;
end;

procedure TStateMachineDemoScene.OnUpdate(AEntityID: cardinal; AStateID: TStateID; ADelta: Single);
var
   Tr: TTransformComponent;
begin
   FStateTimer := FStateTimer + ADelta;
   Tr := TTransformComponent(FEntity.GetComponentByID(FTRID));
   case AStateID of
      ST_IDLE:
      begin
         Tr.Position.Y := DEMO_AREA_CY - 40 + Sin(FStateTimer * 2) * 12;
         FEntityScale := 1 + Sin(FStateTimer * 2) * 0.05;
      end;
      ST_WALK:
         Tr.Position.X := DEMO_AREA_CX + Sin(FStateTimer * 1.5) * 120;
      ST_RUN:
      begin
         Tr.Position.X := DEMO_AREA_CX + Sin(FStateTimer * 3) * 180;
         Tr.Position.Y := DEMO_AREA_CY - 40 + Abs(Sin(FStateTimer * 6)) * (-30);
      end;
      ST_ATTACK:
      begin
         FEntityScale := Max(1, 1.8 - FStateTimer * 1.6);
         if FStateTimer >= 0.5 then
            FSM.RequestTransition(ST_IDLE);
      end;
      ST_HURT:
         if FStateTimer >= 1 then
            FSM.RequestTransition(ST_IDLE);
   end;
end;

procedure TStateMachineDemoScene.DoLoad;
begin
   FSMSys := TStateMachineSystem2D(World.AddSystem(TStateMachineSystem2D.Create(World)));
end;

procedure TStateMachineDemoScene.DoEnter;
var
   Tr: TTransformComponent;
   SM: TStateMachineComponent2D;
begin
   FAutoMode := False;
   FAutoTimer := 0;
   FAutoStep := 0;
   FStateTimer := 0;
   FEnterLogN := 0;
   FEntityColor := STATE_COLS[ST_IDLE];
   FEntityScale := 1;
   FCurrentStateName := 'IDLE';
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FSID := ComponentRegistry.GetComponentID(TStateMachineComponent2D);
   FEntity := World.CreateEntity('FSMEntity');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(DEMO_AREA_CX, DEMO_AREA_CY - 40);
   FEntity.AddComponent(Tr);
   SM := TStateMachineComponent2D.Create;
   SM.OwnerID := FEntity.ID;
   SM.SetInitialState(ST_IDLE);
   SM.OnEnter := @OnEnter;
   SM.OnExit := @OnExit;
   SM.OnUpdate := @OnUpdate;
   FEntity.AddComponent(SM);
   World.Init;
   LogEntry('FSM initialized in IDLE.');
end;

procedure TStateMachineDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TStateMachineDemoScene.Update(ADelta: Single);
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_ONE) then
      FSM.RequestTransition(ST_IDLE);
   if IsKeyPressed(KEY_TWO) then
      FSM.RequestTransition(ST_WALK);
   if IsKeyPressed(KEY_THREE) then
      FSM.RequestTransition(ST_RUN);
   if IsKeyPressed(KEY_FOUR) then
      FSM.RequestTransition(ST_ATTACK);
   if IsKeyPressed(KEY_FIVE) then
      FSM.RequestTransition(ST_HURT);
   if IsKeyPressed(KEY_A) then
   begin
      FAutoMode := not FAutoMode;
      FAutoTimer := 0;
      LogEntry(IfThen(FAutoMode, 'AUTO mode ON', 'AUTO mode OFF'));
   end;
   if FAutoMode then
   begin
      FAutoTimer := FAutoTimer + ADelta;
      if FAutoTimer >= 2 then
      begin
         FAutoTimer := 0;
         FAutoStep := (FAutoStep + 1) mod 5;
         FSM.RequestTransition(FAutoStep);
      end;
   end;
   World.Update(ADelta);
end;

procedure TStateMachineDemoScene.Render;
const
   SZ = 60;
var
   Tr: TTransformComponent;
   I, SX: Integer;
   Col: TColor;
   Sc: Single;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 18 - Finite State Machine (TStateMachineComponent2D)');
   DrawFooter('1-5=transition   A=auto-cycle through states');
   Tr := TTransformComponent(FEntity.GetComponentByID(FTRID));
   Sc := FEntityScale;
   Col := FEntityColor;
   if (FSM.CurrentState = ST_HURT) and (Round(FStateTimer * 10) mod 2 = 0) then
      Col := WHITE;
   DrawCircle(Round(Tr.Position.X), Round(Tr.Position.Y), Round(SZ * Sc), Col);
   DrawCircleLines(Round(Tr.Position.X), Round(Tr.Position.Y), Round(SZ * Sc) + 2, COL_DIMTEXT);
   DrawText(PChar(FCurrentStateName), Round(Tr.Position.X) - 24, Round(Tr.Position.Y) - 8,
      13, ColorCreate(20, 20, 30, 255));
   DrawPanel(30, DEMO_AREA_Y + 10, 300, 180, 'State Diagram');
   for I := 0 to 4 do
   begin
      SX := 60 + I * 46;
      if I = (FSM.CurrentState mod 5) then
         DrawRectangle(SX - 16, DEMO_AREA_Y + 50, 32, 20, STATE_COLS[I])
      else
         DrawRectangle(SX - 16, DEMO_AREA_Y + 50, 32, 20, ColorCreate(50, 50, 70, 255));
      DrawText(PChar(IntToStr(I + 1)), SX - 4, DEMO_AREA_Y + 54, 12, WHITE);
      DrawText(PChar(STATE_NAMES[I]), SX - 14, DEMO_AREA_Y + 76, 9, COL_DIMTEXT);
   end;
   DrawPanel(30, DEMO_AREA_Y + 200, 300, 330, 'Callback Log');
   for I := 0 to FEnterLogN - 1 do
      DrawText(PChar(FEnterLog[I]), 42, DEMO_AREA_Y + 224 + I * 34, 12, IfThen(Pos('ENTER', FEnterLog[I]) > 0, COL_GOOD, IfThen(Pos('EXIT', FEnterLog[I]) > 0, COL_WARN, COL_DIMTEXT)));
   DrawPanel(SCR_W - 300, DEMO_AREA_Y + 10, 290, 180, 'FSM State');
   DrawText(PChar('Current: ' + FCurrentStateName), SCR_W - 290, DEMO_AREA_Y + 34, 15, FEntityColor);
   DrawText(PChar(Format('In state: %.2f s', [FStateTimer])), SCR_W - 290, DEMO_AREA_Y + 60, 12, COL_TEXT);
   DrawText(PChar('AUTO: ' + IfThen(FAutoMode, 'ON', 'OFF')), SCR_W - 290, DEMO_AREA_Y + 78, 12, IfThen(FAutoMode, COL_GOOD, COL_DIMTEXT));
   DrawText(PChar('Previous: ' + STATE_NAMES[FSM.PreviousState mod 5]),
      SCR_W - 290, DEMO_AREA_Y + 96, 12, COL_DIMTEXT);
end;

end.
