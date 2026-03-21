unit P2D.Components.StateMachine;

{$mode objfpc}{$H+}

{ ─────────────────────────────────────────────────────────────────────────────
  TStateMachineComponent2D — generic Finite State Machine component.

  This component provides a generic, engine-level FSM built on Integer state
  IDs. Game code maps its domain enum to Integer via Ord() casts. The FSM
  fires Enter/Exit/Update callbacks, enabling self-contained behaviours.

  DESIGN
  ──────
  • States are Integer IDs — no heap allocation per state type.
  • OnEnter / OnExit / OnUpdate are method-pointer callbacks set by the owner
    system or entity factory.  This keeps the component as pure data while
    delegating behaviour to systems (ECS-correct).
  • TStateMachineSystem2D drives OnUpdate every frame with ADelta.
  • Transitions are explicit: call RequestTransition(NewState) from any
    system. The transition is applied immediately (within the same frame)
    and the Enter/Exit callbacks fire in order: Exit(old) → Enter(new).
  ───────────────────────────────────────────────────────────────────────────── }

interface

uses
   SysUtils, P2D.Core.Component;

type
   TStateID = Integer;

   TStateCallback       = procedure(AEntityID: Cardinal; AStateID: TStateID) of object;
   TStateUpdateCallback = procedure(AEntityID: Cardinal; AStateID: TStateID; ADelta: Single) of object;

   TStateMachineComponent2D = class(TComponent2D)
   private
      FCurrentState : TStateID;
      FPreviousState: TStateID;
      FPendingState : TStateID;
      FHasPending   : Boolean;
      FOwnerID      : Cardinal;
   public
      OnEnter : TStateCallback;
      OnExit  : TStateCallback;
      OnUpdate: TStateUpdateCallback;

      constructor Create; override;

      { Sets the starting state directly, without firing OnExit or OnEnter.
        Call this once in the entity factory (CreatePlayer, CreateGoomba, etc.)
        before World.Init runs. Never call during gameplay — use
        RequestTransition for all runtime state changes. }
      procedure SetInitialState(AState: TStateID);

      { Schedules a transition to ANewState. The FSM will exit the current
        state and enter ANewState on the next TStateMachineSystem2D.Update call. }
      procedure RequestTransition(ANewState: TStateID);

      { Called by TStateMachineSystem2D every frame — do NOT call from game code. }
      procedure Tick(ADelta: Single);

      property CurrentState : TStateID read FCurrentState;
      property PreviousState: TStateID read FPreviousState;
      property OwnerID      : Cardinal read FOwnerID write FOwnerID;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TStateMachineComponent2D.Create;
begin
   inherited Create;

   FCurrentState  := -1;
   FPreviousState := -1;
   FPendingState  := -1;
   FHasPending    := False;
   FOwnerID       := 0;
   OnEnter        := nil;
   OnExit         := nil;
   OnUpdate       := nil;
end;

procedure TStateMachineComponent2D.SetInitialState(AState: TStateID);
begin
   FCurrentState  := AState;
   FPreviousState := -1;
   FPendingState  := -1;
   FHasPending    := False;
end;

procedure TStateMachineComponent2D.RequestTransition(ANewState: TStateID);
begin
   if ANewState = FCurrentState then
      Exit;
   FPendingState := ANewState;
   FHasPending   := True;
end;

procedure TStateMachineComponent2D.Tick(ADelta: Single);
begin
   if FHasPending then
   begin
      if (FCurrentState >= 0) and Assigned(OnExit) then
         OnExit(FOwnerID, FCurrentState);
      FPreviousState := FCurrentState;
      FCurrentState  := FPendingState;
      FHasPending    := False;
      FPendingState  := -1;
      if Assigned(OnEnter) then
         OnEnter(FOwnerID, FCurrentState);
   end;
   if (FCurrentState >= 0) and Assigned(OnUpdate) then
      OnUpdate(FOwnerID, FCurrentState, ADelta);
end;

initialization
   ComponentRegistry.Register(TStateMachineComponent2D);

end.

