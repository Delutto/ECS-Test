unit Showcase.Scene.Health;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Health, P2D.Components.Transform, P2D.Systems.Health, Showcase.Common;

type
   THealthDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH, FSel, FLogN: integer;
      FE: array[0..2] of TEntity;
      FLog: array[0..9] of string;
      FPort: array[0..2] of TTexture2D;
      procedure Log(const S: string);
      function HC(I: integer): THealthComponent2D;
      procedure GenPortraits;
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

const
   PW = 64;
   PH = 96;

function IfS(B: boolean; const T, F: string): string;
begin
   if B then
      Result := T
   else
      Result := F;
end;

constructor THealthDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Health');
   FScreenW := AW;
   FScreenH := AH;
end;

procedure THealthDemoScene.GenPortraits;

   procedure MkP(Idx: integer; BR, BG, BB, AR, AG, AB: byte);
   var
      Img: TImage;
   begin
      Img := GenImageColor(PW, PH, ColorCreate(28, 28, 42, 255));
      ImageDrawRectangle(@Img, 0, 0, PW, PH div 2, ColorCreate(38, 38, 58, 255));
      ImageDrawRectangle(@Img, PW div 4, PH div 2 - 4, PW div 2, PH div 2, ColorCreate(BR, BG, BB, 255));
      ImageDrawRectangle(@Img, PW div 4 + 2, PH div 2 - 2, 6, 18, ColorCreate(Min(255, Integer(BR) + 60), Min(255, Integer(BG) + 60), Min(255, Integer(BB) + 60), 200));
      ImageDrawRectangle(@Img, PW div 4 + 2, PH div 4 - 10, PW div 2 - 4, 24, ColorCreate(220, 190, 160, 255));
      ImageDrawRectangle(@Img, PW div 4 + 6, PH div 4 - 4, 5, 4, ColorCreate(AR, AG, AB, 255));
      ImageDrawRectangle(@Img, PW div 4 + 14, PH div 4 - 4, 5, 4, ColorCreate(AR, AG, AB, 255));
      ImageDrawRectangle(@Img, PW div 4, PH div 4 - 14, PW div 2, 8, ColorCreate(BR, BG, BB, 255));
      ImageDrawRectangle(@Img, PW div 4 - 2, PH div 4 - 10, PW div 2 + 4, 4, ColorCreate(AR, AG, AB, 255));
      ImageDrawRectangle(@Img, PW div 4, PH * 3 div 4, PW div 4 - 2, PH div 4, ColorCreate(BR - 20, BG - 20, BB - 20, 255));
      ImageDrawRectangle(@Img, PW div 2 + 2, PH * 3 div 4, PW div 4 - 2, PH div 4, ColorCreate(BR - 20, BG - 20, BB - 20, 255));
      ImageDrawRectangle(@Img, 0, 0, PW, 2, ColorCreate(AR, AG, AB, 200));
      ImageDrawRectangle(@Img, 0, PH - 2, PW, 2, ColorCreate(AR, AG, AB, 200));
      FPort[Idx] := LoadTextureFromImage(Img);
      UnloadImage(Img);
   end;

begin
   MkP(0, 130, 140, 160, 80, 160, 255);
   MkP(1, 90, 50, 130, 200, 100, 255);
   MkP(2, 140, 50, 50, 220, 90, 40);
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
   GenPortraits;
   Mk(0, 'Knight', 120, 8, 0, 0);
   Mk(1, 'Mage', 60, 0, 5, 2);
   Mk(2, 'Brute', 200, 4, 0, 0);
   World.Init;
   Log('D=dmg15  H=heal20  K=kill  R=revive50%  TAB=select');
end;

procedure THealthDemoScene.DoExit;
var
   I: integer;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
   for I := 0 to 2 do
      if FPort[I].Id > 0 then
      begin
         UnloadTexture(FPort[I]);
         FPort[I].Id := 0;
      end;
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
         Log(Format('[%s] dmg15->-%d net DEF=%d', [FE[FSel].Name, Round(Max(0, 15 - H.Defense)), Round(H.Defense)]));
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
   CW = 260;
   CH = 200;
var
   H: THealthComponent2D;
   Pct, BW: single;
   BC: TColor;
   FA: byte;
   Dst: TRectangle;
begin
   if not Assigned(FE[I]) then
      Exit;
   H := HC(I);
   if I = FSel then
      DrawRectangleLinesEx(RectangleCreate(X - 3, Y - 3, CW + 6, CH + 6), 3, COL_ACCENT);
   DrawRectangle(X, Y, CW, CH, ColorCreate(40, 40, 55, 220));
   DrawRectangleLinesEx(RectangleCreate(X, Y, CW, CH), 1, COL_DIMTEXT);
   if FPort[I].Id > 0 then
   begin
      Dst := RectangleCreate(X + 8, Y + 8, 74, 110);
      DrawTexturePro(FPort[I], RectangleCreate(0, 0, PW, PH), Dst, Vector2Create(0, 0), 0, WHITE);
      DrawRectangleLinesEx(RectangleCreate(X + 7, Y + 7, 76, 112), 1, COL_DIMTEXT);
   end;
   if Assigned(H) then
   begin
      DrawText(PChar(FE[I].Name + IfS(H.Dead, ' [DEAD]', '')), X + 90, Y + 8, 15, COL_TEXT);
      Pct := H.GetHPPercent;
      BW := (CW - 100) * Pct;
      if Pct > 0.5 then
         BC := COL_GOOD
      else
      if Pct > 0.25 then
         BC := COL_WARN
      else
         BC := COL_BAD;
      DrawRectangle(X + 90, Y + 34, CW - 100, 16, ColorCreate(60, 60, 60, 200));
      if BW > 0 then
         DrawRectangle(X + 90, Y + 34, Round(BW), 16, BC);
      DrawRectangleLinesEx(RectangleCreate(X + 90, Y + 34, CW - 100, 16), 1, COL_DIMTEXT);
      DrawText(PChar(Format('HP %.0f/%.0f', [H.HP, H.MaxHP])), X + 94, Y + 36, 11, WHITE);
      DrawText(PChar(Format('DEF %.0f', [H.Defense])), X + 90, Y + 56, 11, COL_DIMTEXT);
      DrawText(PChar(Format('Inv %.1fs', [H.InvincibilityTime])), X + 90, Y + 70, 11, COL_DIMTEXT);
      DrawText(PChar(Format('Regen %.1f/s', [H.RegenRate])), X + 90, Y + 84, 11, COL_DIMTEXT);
      if H.InvincibilityTimer > 0 then
      begin
         FA := Round((H.InvincibilityTimer / H.InvincibilityTime) * 90);
         DrawRectangle(X, Y, CW, CH, ColorCreate(255, 255, 255, FA));
      end;
      if H.Regenerating then
         DrawText('+REGEN', X + 90, Y + 100, 11, COL_GOOD);
      if H.Dead then
         DrawRectangle(X, Y, CW, CH, ColorCreate(20, 10, 10, 160));
   end;
end;

procedure THealthDemoScene.Render;
const
   LY = DEMO_AREA_Y + 218;
var
   I: integer;
begin
   ClearBackground(COL_BG);
   for I := 0 to 12 do
      DrawLine(I * 80, DEMO_AREA_Y, I * 80, SCR_H - FOOTER_H, ColorCreate(40, 40, 56, 90));
   DrawHeader('Demo 1 - Health and Damage System');
   DrawFooter('TAB=select   D=damage 15   H=heal 20   K=kill   R=revive 50%');
   DrawCreature(0, 20, DEMO_AREA_Y + 10);
   DrawCreature(1, 300, DEMO_AREA_Y + 10);
   DrawCreature(2, 580, DEMO_AREA_Y + 10);
   DrawPanel(20, LY, SCR_W - 40, 206, 'Event Log');
   for I := 0 to FLogN - 1 do
      DrawText(PChar(FLog[I]), 32, LY + 26 + I * 17, 12, COL_TEXT);
end;

end.
