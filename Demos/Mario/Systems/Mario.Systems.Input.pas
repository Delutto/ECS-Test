unit Mario.Systems.Input;

{$mode ObjFPC}{$H+}

{ ============================================================================
  TPlayerInputSystem
    Toda leitura de hardware passa pelo InputManager via TInputMapComponent.
  ============================================================================ }

interface

uses
  SysUtils,
  P2D.Core.Entity,
  P2D.Core.System,
  P2D.Core.World,
  P2D.Components.Tags,
  P2D.Components.InputMap,
  P2D.Core.ResourceManager;

type
  TPlayerInputSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorldBase); override;
    procedure Init; override;
    procedure Update(ADelta: Single); override;
  end;

implementation

constructor TPlayerInputSystem.Create(AWorld: TWorldBase);
begin
  inherited Create(AWorld);
  Priority := 1;
  Name     := 'PlayerInputSystem';
end;

procedure TPlayerInputSystem.Init;
begin
  inherited;
  RequireComponent(TPlayerTag);
  RequireComponent(TPlayerComponent);
  RequireComponent(TInputMapComponent);
end;

procedure TPlayerInputSystem.Update(ADelta: Single);
var
  E  : TEntity;
  PC : TPlayerComponent;
  IM : TInputMapComponent;
begin
  for E in GetMatchingEntities do
  begin
    if not E.Alive then Continue;

    PC := TPlayerComponent(E.GetComponent(TPlayerComponent));
    IM := TInputMapComponent(E.GetComponent(TInputMapComponent));

    if PC.State = psDead then Continue;

    { Contador de invulnerabilidade }
    if PC.InvFrames > 0 then
      PC.InvFrames := PC.InvFrames - ADelta;

    { Intenções de movimento }
    PC.WantsRun       := IM.IsDown('Run');
    PC.WantsMoveLeft  := IM.IsDown('MoveLeft');
    PC.WantsMoveRight := IM.IsDown('MoveRight');

    { Pulo: preserva a flag até ser consumida pela física }
    if IM.IsPressed('Jump') then
      PC.WantsJump := True;

    { Corte de pulo (short-hop) }
    if IM.IsReleased('Jump') then
      PC.WantsJumpCut := True;
  end;
end;

end.
