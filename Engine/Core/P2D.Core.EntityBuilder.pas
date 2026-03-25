unit P2D.Core.EntityBuilder;
{$mode objfpc}{$H+}
interface

uses
   SysUtils, raylib,
   P2D.Core.Component, P2D.Core.Entity, P2D.Core.World, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Sprite, P2D.Components.RigidBody,
   P2D.Components.Collider, P2D.Components.Animation,
   P2D.Components.StateMachine, P2D.Components.Text,
   P2D.Components.Lifetime, P2D.Components.Timer, P2D.Components.Tween,
   P2D.Components.Tag, P2D.Components.Health, P2D.Components.Inventory;

type
   TEntityBuilder2D = class
   private
      FWorld: TWorld;
      FEntity: TEntity;
   public
      constructor Create(AW: TWorld);
      class function InWorld(AW: TWorld): TEntityBuilder2D;
      function Named(const N: string): TEntityBuilder2D;
      function Tagged(const T: string): TEntityBuilder2D;
      function WithTransform(AX, AY: single; SX: single = 1; SY: single = 1; Rot: single = 0): TEntityBuilder2D;
      function WithSprite(const Tex: TTexture2D; Z: integer = 0): TEntityBuilder2D;
      function WithSpriteRect(X, Y, W, H: single): TEntityBuilder2D;
      function WithSpriteTint(C: TColor): TEntityBuilder2D;
      function WithSpriteOrigin(OX, OY: single): TEntityBuilder2D;
      function WithRigidBody(GS: single = 1; UseG: boolean = True): TEntityBuilder2D;
      function WithKinematic: TEntityBuilder2D;
      function WithCollider(Tag: TColliderTag; W, H: single; OX: single = 0; OY: single = 0; Trig: boolean = False): TEntityBuilder2D;
      function WithHealth(MHP: single = 100; Def: single = 0; Inv: single = 0.5): TEntityBuilder2D;
      function WithInventory(Slots: integer = 20): TEntityBuilder2D;
      function WithAnimation: TEntityBuilder2D;
      function WithStateMachine(Init: integer = 0): TEntityBuilder2D;
      function WithText(const Txt, FKey: string; const Col: TColor; FSz: single = 16): TEntityBuilder2D;
      function WithLifetime(Dur: single): TEntityBuilder2D;
      function WithTimer: TEntityBuilder2D;
      function WithTween: TEntityBuilder2D;
      function WithTags(const Tags: array of string): TEntityBuilder2D;
      function AddComp(C: TComponent2D): TEntityBuilder2D;
      function Build: TEntity;
   end;

implementation

constructor TEntityBuilder2D.Create(AW: TWorld);
begin
   inherited Create;
   FWorld := AW;
   FEntity := AW.CreateEntity;
end;

class function TEntityBuilder2D.InWorld(AW: TWorld): TEntityBuilder2D;
begin
   Result := TEntityBuilder2D.Create(AW);
end;

function TEntityBuilder2D.Named(const N: string): TEntityBuilder2D;
begin
   FEntity.Name := N;
   Result := Self;
end;

function TEntityBuilder2D.Tagged(const T: string): TEntityBuilder2D;
begin
   FEntity.Tag := T;
   Result := Self;
end;

function TEntityBuilder2D.WithTransform(AX, AY, SX, SY, Rot: single): TEntityBuilder2D;
var
   T: TTransformComponent;
begin
   T := TTransformComponent(FEntity.GetComponent(TTransformComponent));
   if not Assigned(T) then
   begin
      T := TTransformComponent.Create;
      FEntity.AddComponent(T);
   end;
   T.Position.X := AX;
   T.Position.Y := AY;
   T.Scale.X := SX;
   T.Scale.Y := SY;
   T.Rotation := Rot;
   Result := Self;
end;

function TEntityBuilder2D.WithSprite(const Tex: TTexture2D; Z: integer): TEntityBuilder2D;
var
   S: TSpriteComponent;
begin
   S := TSpriteComponent.Create;
   S.Texture := Tex;
   S.OwnsTexture := False;
   S.ZOrder := Z;
   S.SetSourceFull;
   FEntity.AddComponent(S);
   Result := Self;
end;

function TEntityBuilder2D.WithSpriteRect(X, Y, W, H: single): TEntityBuilder2D;
var
   S: TSpriteComponent;
begin
   S := TSpriteComponent(FEntity.GetComponent(TSpriteComponent));
   if Assigned(S) then
   begin
      S.SourceRect.X := X;
      S.SourceRect.Y := Y;
      S.SourceRect.Width := W;
      S.SourceRect.Height := H;
   end;
   Result := Self;
end;

function TEntityBuilder2D.WithSpriteTint(C: TColor): TEntityBuilder2D;
var
   S: TSpriteComponent;
begin
   S := TSpriteComponent(FEntity.GetComponent(TSpriteComponent));
   if Assigned(S) then
      S.Tint := C;
   Result := Self;
end;

function TEntityBuilder2D.WithSpriteOrigin(OX, OY: single): TEntityBuilder2D;
var
   S: TSpriteComponent;
begin
   S := TSpriteComponent(FEntity.GetComponent(TSpriteComponent));
   if Assigned(S) then
   begin
      S.Origin.X := OX;
      S.Origin.Y := OY;
   end;
   Result := Self;
end;

function TEntityBuilder2D.WithRigidBody(GS: single; UseG: boolean): TEntityBuilder2D;
var
   RB: TRigidBodyComponent;
begin
   RB := TRigidBodyComponent.Create;
   RB.GravityScale := GS;
   RB.UseGravity := UseG;
   FEntity.AddComponent(RB);
   Result := Self;
end;

function TEntityBuilder2D.WithKinematic: TEntityBuilder2D;
begin
   Result := WithRigidBody(1.0, False);
end;

function TEntityBuilder2D.WithCollider(Tag: TColliderTag; W, H, OX, OY: single; Trig: boolean): TEntityBuilder2D;
var
   C: TColliderComponent;
begin
   C := TColliderComponent.Create;
   C.Tag := Tag;
   C.Size.X := W;
   C.Size.Y := H;
   C.Offset.X := OX;
   C.Offset.Y := OY;
   C.IsTrigger := Trig;
   FEntity.AddComponent(C);
   Result := Self;
end;

function TEntityBuilder2D.WithHealth(MHP, Def, Inv: single): TEntityBuilder2D;
var
   H: THealthComponent2D;
begin
   H := THealthComponent2D.Create;
   H.MaxHP := MHP;
   H.HP := MHP;
   H.Defense := Def;
   H.InvincibilityTime := Inv;
   H.OwnerEntity := FEntity.ID;
   FEntity.AddComponent(H);
   Result := Self;
end;

function TEntityBuilder2D.WithInventory(Slots: integer): TEntityBuilder2D;
var
   Inv: TInventoryComponent2D;
begin
   Inv := TInventoryComponent2D.Create;
   Inv.Resize(Slots);
   FEntity.AddComponent(Inv);
   Result := Self;
end;

function TEntityBuilder2D.WithAnimation: TEntityBuilder2D;
begin
   FEntity.AddComponent(TAnimationComponent.Create);
   Result := Self;
end;

function TEntityBuilder2D.WithStateMachine(Init: integer): TEntityBuilder2D;
var
   FSM: TStateMachineComponent2D;
begin
   FSM := TStateMachineComponent2D.Create;
   FSM.OwnerID := FEntity.ID;
   FSM.SetInitialState(Init);
   FEntity.AddComponent(FSM);
   Result := Self;
end;

function TEntityBuilder2D.WithText(const Txt, FKey: string; const Col: TColor; FSz: single = 16): TEntityBuilder2D;
var
   TC: TTextComponent2D;
begin
   if (Col.a = 0) and (Col.b = 0) and (Col.g = 0) and (Col.r = 0) then
      TC.Color := WHITE
   else
      TC.Color := Col;
   TC := TTextComponent2D.Create;
   TC.Text := Txt;
   TC.FontKey := FKey;
   TC.FontSize := FSz;
   FEntity.AddComponent(TC);
   Result := Self;
end;

function TEntityBuilder2D.WithLifetime(Dur: single): TEntityBuilder2D;
var
   LT: TLifetimeComponent2D;
begin
   LT := TLifetimeComponent2D.Create;
   LT.Duration := Dur;
   LT.Remaining := Dur;
   FEntity.AddComponent(LT);
   Result := Self;
end;

function TEntityBuilder2D.WithTimer: TEntityBuilder2D;
begin
   FEntity.AddComponent(TTimerComponent2D.Create);
   Result := Self;
end;

function TEntityBuilder2D.WithTween: TEntityBuilder2D;
begin
   FEntity.AddComponent(TTweenComponent2D.Create);
   Result := Self;
end;

function TEntityBuilder2D.WithTags(const Tags: array of string): TEntityBuilder2D;
var
   TC: TTagComponent2D;
   S: string;
begin
   TC := TTagComponent2D(FEntity.GetComponent(TTagComponent2D));
   if not Assigned(TC) then
   begin
      TC := TTagComponent2D.Create;
      FEntity.AddComponent(TC);
   end;
   for S in Tags do
      TC.AddTag(S);
   Result := Self;
end;

function TEntityBuilder2D.AddComp(C: TComponent2D): TEntityBuilder2D;
begin
   C.OwnerEntity := FEntity.ID;
   FEntity.AddComponent(C);
   Result := Self;
end;

function TEntityBuilder2D.Build: TEntity;
begin
   Result := FEntity;
end;

end.
