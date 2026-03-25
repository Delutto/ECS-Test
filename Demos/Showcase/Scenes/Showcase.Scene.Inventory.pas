unit Showcase.Scene.Inventory;

{$mode objfpc}{$H+}

{ Demo 3 - Inventory System
  Arrows=move cursor  A=add item  R=remove  S=split  E=equip  Q=unequip MainHand }
interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Components.Inventory, Showcase.Common;

type
   TInventoryDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH, FCursor: integer;
      FEntity: TEntity;
      FLog: array[0..5] of string;
      FLogN: integer;
      function Inv: TInventoryComponent2D;
      procedure Log(const S: string);
      procedure AddRandom;
      procedure DrawSlot(Idx, X, Y, W, H: integer);
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
   INM: array[0..4] of string = ('Sword', 'Potion', 'Arrow', 'Gold', 'Shield');
   ITP: array[0..4] of TItemType2D = (itWeapon, itConsumable, itAmmo, itMisc, itArmor);
   IES: array[0..4] of TEquipSlot2D = (esMainHand, esNone, esNone, esNone, esOffHand);

constructor TInventoryDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Inventory');

   FScreenW := AW;
   FScreenH := AH;
end;

function TInventoryDemoScene.Inv: TInventoryComponent2D;
begin
   Result := TInventoryComponent2D(FEntity.GetComponentByID(ComponentRegistry.GetComponentID(TInventoryComponent2D)));
end;

procedure TInventoryDemoScene.Log(const S: string);
var
   I: integer;
begin
   if FLogN < 6 then
   begin
      FLog[FLogN] := S;
      Inc(FLogN);
   end
   else
   begin
      for I := 0 to 4 do
         FLog[I] := FLog[I + 1];
      FLog[5] := S;
   end;
end;

procedure TInventoryDemoScene.AddRandom;
var
   Item: TItemData2D;
   K: integer;
begin
   K := Random(5);
   FillChar(Item, SizeOf(Item), 0);
   Item.ID := K + 1;
   Item.Name := INM[K];
   Item.ItemType := ITP[K];
   Item.EquipSlot := IES[K];
   Item.MaxStack := IfThen(K = 3, 99, 1);
   if Inv.AddItem(Item) >= 0 then
      Log('Added: ' + Item.Name)
   else
      Log('Inventory full!');
end;

procedure TInventoryDemoScene.DoLoad;
begin
end;

procedure TInventoryDemoScene.DoEnter;
begin
   FCursor := 0;
   FLogN := 0;
   FEntity := World.CreateEntity('Hero');
   FEntity.AddComponent(TInventoryComponent2D.Create);
   World.Init;
   Log('A=add  R=remove  S=split  E=equip  Q=unequip');
end;

procedure TInventoryDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TInventoryDemoScene.Update(ADelta: single);
var
   N: integer;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      System.Exit;
   end;
   N := Inv.SlotCount;
   if IsKeyPressed(KEY_RIGHT) then
      FCursor := (FCursor + 1) mod N;
   if IsKeyPressed(KEY_LEFT) then
      FCursor := (FCursor - 1 + N) mod N;
   if IsKeyPressed(KEY_DOWN) then
      FCursor := (FCursor + 5) mod N;
   if IsKeyPressed(KEY_UP) then
      FCursor := (FCursor - 5 + N) mod N;
   if IsKeyPressed(KEY_A) then
      AddRandom;
   if IsKeyPressed(KEY_R) then
   begin
      Inv.RemoveAt(FCursor, 1);
      Log('Removed 1 from slot ' + IntToStr(FCursor));
   end;
   if IsKeyPressed(KEY_S) then
   begin
      if Inv.SplitSlot(FCursor) >= 0 then
         Log('Split slot ' + IntToStr(FCursor))
      else
         Log('Cannot split');
   end;
   if IsKeyPressed(KEY_E) then
   begin
      if Inv.Equip(FCursor) then
         Log('Equipped slot ' + IntToStr(FCursor))
      else
         Log('Cannot equip');
   end;
   if IsKeyPressed(KEY_Q) then
   begin
      if Inv.Unequip(esMainHand) then
         Log('Unequipped MainHand')
      else
         Log('Nothing in MainHand');
   end;
   World.Update(ADelta);
end;

procedure TInventoryDemoScene.DrawSlot(Idx, X, Y, W, H: integer);
var
   Sl: TInventorySlot2D;
   BC, TC2: TColor;
begin
   Sl := Inv[Idx];
   if Idx = FCursor then
      BC := COL_ACCENT
   else
      BC := COL_DIMTEXT;
   DrawRectangle(X, Y, W, H, ColorCreate(40, 40, 55, 220));
   DrawRectangleLinesEx(RectangleCreate(X, Y, W, H), 2, BC);
   if Sl.Count > 0 then
   begin
      case Sl.Item.ItemType of
         itWeapon:
            TC2 := COL_WARN;
         itConsumable:
            TC2 := COL_GOOD;
         itAmmo:
            TC2 := COL_ACCENT;
         else
            TC2 := COL_TEXT;
      end;
      DrawText(PChar(Copy(Sl.Item.Name, 1, 4)), X + 3, Y + 5, 10, TC2);
      if Sl.Item.MaxStack > 1 then
         DrawText(PChar('x' + IntToStr(Sl.Count)), X + 3, Y + H - 16, 10, COL_TEXT);
   end;
   DrawText(PChar(IntToStr(Idx)), X + W - 16, Y + 2, 9, COL_DIMTEXT);
end;

procedure TInventoryDemoScene.Render;
const
   SW = 54;
   SH = 50;
   COLS = 5;
   GX = 30;
   GY = DEMO_AREA_Y + 30;
var
   I: integer;
   ES: TEquipSlot2D;
   ESl: TInventorySlot2D;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 3 - Inventory System (TInventoryComponent2D)');
   DrawFooter('Arrows=move   A=add   R=remove   S=split   E=equip   Q=unequip MainHand');
   DrawPanel(GX - 8, GY - 8, (SW + 4) * COLS + 16 + 8, (SH + 4) * 4 + 24, '20-Slot Inventory');
   for I := 0 to Inv.SlotCount - 1 do
      DrawSlot(I, GX + (I mod COLS) * (SW + 4), GY + 24 + (I div COLS) * (SH + 4), SW, SH);
   DrawPanel(340, GY, 440, 240, 'Equipment and Info');
   DrawText(PChar('Cursor: slot ' + IntToStr(FCursor)), 350, GY + 26, 13, COL_TEXT);
   if not Inv.IsEmpty(FCursor) then
      DrawText(PChar('  Item: ' + Inv[FCursor].Item.Name + '  x' + IntToStr(Inv[FCursor].Count)),
         350, GY + 46, 12, COL_GOOD);
   DrawText('Equipped:', 350, GY + 70, 13, COL_TEXT);
   I := 0;
   for ES := esHead to esAcc2 do
   begin
      ESl := Inv.GetEquipped(ES);
      if ESl.Count > 0 then
         DrawText(PChar(Format('  [%d] %s', [Ord(ES), ESl.Item.Name])), 350, GY + 90 + I * 18, 12, COL_WARN);
      Inc(I);
   end;
   DrawPanel(340, GY + 250, 440, 140, 'Log');
   for I := 0 to FLogN - 1 do
      DrawText(PChar(FLog[I]), 350, GY + 276 + I * 18, 12, COL_TEXT);
end;

end.
