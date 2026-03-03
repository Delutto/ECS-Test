unit Mario.Systems.Input;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, raylib,
  P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Tags;

type
  { TPlayerInputSystem }
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
end;

{ Responsabilidade única: ler estado do hardware e registrar intenções.
  Nenhuma modificação de Velocity, Position ou State acontece aqui. }
procedure TPlayerInputSystem.Update(ADelta: Single);
var
   E : TEntity;
   PC: TPlayerComponent;
begin
   for E in GetMatchingEntities do
   begin
      if not E.Alive then
         Continue;

      PC := TPlayerComponent(E.GetComponent(TPlayerComponent));
      if PC.State = psDead then
         Continue;

      { Timer de invulnerabilidade: é apenas uma contagem regressiva de tempo, não depende de física — pode ficar em Update sem problemas. }
      if PC.InvFrames > 0 then
         PC.InvFrames := PC.InvFrames - ADelta;

      { Intenções de movimento — refletem o estado ATUAL das teclas. }
      PC.WantsRun       := IsKeyDown(KEY_LEFT_SHIFT) or IsKeyDown(KEY_Z);
      PC.WantsMoveLeft  := IsKeyDown(KEY_LEFT)  or IsKeyDown(KEY_A);
      PC.WantsMoveRight := IsKeyDown(KEY_RIGHT) or IsKeyDown(KEY_D);

      { Pulo: IsKeyPressed é true apenas no frame exato do pressionamento.
        A flag WantsJump persiste até FixedUpdate consumi-la — se FixedUpdate não rodar neste frame, a intenção não é perdida. }
      if IsKeyPressed(KEY_SPACE) or IsKeyPressed(KEY_UP) or IsKeyPressed(KEY_W) then
         PC.WantsJump := True;

      { Corte de pulo: soltar o botão antes do ápice reduz a altura do salto.
        A flag WantsJumpCut persiste até FixedUpdate consumi-la. }
      if IsKeyReleased(KEY_SPACE) or IsKeyReleased(KEY_UP) or IsKeyReleased(KEY_W) then
         PC.WantsJumpCut := True;
   end;
end;

end.

