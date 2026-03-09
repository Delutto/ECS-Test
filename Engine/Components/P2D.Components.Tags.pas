unit P2D.Components.Tags;

{$mode objfpc}{$H+}

interface

uses
   P2D.Core.Component;

type
   // Tag components – zero data, used only for entity classification
   TPlayerTag    = class(TComponent2D) end;
   TEnemyTag     = class(TComponent2D) end;
   TGroundTag    = class(TComponent2D) end;
   TCoinTag      = class(TComponent2D) end;
   TPowerUpTag   = class(TComponent2D) end;
   TGoalTag      = class(TComponent2D) end;

   // Player state
   TPlayerState = (psIdle, psWalking, psRunning, psJumping, psRunJumping, psFalling, psCrouching, psDead, psWin);

   TPlayerComponent = class(TComponent2D)
   public
      State        : TPlayerState;
      Lives        : Integer;
      Score        : Integer;
      Coins        : Integer;
      JumpForce    : Single;
      RunSpeed     : Single;
      WalkSpeed    : Single;
      IsBig        : Boolean;
      HasFireFlower: Boolean;
      InvFrames    : Single;

      { ── Flags de intenção ──────────────────────────────────────────────────
      Escritas pelo TPlayerInputSystem (Update) com base no input bruto.
      Lidas e consumidas pelo TPlayerPhysicsSystem (FixedUpdate). Nunca modifique Velocity diretamente no Input — use estas flags. }
      WantsMoveLeft : Boolean;
      WantsMoveRight: Boolean;
      WantsRun      : Boolean;
      WantsJump     : Boolean; // true no frame em que o botão foi pressionado
      WantsJumpCut  : Boolean; // true no frame em que o botão foi solto cedo

      constructor Create; override;
   end;

implementation

constructor TPlayerComponent.Create;
begin
   inherited Create;

   State          := psIdle;
   Lives          := 3;
   Score          := 0;
   Coins          := 0;
   JumpForce      := -520.0;
   RunSpeed       := 150.0;
   WalkSpeed      := 80.0;
   IsBig          := False;
   HasFireFlower  := False;
   InvFrames      := 0;
   WantsMoveLeft  := False;
   WantsMoveRight := False;
   WantsRun       := False;
   WantsJump      := False;
   WantsJumpCut   := False;
end;

end.
