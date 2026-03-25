unit Mario.Components.Player;

{$mode objfpc}{$H+}

interface

uses
   P2D.Core.Component;

type
   { Tag components }
   TEnemyTag = class(TComponent2D)
   end;

   TGroundTag = class(TComponent2D)
   end;

   TCoinTag = class(TComponent2D)
   end;

   TPowerUpTag = class(TComponent2D)
   end;

   TGoalTag = class(TComponent2D)
   end;

   { ── Player state machine ───────────────────────────────────────────────── }
   { IMPORTANT: new states MUST be appended at the end.
     Existing Ord() values drive the FSM integer IDs; inserting anywhere else shifts every subsequent value and breaks running transitions. }
   TPlayerState = (
      { Surface states (original) }
      psIdle, psWalking, psRunning, psSkid, psCrouching,
      psJumping, psRunJumping, psSpinJump, psFalling,
      psPipe, psDead, psVictory,
      { Underwater states (appended) }
      psSwimIdle,   { floating still in water    }
      psSwimming);  { actively moving in water   }

   TPlayerComponent = class(TComponent2D)
   public
      State: TPlayerState;
      Lives: Integer;
      Score: Integer;
      Coins: Integer;
      JumpForce: Single;
      RunSpeed: Single;
      WalkSpeed: Single;
      IsBig: boolean;
      HasFireFlower: boolean;
      InvFrames: Single;

      { ── Intent flags (written by Input system, read by Physics system) ── }
      WantsMoveLeft: boolean;
      WantsMoveRight: boolean;
      WantsRun: boolean;
      WantsJump: boolean;
      WantsJumpCut: boolean;
      WantsDuck: boolean;
      WantsSpin: boolean;

      constructor Create; override;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TPlayerComponent.Create;
begin
   inherited Create;

   State := psIdle;
   Lives := 3;
   Score := 0;
   Coins := 0;
   JumpForce := -420.0;
   RunSpeed := 150.0;
   WalkSpeed := 80.0;
   IsBig := False;
   HasFireFlower := False;
   InvFrames := 0;
   WantsMoveLeft := False;
   WantsMoveRight := False;
   WantsRun := False;
   WantsJump := False;
   WantsJumpCut := False;
   WantsDuck := False;
   WantsSpin := False;
end;

initialization
   ComponentRegistry.Register(TPlayerComponent);
   ComponentRegistry.Register(TEnemyTag);
   ComponentRegistry.Register(TGroundTag);
   ComponentRegistry.Register(TCoinTag);
   ComponentRegistry.Register(TPowerUpTag);
   ComponentRegistry.Register(TGoalTag);

end.
