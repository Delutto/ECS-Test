unit P2D.Components.Inventory;
{$mode objfpc}{$H+}
interface
uses SysUtils,Math,raylib,P2D.Core.Component,P2D.Core.Types;
const ITEM_ID_NONE=0;
type
  TItemType2D=(itNone,itWeapon,itTool,itArmor,itConsumable,itMaterial,itAmmo,itMisc);
  TEquipSlot2D=(esNone,esHead,esChest,esLegs,esFeet,esMainHand,esOffHand,esAcc1,esAcc2);
  TItemData2D=record
    ID,MaxStack,Value:Integer;
    Name,Description,TextureKey,Tags:String;
    ItemType:TItemType2D;
    Weight,Damage,Defense,UseSpeed:Single;
    EquipSlot:TEquipSlot2D;
    SourceRect:TRectangle;
  end;
  TInventorySlot2D=record Item:TItemData2D; Count:Integer; end;
  TOnInventoryChangedProc2D=procedure(AID:Cardinal;ASlot:Integer) of object;
  TInventoryComponent2D=class(TComponent2D)
  private
    FSlots:array of TInventorySlot2D;
    FSlotCount,FHotbarSize,FActiveHotbar:Integer;
    FEquipSlots:array[TEquipSlot2D]of TInventorySlot2D;
    FOnChanged:TOnInventoryChangedProc2D;
    function  GetSlot(I:Integer):TInventorySlot2D;
    procedure SetSlot(I:Integer;const S:TInventorySlot2D);
    procedure Notify(I:Integer);
  public
    constructor Create;override;
    procedure Resize(N:Integer);
    function  AddItem(const Item:TItemData2D;Qty:Integer=1):Integer;
    function  RemoveItem(ItemID:Integer;Qty:Integer=1):Integer;
    procedure RemoveAt(I:Integer;Qty:Integer=1);
    function  CountItem(ItemID:Integer):Integer;
    function  FindItem(ItemID:Integer):Integer;
    procedure SwapSlots(I,J:Integer);
    function  SplitSlot(I:Integer):Integer;
    function  IsEmpty(I:Integer):Boolean;
    function  Equip(I:Integer):Boolean;
    function  Unequip(ES:TEquipSlot2D):Boolean;
    function  GetEquipped(ES:TEquipSlot2D):TInventorySlot2D;
    property Slots[I:Integer]:TInventorySlot2D read GetSlot write SetSlot;default;
    property SlotCount:Integer read FSlotCount;
    property HotbarSize:Integer read FHotbarSize write FHotbarSize;
    property ActiveHotbar:Integer read FActiveHotbar write FActiveHotbar;
    property OnChanged:TOnInventoryChangedProc2D read FOnChanged write FOnChanged;
  end;
implementation
uses P2D.Core.ComponentRegistry,P2D.Common;
procedure ClearSl(var S:TInventorySlot2D);
begin FillChar(S,SizeOf(S),0);S.Item.ID:=ITEM_ID_NONE;S.Item.Name:='';S.Count:=0;end;
constructor TInventoryComponent2D.Create;
var ES:TEquipSlot2D;
begin inherited Create;
  FSlotCount:=0;FHotbarSize:=MAX_HOTBAR_SLOTS;FActiveHotbar:=0;FOnChanged:=nil;
  for ES:=Low(TEquipSlot2D)to High(TEquipSlot2D)do ClearSl(FEquipSlots[ES]);
  Resize(MAX_INVENTORY_SLOTS);end;
procedure TInventoryComponent2D.Resize(N:Integer);
var I:Integer;
begin if N<0 then N:=0;
  SetLength(FSlots,N);
  for I:=FSlotCount to N-1 do ClearSl(FSlots[I]);
  FSlotCount:=N;end;
function TInventoryComponent2D.GetSlot(I:Integer):TInventorySlot2D;
begin if(I>=0)and(I<FSlotCount)then Result:=FSlots[I]else ClearSl(Result);end;
procedure TInventoryComponent2D.SetSlot(I:Integer;const S:TInventorySlot2D);
begin if(I>=0)and(I<FSlotCount)then begin FSlots[I]:=S;Notify(I);end;end;
procedure TInventoryComponent2D.Notify(I:Integer);
begin if Assigned(FOnChanged)then FOnChanged(OwnerEntity,I);end;
function TInventoryComponent2D.AddItem(const Item:TItemData2D;Qty:Integer):Integer;
var I,MS,CA,Rem:Integer;
begin Result:=-1;Rem:=Qty;MS:=Item.MaxStack;if MS<=0 then MS:=1;
  for I:=0 to FSlotCount-1 do
    if(FSlots[I].Item.ID=Item.ID)and(FSlots[I].Count<MS)then begin
      CA:=Min(Rem,MS-FSlots[I].Count);FSlots[I].Count:=FSlots[I].Count+CA;
      Dec(Rem,CA);Notify(I);if Result<0 then Result:=I;if Rem<=0 then Exit;end;
  for I:=0 to FSlotCount-1 do
    if FSlots[I].Count=0 then begin
      CA:=Min(Rem,MS);FSlots[I].Item:=Item;FSlots[I].Count:=CA;
      Dec(Rem,CA);Notify(I);if Result<0 then Result:=I;if Rem<=0 then Exit;end;end;
function TInventoryComponent2D.RemoveItem(ItemID:Integer;Qty:Integer):Integer;
var I,Rm,Rm2:Integer;
begin Rm2:=0;
  for I:=0 to FSlotCount-1 do
    if FSlots[I].Item.ID=ItemID then begin
      Rm:=Min(Qty-Rm2,FSlots[I].Count);FSlots[I].Count:=FSlots[I].Count-Rm;
      Inc(Rm2,Rm);if FSlots[I].Count=0 then ClearSl(FSlots[I]);
      Notify(I);if Rm2>=Qty then Break;end;
  Result:=Rm2;end;
procedure TInventoryComponent2D.RemoveAt(I:Integer;Qty:Integer);
begin if(I<0)or(I>=FSlotCount)or(Qty<=0)then Exit;
  Dec(FSlots[I].Count,Qty);
  if FSlots[I].Count<=0 then ClearSl(FSlots[I]);Notify(I);end;
function TInventoryComponent2D.CountItem(ItemID:Integer):Integer;
var I:Integer;begin Result:=0;
  for I:=0 to FSlotCount-1 do if FSlots[I].Item.ID=ItemID then Inc(Result,FSlots[I].Count);end;
function TInventoryComponent2D.FindItem(ItemID:Integer):Integer;
var I:Integer;
begin for I:=0 to FSlotCount-1 do if FSlots[I].Item.ID=ItemID then begin Result:=I;Exit;end;
  Result:=-1;end;
procedure TInventoryComponent2D.SwapSlots(I,J:Integer);
var T:TInventorySlot2D;
begin if(I<0)or(I>=FSlotCount)or(J<0)or(J>=FSlotCount)or(I=J)then Exit;
  T:=FSlots[I];FSlots[I]:=FSlots[J];FSlots[J]:=T;Notify(I);Notify(J);end;
function TInventoryComponent2D.SplitSlot(I:Integer):Integer;
var Half,J:Integer;
begin Result:=-1;if(I<0)or(I>=FSlotCount)or(FSlots[I].Count<2)then Exit;
  Half:=FSlots[I].Count div 2;
  for J:=0 to FSlotCount-1 do if FSlots[J].Count=0 then begin
    FSlots[J].Item:=FSlots[I].Item;FSlots[J].Count:=Half;
    Dec(FSlots[I].Count,Half);Notify(I);Notify(J);Result:=J;Exit;end;end;
function TInventoryComponent2D.IsEmpty(I:Integer):Boolean;
begin if(I>=0)and(I<FSlotCount)then Result:=FSlots[I].Count=0 else Result:=True;end;
function TInventoryComponent2D.Equip(I:Integer):Boolean;
var ES:TEquipSlot2D;
begin Result:=False;if(I<0)or(I>=FSlotCount)or(FSlots[I].Count=0)then Exit;
  ES:=FSlots[I].Item.EquipSlot;if ES=esNone then Exit;
  FEquipSlots[ES]:=FSlots[I];ClearSl(FSlots[I]);Notify(I);Result:=True;end;
function TInventoryComponent2D.Unequip(ES:TEquipSlot2D):Boolean;
var S:Integer;
begin Result:=False;if FEquipSlots[ES].Count=0 then Exit;
  S:=AddItem(FEquipSlots[ES].Item,FEquipSlots[ES].Count);
  if S>=0 then begin ClearSl(FEquipSlots[ES]);Result:=True;end;end;
function TInventoryComponent2D.GetEquipped(ES:TEquipSlot2D):TInventorySlot2D;
begin Result:=FEquipSlots[ES];end;
initialization ComponentRegistry.Register(TInventoryComponent2D);
end.
