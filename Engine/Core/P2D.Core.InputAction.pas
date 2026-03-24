unit P2D.Core.InputAction;

{$mode ObjFPC}
{$H+}
{$modeswitch ADVANCEDRECORDS}

interface

uses
   Classes,
   SysUtils,
   fgl,
   raylib;

{ ============================================================================
  Tipos primitivos de input
  ============================================================================ }

type
  { Categoria do binding: teclado, mouse ou gamepad }
   TInputDeviceKind = (idkKeyboard, idkMouseButton, idkGamepadButton, idkGamepadAxis);

  { Um binding associa um dispositivo + código a um valor }
   TInputBinding = record
      DeviceKind: TInputDeviceKind;
      KeyCode: Integer;   // KEY_* para teclado / MOUSE_BUTTON_* para mouse
      GamepadIndex: Integer;   // índice do gamepad (0 = primeiro)
      AxisIndex: Integer;   // eixo do gamepad
      AxisDeadZone: Single;    // zona morta do eixo (0..1)
      AxisPositive: Boolean;   // True = eixo positivo; False = negativo
      class function FromKey(AKey: Integer): TInputBinding; static;
      class function FromMouseButton(AButton: Integer): TInputBinding; static;
      class function FromGamepadButton(AGamepad, AButton: Integer): TInputBinding; static;
      class function FromGamepadAxis(AGamepad, AAxis: Integer; APositive: Boolean; ADeadZone: Single = 0.2): TInputBinding; static;
   end;

  { Array dinâmico de bindings (uma action pode ter múltiplos) }
   TInputBindingArray = array of TInputBinding;

{ ============================================================================
  TInputAction – uma ação nomeada com um ou mais bindings
  ============================================================================ }

   TInputActionState = record
      IsDown: Boolean;  // tecla mantida pressionada
      IsPressed: Boolean;  // borda de descida (só no frame do pressionamento)
      IsReleased: Boolean;  // borda de subida (só no frame da soltura)
      AxisValue: Single;   // valor analógico [-1..1], 0 para digital
   end;

   TInputAction = class
   private
      FName: String;
      FBindings: TInputBindingArray;
      FState: TInputActionState;
      FPrevDown: Boolean;
   public
      constructor Create(const AName: String);
      procedure AddBinding(const ABinding: TInputBinding);
      procedure ClearBindings;
    { Lê o hardware e atualiza FState. Chamado uma vez por frame. }
      procedure Poll;
      property Name: String read FName;
      property State: TInputActionState read FState;
      property Bindings: TInputBindingArray read FBindings;
   end;

{ ============================================================================
  TInputActionMap – coleção nomeada de actions (ex.: "Player1", "UI")
  ============================================================================ }

   TActionList = specialize TFPGObjectList<TInputAction>;

   TInputActionMap = class
   private
      FName: String;
      FActions: TActionList;
      FEnabled: Boolean;
      function FindAction(const AName: String): TInputAction;
   public
      constructor Create(const AName: String);
      destructor Destroy; override;
      function AddAction(const AName: String): TInputAction;
      function GetAction(const AName: String): TInputAction;
      procedure Poll;
    { Consultas de conveniência }
      function IsDown(const AAction: String): Boolean;
      function IsPressed(const AAction: String): Boolean;
      function IsReleased(const AAction: String): Boolean;
      function AxisValue(const AAction: String): Single;
      property Name: String read FName;
      property Enabled: Boolean read FEnabled write FEnabled;
   end;

implementation

{ ─────────────────────────────────────────────────────────────────────────── }
{ TInputBinding                                                               }
{ ─────────────────────────────────────────────────────────────────────────── }

class function TInputBinding.FromKey(AKey: Integer): TInputBinding;
begin
   Result.DeviceKind := idkKeyboard;
   Result.KeyCode := AKey;
   Result.GamepadIndex := 0;
   Result.AxisIndex := 0;
   Result.AxisDeadZone := 0.0;
   Result.AxisPositive := True;
end;

class function TInputBinding.FromMouseButton(AButton: Integer): TInputBinding;
begin
   Result.DeviceKind := idkMouseButton;
   Result.KeyCode := AButton;
   Result.GamepadIndex := 0;
   Result.AxisIndex := 0;
   Result.AxisDeadZone := 0.0;
   Result.AxisPositive := True;
end;

class function TInputBinding.FromGamepadButton(AGamepad, AButton: Integer): TInputBinding;
begin
   Result.DeviceKind := idkGamepadButton;
   Result.KeyCode := AButton;
   Result.GamepadIndex := AGamepad;
   Result.AxisIndex := 0;
   Result.AxisDeadZone := 0.0;
   Result.AxisPositive := True;
end;

class function TInputBinding.FromGamepadAxis(AGamepad, AAxis: Integer; APositive: Boolean; ADeadZone: Single): TInputBinding;
begin
   Result.DeviceKind := idkGamepadAxis;
   Result.KeyCode := 0;
   Result.GamepadIndex := AGamepad;
   Result.AxisIndex := AAxis;
   Result.AxisDeadZone := ADeadZone;
   Result.AxisPositive := APositive;
end;

{ ─────────────────────────────────────────────────────────────────────────── }
{ TInputAction                                                                }
{ ─────────────────────────────────────────────────────────────────────────── }

constructor TInputAction.Create(const AName: String);
begin
   inherited Create;
   FName := AName;
   FPrevDown := False;
   FState := Default(TInputActionState);
end;

procedure TInputAction.AddBinding(const ABinding: TInputBinding);
var
   L: Integer;
begin
   L := Length(FBindings);
   SetLength(FBindings, L + 1);
   FBindings[L] := ABinding;
end;

procedure TInputAction.ClearBindings;
begin
   SetLength(FBindings, 0);
end;

procedure TInputAction.Poll;
var
   B: TInputBinding;
   CurDown: Boolean;
   RawAxis: Single;
   AxisVal: Single;
begin
   CurDown := False;
   AxisVal := 0.0;

   for B In FBindings do
   begin
      case B.DeviceKind of

         idkKeyboard:
         begin
            if IsKeyDown(B.KeyCode) then
            begin
               CurDown := True;
               AxisVal := 1.0;
            end
         end;

         idkMouseButton:
         begin
            if IsMouseButtonDown(B.KeyCode) then
            begin
               CurDown := True;
               AxisVal := 1.0;
            end
         end;

         idkGamepadButton:
         begin
            if IsGamepadButtonDown(B.GamepadIndex, B.KeyCode) then
            begin
               CurDown := True;
               AxisVal := 1.0;
            end
         end;

         idkGamepadAxis:
         begin
            RawAxis := GetGamepadAxisMovement(B.GamepadIndex, B.AxisIndex);
            if B.AxisPositive then
            begin
               if RawAxis > B.AxisDeadZone then
               begin
                  CurDown := True;
                  AxisVal := RawAxis;
               end;
            end
            else
            begin
               if RawAxis < -B.AxisDeadZone then
               begin
                  CurDown := True;
                  AxisVal := -RawAxis; // retorna sempre positivo
               end;
            end;
         end;
      end; // case

      if CurDown then
      begin
         Break
      end; // primeiro binding ativo vence
   end;

   FState.IsDown := CurDown;
   FState.IsPressed := CurDown And Not FPrevDown;
   FState.IsReleased := (Not CurDown) And FPrevDown;
   FState.AxisValue := AxisVal;
   FPrevDown := CurDown;
end;

{ ─────────────────────────────────────────────────────────────────────────── }
{ TInputActionMap                                                             }
{ ─────────────────────────────────────────────────────────────────────────── }

constructor TInputActionMap.Create(const AName: String);
begin
   inherited Create;
   FName := AName;
   FEnabled := True;
   FActions := TActionList.Create(True); // lista dona dos objetos
end;

destructor TInputActionMap.Destroy;
begin
   FActions.Free;
   inherited;
end;

function TInputActionMap.FindAction(const AName: String): TInputAction;
var
   A: TInputAction;
begin
   Result := nil;
   for A In FActions do
   begin
      if A.Name = AName then
      begin
         Result := A;
         Exit;
      end
   end;
end;

function TInputActionMap.AddAction(const AName: String): TInputAction;
begin
   Result := FindAction(AName);
   if Assigned(Result) then
   begin
      Exit
   end; // idempotente
   Result := TInputAction.Create(AName);
   FActions.Add(Result);
end;

function TInputActionMap.GetAction(const AName: String): TInputAction;
begin
   Result := FindAction(AName);
end;

procedure TInputActionMap.Poll;
var
   A: TInputAction;
begin
   if Not FEnabled then
   begin
      Exit
   end;
   for A In FActions do
   begin
      A.Poll
   end;
end;

function TInputActionMap.IsDown(const AAction: String): Boolean;
var
   A: TInputAction;
begin
   A := FindAction(AAction);
   Result := Assigned(A) And A.State.IsDown;
end;

function TInputActionMap.IsPressed(const AAction: String): Boolean;
var
   A: TInputAction;
begin
   A := FindAction(AAction);
   Result := Assigned(A) And A.State.IsPressed;
end;

function TInputActionMap.IsReleased(const AAction: String): Boolean;
var
   A: TInputAction;
begin
   A := FindAction(AAction);
   Result := Assigned(A) And A.State.IsReleased;
end;

function TInputActionMap.AxisValue(const AAction: String): Single;
var
   A: TInputAction;
begin
   A := FindAction(AAction);
   if Assigned(A) then
   begin
      Result := A.State.AxisValue
   end
   else
   begin
      Result := 0.0
   end;
end;

end.
