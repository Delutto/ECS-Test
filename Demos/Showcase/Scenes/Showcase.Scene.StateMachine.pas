unit Showcase.Scene.StateMachine;

{$mode objfpc}{$H+}

{ Demo 18 - StateMachine  NEW: per-state character texture (48x48). }
interface

uses
   SysUtils, StrUtils, Math, raylib, P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.StateMachine, P2D.Systems.StateMachine, Showcase.Common;

const
   ST_IDLE = 0;
   ST_WALK = 1;
   ST_RUN = 2;
   ST_ATTACK = 3;
   ST_HURT = 4;

type
   TStateMachineDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FEntity: TEntity;
      FSMSys: TStateMachineSystem2D;
      FTRID, FSID: integer;
      FCurrentStateName: string;
      FAutoMode: boolean;
      FAutoTimer, FStateTimer: single;
      FAutoStep: integer;
      FEnterLog: array[0..7] of string;
      FEnterLogN: integer;
      FEntityColor: TColor;
      FEntityScale: single;
      FCharTex: array[0..4] of TTexture2D;
      procedure GenCharTextures;
      procedure FreeCharTextures;
      procedure OnEnter(AEntityID: cardinal; AStateID: TStateID);
      procedure OnExit(AEntityID: cardinal; AStateID: TStateID);
      procedure OnUpdate(AEntityID: cardinal; AStateID: TStateID; ADelta: single);
      procedure LogEntry(const S: string);
      function FSM: TStateMachineComponent2D;
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
   STATE_NAMES: array[0..4] of string = ('IDLE', 'WALK', 'RUN', 'ATTACK', 'HURT');
   STATE_COLS: array[0..4] of TColor = (
      (R: 80; G: 160; B: 255; A: 255), (R: 80; G: 220; B: 100; A: 255), (R: 255; G: 160; B: 60; A: 255),
      (R: 220; G: 60; B: 220; A: 255), (R: 255; G: 60; B: 60; A: 255));

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

constructor TStateMachineDemoScene.Create(AW, AH: integer);
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

procedure TStateMachineDemoScene.GenCharTextures;

   procedure MkC(Idx: integer; BR, BG, BB, AR, AG, AB: byte; LO, BO: integer; Wpn: boolean);
   var
      Img: TImage;
   begin
      Img := GenImageColor(48, 48, ColorCreate(20, 20, 32, 0));
      ImageDrawRectangle(@Img, 16, 4 + BO, 16, 12, ColorCreate(220, 190, 160, 255));
      ImageDrawRectangle(@Img, 12, 16 + BO, 24, 14, ColorCreate(BR, BG, BB, 255));
      ImageDrawRectangle(@Img, 14, 18 + BO, 4, 10, ColorCreate(Min(255, Integer(BR) + 60), Min(255, Integer(BG) + 60), Min(255, Integer(BB) + 60), 160));
      ImageDrawRectangle(@Img, 12, 30 + BO, 9, Max(3, 10 + LO), ColorCreate(AR, AG, AB, 255));
      ImageDrawRectangle(@Img, 27, 30 + BO, 9, Max(3, 10 - LO), ColorCreate(AR, AG, AB, 255));
      ImageDrawRectangle(@Img, 2, 2, 6, 6, ColorCreate(AR, AG, AB, 200));
      if Wpn then
      begin
         ImageDrawRectangle(@Img, 34, 4, 4, 22, ColorCreate(200, 210, 220, 255));
         ImageDrawRectangle(@Img, 28, 10, 12, 4, ColorCreate(200, 160, 40, 255));
      end;
      FCharTex[Idx] := LoadTextureFromImage(Img);
      UnloadImage(Img);
   end;

begin
   MkC(ST_IDLE, 70, 110, 180, 80, 160, 255, 0, 0, False);
   MkC(ST_WALK, 60, 150, 80, 80, 220, 100, 4, 0, False);
   MkC(ST_RUN, 200, 120, 40, 255, 180, 60, 6, -2, False);
   MkC(ST_ATTACK, 150, 60, 200, 220, 60, 220, 0, 0, True);
   MkC(ST_HURT, 190, 60, 60, 220, 60, 60, -2, 2, False);
end;

procedure TStateMachineDemoScene.FreeCharTextures;

   procedure U(var T: TTexture2D);
   begin
      if T.Id > 0 then
      begin
         UnloadTexture(T);
         T.Id := 0;
      end;
   end;

var
   I: integer;
begin
   for I := 0 to 4 do
      U(FCharTex[I]);
end;

procedure TStateMachineDemoScene.LogEntry(const S: string);
var
   I: integer;
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

procedure TStateMachineDemoScene.OnUpdate(AEntityID: cardinal; AStateID: TStateID; ADelta: single);
var
   Tr: TTransformComponent;
begin
   FStateTimer := FStateTimer + ADelta;
   Tr := TTransformComponent(FEntity.GetComponentByID(FTRID));
   case AStateID of
      ST_IDLE:
      begin
         Tr.Position.Y := DEMO_AREA_CY - 40 + Sin(FStateTimer * 2) * 10;
         FEntityScale := 1 + Sin(FStateTimer * 2) * 0.04;
      end;
      ST_WALK:
         Tr.Position.X := DEMO_AREA_CX + Sin(FStateTimer * 1.5) * 120;
      ST_RUN:
      begin
         Tr.Position.X := DEMO_AREA_CX + Sin(FStateTimer * 3) * 180;
         Tr.Position.Y := DEMO_AREA_CY - 40 + Abs(Sin(FStateTimer * 6)) * (-28);
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
   GenCharTextures;
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
   FreeCharTextures;
end;

procedure TStateMachineDemoScene.Update(ADelta: single);
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
      LogEntry(IfStr(FAutoMode, 'AUTO mode ON', 'AUTO mode OFF'));
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
   SZ = 56;
var
   Tr: TTransformComponent;
   I, SX, CState: integer;
   Col: TColor;
   Sc: single;
   Dst: TRectangle;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 18 - Finite State Machine (TStateMachineComponent2D)');
   DrawFooter('1-5=transition   A=auto-cycle through states');
   Tr := TTransformComponent(FEntity.GetComponentByID(FTRID));
   Sc := FEntityScale;
   Col := FEntityColor;
   CState := FSM.CurrentState mod 5;
   if (CState = ST_HURT) and (Round(FStateTimer * 10) mod 2 = 0) then
      Col := WHITE;
   if FCharTex[CState].Id > 0 then
   begin
      Dst := RectangleCreate(Round(Tr.Position.X) - Round(SZ * Sc * 0.5), Round(Tr.Position.Y) - Round(SZ * Sc * 0.5), Round(SZ * Sc), Round(SZ * Sc));
      DrawTexturePro(FCharTex[CState], RectangleCreate(0, 0, 48, 48), Dst, Vector2Create(0, 0), 0, Col);
   end
   else
   begin
      DrawCircle(Round(Tr.Position.X), Round(Tr.Position.Y), Round(SZ * Sc), Col);
      DrawCircleLines(Round(Tr.Position.X), Round(Tr.Position.Y), Round(SZ * Sc) + 2, COL_DIMTEXT);
   end;
   DrawText(PChar(FCurrentStateName), Round(Tr.Position.X) - 24, Round(Tr.Position.Y) + Round(SZ * Sc) + 6, 13, FEntityColor);
   DrawPanel(30, DEMO_AREA_Y + 10, 340, 220, 'State Diagram');
   for I := 0 to 4 do
   begin
      SX := 60 + I * 52;
      DrawRectangle(SX - 22, DEMO_AREA_Y + 46, 44, 44, IfCol(I = CState, STATE_COLS[I], ColorCreate(48, 48, 68, 255)));
      if FCharTex[I].Id > 0 then
         DrawTexturePro(FCharTex[I], RectangleCreate(0, 0, 48, 48),
            RectangleCreate(SX - 20, DEMO_AREA_Y + 48, 40, 40), Vector2Create(0, 0), 0, WHITE)
      else
      begin
         DrawRectangle(SX - 20, DEMO_AREA_Y + 48, 40, 40, STATE_COLS[I]);
         DrawText(PChar(IntToStr(I + 1)), SX - 4, DEMO_AREA_Y + 58, 12, WHITE);
      end;
      DrawText(PChar(STATE_NAMES[I]), SX - 16, DEMO_AREA_Y + 94, 9, COL_DIMTEXT);
   end;
   DrawPanel(30, DEMO_AREA_Y + 240, 340, 330, 'Callback Log');
   for I := 0 to FEnterLogN - 1 do
      DrawText(PChar(FEnterLog[I]), 42, DEMO_AREA_Y + 264 + I * 34, 12,
         IfCol(Pos('ENTER', FEnterLog[I]) > 0, COL_GOOD, IfCol(Pos('EXIT', FEnterLog[I]) > 0, COL_WARN, COL_DIMTEXT)));
   DrawPanel(SCR_W - 304, DEMO_AREA_Y + 10, 294, 200, 'FSM State');
   DrawText(PChar('Current: ' + FCurrentStateName), SCR_W - 294, DEMO_AREA_Y + 34, 15, FEntityColor);
   DrawText(PChar(Format('In state: %.2f s', [FStateTimer])), SCR_W - 294, DEMO_AREA_Y + 60, 12, COL_TEXT);
   DrawText(PChar('AUTO: ' + IfStr(FAutoMode, 'ON', 'OFF')), SCR_W - 294, DEMO_AREA_Y + 78, 12, IfCol(FAutoMode, COL_GOOD, COL_DIMTEXT));
   DrawText(PChar('Previous: ' + STATE_NAMES[FSM.PreviousState mod 5]), SCR_W - 294, DEMO_AREA_Y + 96, 12, COL_DIMTEXT);
end;

end.
