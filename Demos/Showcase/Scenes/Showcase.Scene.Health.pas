unit Showcase.Scene.Health;

{$mode objfpc}{$H+}

{ Demo 1 - Health and Damage System
  Three creatures; TAB=select  D=damage  H=heal  K=kill  R=revive }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Health, P2D.Components.Transform,
   P2D.Systems.Health, Showcase.Common;

type
   THealthDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH, FSel, FLogN: integer;
      FE: array[0..2] of TEntity;
      FLog: array[0..9] of string;
      procedure Log(const S: string);
      function HC(I: integer): THealthComponent2D;
      procedure DrawCreature(I, X, Y: integer);
      procedure OnDie(AID: cardinal);
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AW, AH: integer);
      procedure Update(ADelta: single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Systems.SceneManager;

constructor THealthDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Health');

   FScreenW := AW;
   FScreenH := AH;
end;

procedure THealthDemoScene.Log(const S: string);
var
   I: integer;
begin
   if FLogN < 10 then
   begin
      FLog[FLogN] := S;
      Inc(FLogN);
   end
   else
   begin
      for I := 0 to 8 do
         FLog[I] := FLog[I + 1];
      FLog[9] := S;
   end;
end;

procedure THealthDemoScene.OnDie(AID: cardinal);
begin
   Log(Format('Entity #%d DIED!', [AID]));
end;

function THealthDemoScene.HC(I: integer): THealthComponent2D;
begin
   if not Assigned(FE[I]) then
   begin
      Result := nil;
      Exit;
   end;
   Result := THealthComponent2D(FE[I].GetComponentByID(ComponentRegistry.GetComponentID(THealthComponent2D)));
end;

procedure THealthDemoScene.DoLoad;
begin
   World.AddSystem(THealthSystem2D.Create(World));
end;

procedure THealthDemoScene.DoEnter;
var
   H: THealthComponent2D;
   E: TEntity;
   Tr: TTransformComponent;

   procedure Mk(Idx: integer; const N: string; MaxHP, Def, Regen, RD: single);
   begin
      E := World.CreateEntity(N);
      Tr := TTransformComponent.Create;
      E.AddComponent(Tr);
      H := THealthComponent2D.Create;
      H.MaxHP := MaxHP;
      H.HP := MaxHP;
      H.Defense := Def;
      H.InvincibilityTime := 0.6;
      H.RegenRate := Regen;
      H.RegenDelay := RD;
      H.OwnerEntity := E.ID;
      H.OnDeath := @OnDie;
      E.AddComponent(H);
      FE[Idx] := E;
   end;

begin
   FSel := 0;
   FLogN := 0;
   Mk(0, 'Knight', 120, 8, 0, 0);
   Mk(1, 'Mage', 60, 0, 5, 2);
   Mk(2, 'Brute', 200, 4, 0, 0);
   World.Init;
   Log('D=dmg15  H=heal20  K=kill  R=revive50%  TAB=select');
end;

procedure THealthDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure THealthDemoScene.Update(ADelta: single);
var
   H: THealthComponent2D;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_TAB) then
      FSel := (FSel + 1) mod 3;
   H := HC(FSel);
   if Assigned(H) then
   begin
      if IsKeyPressed(KEY_D) then
      begin
         H.TakeDamage(15);
         Log(Format('[%s] dmg15 -> -%d net (DEF=%d)', [FE[FSel].Name, Round(Max(0, 15 - H.Defense)), Round(H.Defense)]));
      end;
      if IsKeyPressed(KEY_H) then
      begin
         H.Heal(20);
         Log('[' + FE[FSel].Name + '] heal+20');
      end;
      if IsKeyPressed(KEY_K) then
      begin
         H.Kill;
         Log('[' + FE[FSel].Name + '] killed!');
      end;
      if IsKeyPressed(KEY_R) then
      begin
         H.Revive(0.5);
         Log('[' + FE[FSel].Name + '] revived 50%');
      end;
   end;
   World.Update(ADelta);
end;

procedure THealthDemoScene.DrawCreature(I, X, Y: integer);
const
   CW = 240;
   CH = 140;
var
   H: THealthComponent2D;
   Pct, BW: single;
   BC: TColor;
   FA: byte;
begin
   if not Assigned(FE[I]) then
      Exit;
   H := HC(I);
   if I = FSel then
      DrawRectangleLinesEx(RectangleCreate(X - 3, Y - 3, CW + 6, CH + 6), 3, COL_ACCENT);
   DrawRectangle(X, Y, CW, CH, ColorCreate(40, 40, 55, 220));
   DrawRectangleLinesEx(RectangleCreate(X, Y, CW, CH), 1, COL_DIMTEXT);
   if Assigned(H) then
   begin
      DrawText(PChar(FE[I].Name + ifThen(H.Dead, ' [DEAD]', '')), X + 8, Y + 8, 14, COL_TEXT);
      Pct := H.GetHPPercent;
      BW := (CW - 16) * Pct;
      if Pct > 0.5 then
         BC := COL_GOOD
      else
      if Pct > 0.25 then
         BC := COL_WARN
      else
         BC := COL_BAD;
      DrawRectangle(X + 8, Y + 32, CW - 16, 14, ColorCreate(60, 60, 60, 200));
      if BW > 0 then
         DrawRectangle(X + 8, Y + 32, Round(BW), 14, BC);
      DrawText(PChar(Format('HP %.0f/%.0f', [H.HP, H.MaxHP])), X + 8, Y + 50, 12, COL_TEXT);
      DrawText(PChar(Format('DEF %.0f  Inv %.1fs  Regen %.1f/s', [H.Defense, H.InvincibilityTime, H.RegenRate])), X + 8, Y + 68, 11, COL_DIMTEXT);
      if H.InvincibilityTimer > 0 then
      begin
         FA := Round((H.InvincibilityTimer / H.InvincibilityTime) * 90);
         DrawRectangle(X, Y, CW, CH, ColorCreate(255, 255, 255, FA));
      end;
      if H.Regenerating then
         DrawText('+REGEN', X + 8, Y + 88, 11, COL_GOOD);
   end;
end;

procedure THealthDemoScene.Render;
const
   LY = 450;
var
   I: integer;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 1 - Health and Damage System');
   DrawFooter('TAB=select   D=damage 15   H=heal 20   K=kill   R=revive 50%');
   DrawCreature(0, 40, DEMO_AREA_Y + 20);
   DrawCreature(1, 300, DEMO_AREA_Y + 20);
   DrawCreature(2, 560, DEMO_AREA_Y + 20);
   DrawPanel(30, LY, SCR_W - 60, 200, 'Event Log');
   for I := 0 to FLogN - 1 do
      DrawText(PChar(FLog[I]), 42, LY + 26 + I * 17, 12, COL_TEXT);
end;

end.
