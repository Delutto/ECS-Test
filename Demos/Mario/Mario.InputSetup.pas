unit Mario.InputSetup;

{$mode ObjFPC}{$H+}

{ ============================================================================
  Mario.InputSetup
  Define e registra o mapa de input 'Player1' no InputManager global.
  Separar a configuração dos bindings em uma unit própria facilita:
    - Trocar teclas sem tocar nos sistemas;
    - Adicionar suporte a gamepad sem alterar a lógica de gameplay;
    - Futuramente carregar bindings de um arquivo de configuração.
  ============================================================================ }

interface

uses
   P2D.Core.InputAction,
   P2D.Core.InputManager;

{ Cria o mapa 'Player1' no InputManager e registra todos os bindings padrão. }
procedure SetupPlayerInput;

implementation

uses
   raylib, // KEY_* e MOUSE_BUTTON_*
   Mario.Common;

procedure SetupPlayerInput;
var
   Map     : TInputActionMap;
   Action  : TInputAction;
begin
   Map := InputManager.AddMap(PLAYER_MAP);

   { ── MoveLeft ──────────────────────────────────────────────────────────── }
   Action := Map.AddAction('MoveLeft');
   Action.AddBinding(TInputBinding.FromKey(KEY_LEFT));
   Action.AddBinding(TInputBinding.FromKey(KEY_A));
   // Gamepad: eixo X esquerdo negativo (analógico)
   Action.AddBinding(TInputBinding.FromGamepadAxis(0, GAMEPAD_AXIS_LEFT_X, False));

   { ── MoveRight ─────────────────────────────────────────────────────────── }
   Action := Map.AddAction('MoveRight');
   Action.AddBinding(TInputBinding.FromKey(KEY_RIGHT));
   Action.AddBinding(TInputBinding.FromKey(KEY_D));
   // Gamepad: eixo X esquerdo postivo (analógico)
   Action.AddBinding(TInputBinding.FromGamepadAxis(0, GAMEPAD_AXIS_LEFT_X, True));

   { ── Duck ──────────────────────────────────────────────────────────────── }
   Action := Map.AddAction('Duck');
   Action.AddBinding(TInputBinding.FromKey(KEY_UP));
   Action.AddBinding(TInputBinding.FromKey(KEY_S));
   // Gamepad: eixo Y esquerdo negativo (analógico)
   Action.AddBinding(TInputBinding.FromGamepadAxis(0, GAMEPAD_AXIS_LEFT_Y, False));

   { ── Spin ──────────────────────────────────────────────────────────────── }
   Action := Map.AddAction('Spin');
   Action.AddBinding(TInputBinding.FromKey(KEY_LEFT_CONTROL));
   Action.AddBinding(TInputBinding.FromKey(KEY_C));

   { ── Jump ──────────────────────────────────────────────────────────────── }
   Action := Map.AddAction('Jump');
   Action.AddBinding(TInputBinding.FromKey(KEY_SPACE));
   Action.AddBinding(TInputBinding.FromKey(KEY_UP));
   Action.AddBinding(TInputBinding.FromKey(KEY_X));
   Action.AddBinding(TInputBinding.FromGamepadButton(0, GAMEPAD_BUTTON_RIGHT_FACE_DOWN)); // A (Xbox) / X (PS)

   { ── Run ───────────────────────────────────────────────────────────────── }
   Action := Map.AddAction('Run');
   Action.AddBinding(TInputBinding.FromKey(KEY_LEFT_SHIFT));
   Action.AddBinding(TInputBinding.FromKey(KEY_Z));
   Action.AddBinding(TInputBinding.FromGamepadButton(0, GAMEPAD_BUTTON_RIGHT_FACE_LEFT)); // X (Xbox) / Square (PS)

   { ── Pause (reservado para uso futuro) ────────────────────────────────── }
   Action := Map.AddAction('Pause');
   Action.AddBinding(TInputBinding.FromKey(KEY_ESCAPE));
   Action.AddBinding(TInputBinding.FromKey(KEY_P));
   Action.AddBinding(TInputBinding.FromGamepadButton(0, GAMEPAD_BUTTON_MIDDLE_RIGHT)); // Start

   { ── Shader On/Off ────────────────────────────────────────────────────── }
   Action := Map.AddAction('Shader');
   Action.AddBinding(TInputBinding.FromKey(KEY_G));
end;

end.
