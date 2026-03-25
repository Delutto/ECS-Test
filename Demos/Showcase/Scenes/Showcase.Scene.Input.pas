unit Showcase.Scene.Input;

{$mode objfpc}{$H+}

{ Demo 22 - Input Action Maps (TInputMapComponent + TInputManager)
  TInputBinding: FromKey / FromMouseButton / FromGamepadButton / FromGamepadAxis.
  TInputAction: named action holding bindings array. Poll result = first active.
  TInputActionMap: groups actions; call Poll() once per frame (auto via TInputManager).
  TInputMapComponent: links entity to a named map; forwards IsDown/IsPressed/AxisValue.
  WASD/Arrows=move  SPACE/Z=jump  LShift=run  LMB=fire }
interface

uses
   SysUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.InputAction, P2D.Core.InputManager,
   P2D.Components.Transform, P2D.Components.InputMap,
   Showcase.Common;

type
   TInputDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FPlayerE: TEntity;
      FTRID, FIMID: Integer;
      FJumpCount, FFireCount: Integer;
      FAxisX, FAxisY: Single;
      function IM: TInputMapComponent;
      function PTr: TTransformComponent;
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
   MAP_NAME = 'InputDemo';

constructor TInputDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('Input');

   FScreenW := AW;
   FScreenH := AH;
end;

function TInputDemoScene.IM: TInputMapComponent;
begin
   Result := TInputMapComponent(FPlayerE.GetComponentByID(FIMID));
end;

function TInputDemoScene.PTr: TTransformComponent;
begin
   Result := TTransformComponent(FPlayerE.GetComponentByID(FTRID));
end;

procedure TInputDemoScene.DoLoad;
begin
end;

procedure TInputDemoScene.DoEnter;
var
   Map: TInputActionMap;
   Action: TInputAction;
   Tr: TTransformComponent;
   IMC: TInputMapComponent;
begin
   FJumpCount := 0;
   FFireCount := 0;

   FAxisX := 0;
   FAxisY := 0;

   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FIMID := ComponentRegistry.GetComponentID(TInputMapComponent);

   Map := InputManager.AddMap(MAP_NAME);

   Action := Map.AddAction('MoveLeft');
   Action.AddBinding(TInputBinding.FromKey(KEY_A));
   Action.AddBinding(TInputBinding.FromKey(KEY_LEFT));
   Action.AddBinding(TInputBinding.FromGamepadAxis(0, GAMEPAD_AXIS_LEFT_X, False, 0.2));

   Action := Map.AddAction('MoveRight');
   Action.AddBinding(TInputBinding.FromKey(KEY_D));
   Action.AddBinding(TInputBinding.FromKey(KEY_RIGHT));
   Action.AddBinding(TInputBinding.FromGamepadAxis(0, GAMEPAD_AXIS_LEFT_X, True, 0.2));

   Action := Map.AddAction('MoveUp');
   Action.AddBinding(TInputBinding.FromKey(KEY_W));
   Action.AddBinding(TInputBinding.FromKey(KEY_UP));

   Action := Map.AddAction('MoveDown');
   Action.AddBinding(TInputBinding.FromKey(KEY_S));
   Action.AddBinding(TInputBinding.FromKey(KEY_DOWN));

   Action := Map.AddAction('Jump');
   Action.AddBinding(TInputBinding.FromKey(KEY_SPACE));
   Action.AddBinding(TInputBinding.FromKey(KEY_Z));
   Action.AddBinding(TInputBinding.FromGamepadButton(0, GAMEPAD_BUTTON_RIGHT_FACE_DOWN));

   Action := Map.AddAction('Run');
   Action.AddBinding(TInputBinding.FromKey(KEY_LEFT_SHIFT));
   Action.AddBinding(TInputBinding.FromGamepadButton(0, GAMEPAD_BUTTON_RIGHT_FACE_LEFT));

   Action := Map.AddAction('Fire');
   Action.AddBinding(TInputBinding.FromMouseButton(MOUSE_BUTTON_LEFT));

   FPlayerE := World.CreateEntity('Player');

   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(DEMO_AREA_CX, DEMO_AREA_CY);
   FPlayerE.AddComponent(Tr);

   IMC := TInputMapComponent.Create;
   IMC.MapName := MAP_NAME;
   FPlayerE.AddComponent(IMC);

   World.Init;
end;

procedure TInputDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   InputManager.RemoveMap(MAP_NAME);
end;

procedure TInputDemoScene.Update(ADelta: Single);
var
   M: TInputMapComponent;
   Tr: TTransformComponent;
   Spd: Single;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   M := IM;
   Tr := PTr;
   Spd := 180 * ADelta;
   if IsKeyDown(KEY_LEFT_SHIFT) then
      Spd := Spd * 2;
   if M.IsDown('MoveLeft') then
      Tr.Position.X := Tr.Position.X - Spd;
   if M.IsDown('MoveRight') then
      Tr.Position.X := Tr.Position.X + Spd;
   if M.IsDown('MoveUp') then
      Tr.Position.Y := Tr.Position.Y - Spd;
   if M.IsDown('MoveDown') then
      Tr.Position.Y := Tr.Position.Y + Spd;
   FAxisX := M.AxisValue('MoveRight') - M.AxisValue('MoveLeft');
   FAxisY := M.AxisValue('MoveDown') - M.AxisValue('MoveUp');
   if M.IsPressed('Jump') then
      Inc(FJumpCount);
   if M.IsPressed('Fire') then
      Inc(FFireCount);
   World.Update(ADelta);
end;

procedure TInputDemoScene.Render;
const
   ACTIONS: array[0..6] of String = ('MoveLeft', 'MoveRight', 'MoveUp', 'MoveDown', 'Jump', 'Run', 'Fire');
   BINDINGS: array[0..6] of String = ('A/Left/GP-AxisL-', 'D/Right/GP-AxisL+',
      'W/Up', 'S/Down', 'SPACE/Z/GP-A', 'LShift/GP-X', 'LMB');
var
   M: TInputMapComponent;
   Tr: TTransformComponent;
   I: Integer;
   IsD: boolean;
   Col: TColor;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 22 - Input Action Maps (TInputMapComponent + TInputManager)');
   DrawFooter('WASD/Arrows=move  SPACE/Z=jump  LShift=run  LMB=fire');
   M := IM;
   Tr := PTr;
   DrawRectangle(Round(Tr.Position.X) - 18, Round(Tr.Position.Y) - 18, 36, 36, IfThen(M.IsDown('Run'), COL_WARN, COL_ACCENT));
   DrawText('PLAYER', Round(Tr.Position.X) - 22, Round(Tr.Position.Y) + 20, 10, COL_TEXT);
   DrawCircle(Round(DEMO_AREA_CX * 0.3), Round(DEMO_AREA_CY), 40, ColorCreate(30, 30, 50, 255));
   DrawCircleLines(Round(DEMO_AREA_CX * 0.3), Round(DEMO_AREA_CY), 40, COL_DIMTEXT);
   DrawCircle(Round(DEMO_AREA_CX * 0.3 + FAxisX * 35), Round(DEMO_AREA_CY + FAxisY * 35), 8, COL_ACCENT);
   DrawText('Axis', Round(DEMO_AREA_CX * 0.3) - 14, Round(DEMO_AREA_CY) + 46, 11, COL_DIMTEXT);
   DrawPanel(SCR_W - 410, DEMO_AREA_Y + 10, 400, 260, 'Action State Table');
   for I := 0 to 6 do
   begin
      IsD := M.IsDown(ACTIONS[I]);
      Col := IfThen(IsD, COL_GOOD, COL_DIMTEXT);
      DrawRectangle(SCR_W - 398, DEMO_AREA_Y + 36 + I * 32, 12, 12, IfThen(IsD, COL_GOOD, ColorCreate(50, 50, 60, 255)));
      DrawText(PChar(ACTIONS[I]), SCR_W - 378, DEMO_AREA_Y + 36 + I * 32, 12, Col);
      DrawText(PChar(BINDINGS[I]), SCR_W - 260, DEMO_AREA_Y + 36 + I * 32, 10, COL_DIMTEXT);
   end;
   DrawPanel(SCR_W - 410, DEMO_AREA_Y + 280, 400, 90, 'Event Counters (IsPressed)');
   DrawText(PChar(Format('Jump pressed: %d', [FJumpCount])), SCR_W - 398, DEMO_AREA_Y + 304, 13, COL_TEXT);
   DrawText(PChar(Format('Fire pressed: %d', [FFireCount])), SCR_W - 398, DEMO_AREA_Y + 326, 13, COL_TEXT);
end;

end.
