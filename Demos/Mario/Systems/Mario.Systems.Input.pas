unit Mario.Systems.Input;

{$mode ObjFPC}{$H+}

interface

uses
   SysUtils,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Components.Tags,
   P2D.Components.InputMap,
   P2D.Core.ResourceManager,
   Mario.Components.Player;

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
      //if not E.Alive then
      //   Continue;

      PC := TPlayerComponent(E.GetComponent(TPlayerComponent));
      IM := TInputMapComponent(E.GetComponent(TInputMapComponent));

      if PC.State in [psDead, psVictory, psPipe] then
         Continue;

      { Contador de invulnerabilidade }
      if PC.InvFrames > 0 then
         PC.InvFrames := PC.InvFrames - ADelta;

      { Intenções de movimento }
      PC.WantsRun       := IM.IsDown('Run');
      PC.WantsMoveLeft  := IM.IsDown('MoveLeft');
      PC.WantsMoveRight := IM.IsDown('MoveRight');
      PC.WantsDuck      := IM.IsDown('Duck');

      { Pulo: preserva a flag até ser consumida pela física }
      if IM.IsPressed('Jump') and not (PC.State in [psJumping, psRunJumping, psSpinJump, psFalling]) then
         PC.WantsJump := True;

      { Spin Jump }
      if IM.IsPressed('Spin') and not (PC.State in [psJumping, psRunJumping, psSpinJump, psFalling]) then
      begin
         PC.WantsJump := True;
         PC.WantsSpin := True;
      end;

      { Corte de pulo (short-hop) }
      if IM.IsReleased('Jump') or IM.IsReleased('Spin') then
         PC.WantsJumpCut := True;
   end;
end;

end.
