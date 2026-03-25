unit Showcase.Scene.Interaction;

{$mode objfpc}{$H+}

{ Demo 5 - Interaction System
  Player (blue) walks with WASD. Press E near objects to interact. }
interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.Event,
   P2D.Core.InputAction, P2D.Core.InputManager,
   P2D.Components.Transform, P2D.Components.Interactable, P2D.Components.InputMap,
   P2D.Systems.Interaction, Showcase.Common;

type
   TInteractionDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: integer;
      FPlayer: TEntity;
      FObjects: array[0..2] of TEntity;
      FInterSys: TInteractionSystem2D;
      FLog: array[0..7] of string;
      FLogN: integer;
      FTRID, FIID: integer;
      procedure Log(const S: string);
      procedure OnInteract(AEvent: TEvent2D);
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
   P2D.Systems.SceneManager, P2D.Core.Events;

constructor TInteractionDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Interaction');

   FScreenW := AW;
   FScreenH := AH;
end;

procedure TInteractionDemoScene.Log(const S: string);
var
   I: integer;
begin
   if FLogN < 8 then
   begin
      FLog[FLogN] := S;
      Inc(FLogN);
   end
   else
   begin
      for I := 0 to 6 do
         FLog[I] := FLog[I + 1];
      FLog[7] := S;
   end;
end;

procedure TInteractionDemoScene.OnInteract(AEvent: TEvent2D);
var
   Ev: TInteractionEvent2D;
begin
   Ev := TInteractionEvent2D(AEvent);
   case TInteractionType2D(Ev.InteractionType) of
      iatOpenChest:
         Log('[Chest] Opened! Gold found.');
      iatTalk:
         Log('[NPC] Hello, adventurer!');
      iatUseSwitch:
         Log('[Switch] Toggled ON/OFF');
      else
         Log('[?] Interacted with object #' + IntToStr(Ev.InteractableID));
   end;
end;

procedure TInteractionDemoScene.DoLoad;
begin
   FInterSys := TInteractionSystem2D(World.AddSystem(TInteractionSystem2D.Create(World, 'Interact')));
end;

procedure TInteractionDemoScene.DoEnter;
var
   E: TEntity;
   Tr: TTransformComponent;
   IC: TInteractableComponent2D;
   IM: TInputMapComponent;
   Map: TInputActionMap;
begin
   FLogN := 0;

   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FIID := ComponentRegistry.GetComponentID(TInteractableComponent2D);

   FPlayer := World.CreateEntity('Player');

   Tr := TTransformComponent.Create;
   Tr.Position.X := DEMO_AREA_CX;
   Tr.Position.Y := DEMO_AREA_CY;
   FPlayer.AddComponent(Tr);

   IM := TInputMapComponent.Create;
   IM.MapName := 'InterDemo';
   FPlayer.AddComponent(IM);

   Map := InputManager.AddMap('InterDemo');
   Map.AddAction('Interact').AddBinding(TInputBinding.FromKey(KEY_E));

   E := World.CreateEntity('GoldChest');

   Tr := TTransformComponent.Create;
   Tr.Position.X := 200;
   Tr.Position.Y := 300;
   E.AddComponent(Tr);

   IC := TInteractableComponent2D.Create;
   IC.InteractionType := iatOpenChest;
   IC.Radius := 64;
   IC.Prompt := '[E] Open chest';
   E.AddComponent(IC);

   FObjects[0] := E;

   E := World.CreateEntity('OldSage');

   Tr := TTransformComponent.Create;
   Tr.Position.X := 600;
   Tr.Position.Y := 250;
   E.AddComponent(Tr);

   IC := TInteractableComponent2D.Create;
   IC.InteractionType := iatTalk;
   IC.Radius := 80;
   IC.Prompt := '[E] Talk';
   E.AddComponent(IC);

   FObjects[1] := E;

   E := World.CreateEntity('Lever');

   Tr := TTransformComponent.Create;
   Tr.Position.X := 450;
   Tr.Position.Y := 460;
   E.AddComponent(Tr);

   IC := TInteractableComponent2D.Create;
   IC.InteractionType := iatUseSwitch;
   IC.Radius := 48;
   IC.Prompt := '[E] Pull lever';
   E.AddComponent(IC);

   FObjects[2] := E;

   World.Init;
   World.EventBus.Subscribe(TInteractionEvent2D, @OnInteract);
   Log('WASD = move   E = interact when in radius');
end;

procedure TInteractionDemoScene.DoExit;
begin
   World.EventBus.Unsubscribe(TInteractionEvent2D, @OnInteract);
   World.ShutdownSystems;
   World.DestroyAllEntities;
   InputManager.RemoveMap('InterDemo');
end;

procedure TInteractionDemoScene.Update(ADelta: single);
var
   Tr: TTransformComponent;
   Spd: single;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   Tr := TTransformComponent(FPlayer.GetComponentByID(FTRID));
   Spd := 160 * ADelta;
   if IsKeyDown(KEY_W) then
      Tr.Position.Y := Tr.Position.Y - Spd;
   if IsKeyDown(KEY_S) then
      Tr.Position.Y := Tr.Position.Y + Spd;
   if IsKeyDown(KEY_A) then
      Tr.Position.X := Tr.Position.X - Spd;
   if IsKeyDown(KEY_D) then
      Tr.Position.X := Tr.Position.X + Spd;
   World.Update(ADelta);
end;

procedure TInteractionDemoScene.Render;
const
   ICN: array[0..2] of string = ('CHEST', 'NPC', 'LEVER');
   CLR: array[0..2] of TColor = (
      (R: 220; G: 180; B: 50; A: 255), (R: 100; G: 200; B: 100; A: 255), (R: 180; G: 100; B: 220; A: 255));
var
   I: integer;
   Tr, PT, OTr: TTransformComponent;
   IC: TInteractableComponent2D;
   DX, DY, D: single;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 5 - Interaction System (TInteractableComponent2D)');
   DrawFooter('WASD=move   E=interact when in radius circle');
   for I := 0 to 2 do
   begin
      OTr := TTransformComponent(FObjects[I].GetComponentByID(FTRID));
      IC := TInteractableComponent2D(FObjects[I].GetComponentByID(FIID));
      if not Assigned(OTr) or not Assigned(IC) then
         Continue;

      DrawCircleLines(Round(OTr.Position.X), Round(OTr.Position.Y), IC.Radius, ColorCreate(CLR[I].R, CLR[I].G, CLR[I].B, 60));
      DrawRectangle(Round(OTr.Position.X) - 18, Round(OTr.Position.Y) - 18, 36, 36, CLR[I]);
      DrawText(PChar(ICN[I]), Round(OTr.Position.X) - 18, Round(OTr.Position.Y) + 20, 10, COL_TEXT);

      PT := TTransformComponent(FPlayer.GetComponentByID(FTRID));
      DX := PT.Position.X - OTr.Position.X;
      DY := PT.Position.Y - OTr.Position.Y;
      D := Sqrt(DX * DX + DY * DY);
      if D <= IC.Radius then
         DrawText(PChar(IC.Prompt), Round(OTr.Position.X) - 40, Round(OTr.Position.Y) - 36, 12, COL_WARN);
   end;
   Tr := TTransformComponent(FPlayer.GetComponentByID(FTRID));

   DrawRectangle(Round(Tr.Position.X) - 12, Round(Tr.Position.Y) - 12, 24, 24, COL_ACCENT);
   DrawText('YOU', Round(Tr.Position.X) - 12, Round(Tr.Position.Y) + 14, 11, COL_TEXT);
   DrawPanel(SCR_W - 310, DEMO_AREA_Y + 10, 300, 220, 'Event Log');
   for I := 0 to FLogN - 1 do
      DrawText(PChar(FLog[I]), SCR_W - 300, DEMO_AREA_Y + 34 + I * 22, 11, COL_TEXT);
end;

end.
