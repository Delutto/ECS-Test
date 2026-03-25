unit P2D.Components.Health;
{$mode objfpc}{$H+}
interface

uses
   SysUtils, Math, P2D.Core.Component, P2D.Core.Types;

type
   TOnHealthChangedProc2D = procedure(AID: cardinal; AOld, ANew: single) of object;
   TOnDeathProc2D = procedure(AID: cardinal) of object;

   THealthComponent2D = class(TComponent2D)
   private
      FHP, FMaxHP, FDefense: single;
      FInvincibilityTime, FInvincibilityTimer: single;
      FDead, FRegenerating: boolean;
      FRegenRate, FRegenDelay, FRegenTimer: single;
      FOnHealthChanged: TOnHealthChangedProc2D;
      FOnDeath: TOnDeathProc2D;
   public
      constructor Create; override;
      procedure TakeDamage(Amt: single; Killer: cardinal = 0; IgnoreInv: boolean = False);
      procedure Heal(Amt: single);
      procedure Kill(Killer: cardinal = 0);
      procedure Revive(Pct: single = 1.0);
      function GetHPPercent: single; inline;
      property HP: single read FHP write FHP;
      property MaxHP: single read FMaxHP write FMaxHP;
      property Defense: single read FDefense write FDefense;
      property InvincibilityTime: single read FInvincibilityTime write FInvincibilityTime;
      property InvincibilityTimer: single read FInvincibilityTimer write FInvincibilityTimer;
      property Dead: boolean read FDead write FDead;
      property Regenerating: boolean read FRegenerating write FRegenerating;
      property RegenRate: single read FRegenRate write FRegenRate;
      property RegenDelay: single read FRegenDelay write FRegenDelay;
      property RegenTimer: single read FRegenTimer write FRegenTimer;
      property OnHealthChanged: TOnHealthChangedProc2D read FOnHealthChanged write FOnHealthChanged;
      property OnDeath: TOnDeathProc2D read FOnDeath write FOnDeath;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor THealthComponent2D.Create;
begin
   inherited Create;
   FHP := 100;
   FMaxHP := 100;
   FDefense := 0;
   FInvincibilityTime := 0.5;
   FInvincibilityTimer := 0;
   FDead := False;
   FRegenerating := False;
   FRegenRate := 0;
   FRegenDelay := 3;
   FRegenTimer := 0;
   FOnHealthChanged := nil;
   FOnDeath := nil;
end;

procedure THealthComponent2D.TakeDamage(Amt: single; Killer: cardinal; IgnoreInv: boolean);
var
   Old, FD: single;
begin
   if FDead then
      Exit;
   if (not IgnoreInv) and (FInvincibilityTimer > 0) then
      Exit;
   Old := FHP;
   FD := Max(0, Amt - FDefense);
   FHP := Max(0, FHP - FD);
   if FD > 0 then
   begin
      FInvincibilityTimer := FInvincibilityTime;
      FRegenTimer := 0;
   end;
   if Assigned(FOnHealthChanged) then
      FOnHealthChanged(OwnerEntity, Old, FHP);
   if FHP <= 0 then
      Kill(Killer);
end;

procedure THealthComponent2D.Heal(Amt: single);
var
   Old: single;
begin
   if FDead then
      Exit;
   Old := FHP;
   FHP := Min(FMaxHP, FHP + Amt);
   if (FHP <> Old) and Assigned(FOnHealthChanged) then
      FOnHealthChanged(OwnerEntity, Old, FHP);
end;

procedure THealthComponent2D.Kill(Killer: cardinal);
begin
   if FDead then
      Exit;
   FHP := 0;
   FDead := True;
   if Assigned(FOnDeath) then
      FOnDeath(OwnerEntity);
end;

procedure THealthComponent2D.Revive(Pct: single);
begin
   FDead := False;
   FHP := FMaxHP * Max(0.01, Min(1, Pct));
   FInvincibilityTimer := FInvincibilityTime;
   FRegenTimer := 0;
end;

function THealthComponent2D.GetHPPercent: single;
begin
   if FMaxHP > 0 then
      Result := FHP / FMaxHP
   else
      Result := 0;
end;

initialization
   ComponentRegistry.Register(THealthComponent2D);
end.
