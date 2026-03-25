unit P2D.Core.Events;
{$mode objfpc}{$H+}
interface

uses
   P2D.Core.Event, P2D.Core.Types;

type
   TEntityOverlapEvent = class(TEvent2D)
   public
      EntityAID, EntityBID: TEntityID;
      TagA, TagB: TColliderTag;
      IsTriggerA, IsTriggerB: boolean;
      constructor Create(AEA, AEB: TEntityID; ATagA, ATagB: TColliderTag; ATA, ATB: boolean);
   end;

   THealthChangedEvent2D = class(TEvent2D)
   public
      EntityID: TEntityID;
      OldHP, NewHP, MaxHP: single;
      IsDamage: boolean;
      constructor Create(AID: TEntityID; AOld, ANew, AMax: single);
   end;

   TEntityDiedEvent2D = class(TEvent2D)
   public
      EntityID, KillerID: TEntityID;
      WorldX, WorldY: single;
      constructor Create(AID, AKiller: TEntityID; AX, AY: single);
   end;

   TItemPickedUpEvent2D = class(TEvent2D)
   public
      EntityID: TEntityID;
      ItemID: integer;
      ItemName: string;
      Quantity, SlotIndex: integer;
      constructor Create(AEnt: TEntityID; AItem: integer; const AName: string; AQty, ASlot: integer);
   end;

   TItemDroppedEvent2D = class(TEvent2D)
   public
      EntityID: TEntityID;
      ItemID, Quantity: integer;
      WorldX, WorldY: single;
      constructor Create(AEnt: TEntityID; AItem, AQty: integer; AX, AY: single);
   end;

   TInventoryChangedEvent2D = class(TEvent2D)
   public
      EntityID: TEntityID;
      SlotIndex: integer;
      constructor Create(AEnt: TEntityID; ASlot: integer);
   end;

   TProjectileHitEvent2D = class(TEvent2D)
   public
      ProjectileID, TargetID, SourceID: TEntityID;
      Damage, WorldX, WorldY: single;
      constructor Create(APr, ATg, ASrc: TEntityID; ADmg, AX, AY: single);
   end;

   TInteractionEvent2D = class(TEvent2D)
   public
      ActorID, InteractableID: TEntityID;
      InteractionType: integer;
      constructor Create(AActor, AInter: TEntityID; AType: integer);
   end;

   TDayNightPhaseEvent2D = class(TEvent2D)
   public
      NewPhase: integer;
      TimeOfDay: single;
      constructor Create(APhase: integer; ATime: single);
   end;

   TChunkLoadedEvent2D = class(TEvent2D)
   public
      ChunkX, ChunkY: integer;
      constructor Create(ACX, ACY: integer);
   end;

   TChunkUnloadedEvent2D = class(TEvent2D)
   public
      ChunkX, ChunkY: integer;
      constructor Create(ACX, ACY: integer);
   end;

   TDialogStartedEvent2D = class(TEvent2D)
   public
      ActorID, DialogOwner: TEntityID;
      constructor Create(AActor, AOwner: TEntityID);
   end;

   TDialogEndedEvent2D = class(TEvent2D)
   public
      ActorID, DialogOwner: TEntityID;
      ChosenOptionIdx: integer;
      constructor Create(AActor, AOwner: TEntityID; AChoice: integer);
   end;

implementation

constructor TEntityOverlapEvent.Create(AEA, AEB: TEntityID; ATagA, ATagB: TColliderTag; ATA, ATB: boolean);
begin
   inherited Create;
   EntityAID := AEA;
   EntityBID := AEB;
   TagA := ATagA;
   TagB := ATagB;
   IsTriggerA := ATA;
   IsTriggerB := ATB;
end;

constructor THealthChangedEvent2D.Create(AID: TEntityID; AOld, ANew, AMax: single);
begin
   inherited Create;
   EntityID := AID;
   OldHP := AOld;
   NewHP := ANew;
   MaxHP := AMax;
   IsDamage := ANew < AOld;
end;

constructor TEntityDiedEvent2D.Create(AID, AKiller: TEntityID; AX, AY: single);
begin
   inherited Create;
   EntityID := AID;
   KillerID := AKiller;
   WorldX := AX;
   WorldY := AY;
end;

constructor TItemPickedUpEvent2D.Create(AEnt: TEntityID; AItem: integer; const AName: string; AQty, ASlot: integer);
begin
   inherited Create;
   EntityID := AEnt;
   ItemID := AItem;
   ItemName := AName;
   Quantity := AQty;
   SlotIndex := ASlot;
end;

constructor TItemDroppedEvent2D.Create(AEnt: TEntityID; AItem, AQty: integer; AX, AY: single);
begin
   inherited Create;
   EntityID := AEnt;
   ItemID := AItem;
   Quantity := AQty;
   WorldX := AX;
   WorldY := AY;
end;

constructor TInventoryChangedEvent2D.Create(AEnt: TEntityID; ASlot: integer);
begin
   inherited Create;
   EntityID := AEnt;
   SlotIndex := ASlot;
end;

constructor TProjectileHitEvent2D.Create(APr, ATg, ASrc: TEntityID; ADmg, AX, AY: single);
begin
   inherited Create;
   ProjectileID := APr;
   TargetID := ATg;
   SourceID := ASrc;
   Damage := ADmg;
   WorldX := AX;
   WorldY := AY;
end;

constructor TInteractionEvent2D.Create(AActor, AInter: TEntityID; AType: integer);
begin
   inherited Create;
   ActorID := AActor;
   InteractableID := AInter;
   InteractionType := AType;
end;

constructor TDayNightPhaseEvent2D.Create(APhase: integer; ATime: single);
begin
   inherited Create;
   NewPhase := APhase;
   TimeOfDay := ATime;
end;

constructor TChunkLoadedEvent2D.Create(ACX, ACY: integer);
begin
   inherited Create;
   ChunkX := ACX;
   ChunkY := ACY;
end;

constructor TChunkUnloadedEvent2D.Create(ACX, ACY: integer);
begin
   inherited Create;
   ChunkX := ACX;
   ChunkY := ACY;
end;

constructor TDialogStartedEvent2D.Create(AActor, AOwner: TEntityID);
begin
   inherited Create;
   ActorID := AActor;
   DialogOwner := AOwner;
end;

constructor TDialogEndedEvent2D.Create(AActor, AOwner: TEntityID; AChoice: integer);
begin
   inherited Create;
   ActorID := AActor;
   DialogOwner := AOwner;
   ChosenOptionIdx := AChoice;
end;

end.
