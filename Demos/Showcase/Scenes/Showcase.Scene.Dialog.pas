unit Showcase.Scene.Dialog;

{$mode objfpc}{$H+}

{ Demo 8 - Dialog Tree System
  WASD=move  E=talk to NPC  UP/DOWN=choice  ENTER=confirm }
interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.Event,
   P2D.Core.InputAction, P2D.Core.InputManager,
   P2D.Components.Transform, P2D.Components.Interactable,
   P2D.Components.Dialog, P2D.Components.InputMap,
   P2D.Systems.Interaction, P2D.Systems.Dialog, Showcase.Common;

type
   TDialogDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH, FCurChoice: integer;
      FPlayer, FNpc: TEntity;
      FInterSys: TInteractionSystem2D;
      FDialSys: TDialogSystem2D;
      FTRID, FDID: integer;
      function DCmp: TDialogComponent2D;
      procedure OnDS(AEvent: TEvent2D);
      procedure OnDE(AEvent: TEvent2D);
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

constructor TDialogDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Dialog');
   FScreenW := AW;
   FScreenH := AH;
end;

function TDialogDemoScene.DCmp: TDialogComponent2D;
begin
   Result := TDialogComponent2D(FNpc.GetComponentByID(FDID));
end;

procedure TDialogDemoScene.OnDS(AEvent: TEvent2D);
begin
end;

procedure TDialogDemoScene.OnDE(AEvent: TEvent2D);
begin
end;

procedure TDialogDemoScene.DoLoad;
begin
   FInterSys := TInteractionSystem2D(World.AddSystem(TInteractionSystem2D.Create(World, 'Interact')));
   FDialSys := TDialogSystem2D(World.AddSystem(TDialogSystem2D.Create(World)));
end;

procedure TDialogDemoScene.DoEnter;
var
   Tr: TTransformComponent;
   IC: TInteractableComponent2D;
   D: TDialogComponent2D;
   IM: TInputMapComponent;
   Map: TInputActionMap;
   N0, N1, N2, N3: integer;
begin
   FCurChoice := 0;
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FDID := ComponentRegistry.GetComponentID(TDialogComponent2D);
   FPlayer := World.CreateEntity('Player');
   Tr := TTransformComponent.Create;
   Tr.Position.X := 200;
   Tr.Position.Y := 350;
   FPlayer.AddComponent(Tr);
   IM := TInputMapComponent.Create;
   IM.MapName := 'DlgDemo';
   FPlayer.AddComponent(IM);
   Map := InputManager.AddMap('DlgDemo');
   Map.AddAction('Interact').AddBinding(TInputBinding.FromKey(KEY_E));
   FNpc := World.CreateEntity('Elder');
   Tr := TTransformComponent.Create;
   Tr.Position.X := 520;
   Tr.Position.Y := 350;
   FNpc.AddComponent(Tr);
   IC := TInteractableComponent2D.Create;
   IC.InteractionType := iatTalk;
   IC.Radius := 110;
   IC.Prompt := '[E] Speak';
   FNpc.AddComponent(IC);
   D := TDialogComponent2D.Create;
   N0 := D.AddNode('Elder', 'Greetings, traveller. What brings you here?');
   D.AddChoice(N0, 'I seek the ancient rune.', 1);
   D.AddChoice(N0, 'Just passing through.', 2);
   N1 := D.AddNode('Elder', 'The Rune of Eternity! It rests in the Cavern of Shadows.');
   D.AddChoice(N1, 'Tell me how to find it.', 3);
   D.AddChoice(N1, 'Perhaps another time.', 2);
   N2 := D.AddNode('Elder', 'Safe travels then, stranger. May fortune guide you.');
   N3 := D.AddNode('Elder', 'Head north past the Iron Bridge, descend the spiral stairs. ' + 'The rune glows blue. You will know it.');
   FNpc.AddComponent(D);
   World.Init;
   World.EventBus.Subscribe(TDialogStartedEvent2D, @OnDS);
   World.EventBus.Subscribe(TDialogEndedEvent2D, @OnDE);
end;

procedure TDialogDemoScene.DoExit;
begin
   World.EventBus.Unsubscribe(TDialogStartedEvent2D, @OnDS);
   World.EventBus.Unsubscribe(TDialogEndedEvent2D, @OnDE);
   World.ShutdownSystems;
   World.DestroyAllEntities;
   InputManager.RemoveMap('DlgDemo');
end;

procedure TDialogDemoScene.Update(ADelta: single);
var
   D: TDialogComponent2D;
   N: PDialogNode2D;
   Tr: TTransformComponent;
   Spd: single;
begin
   if IsKeyPressed(KEY_BACKSPACE) and not DCmp.Active then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   D := DCmp;
   if D.Active then
   begin
      N := D.GetCurrentNode;
      if Assigned(N) and (N^.ChoiceCount > 0) then
      begin
         if IsKeyPressed(KEY_UP) then
            FCurChoice := (FCurChoice - 1 + N^.ChoiceCount) mod N^.ChoiceCount;
         if IsKeyPressed(KEY_DOWN) then
            FCurChoice := (FCurChoice + 1) mod N^.ChoiceCount;
         if IsKeyPressed(KEY_ONE) and (N^.ChoiceCount >= 1) then
         begin
            D.AdvanceDialog(0);
            FCurChoice := 0;
         end;
         if IsKeyPressed(KEY_TWO) and (N^.ChoiceCount >= 2) then
         begin
            D.AdvanceDialog(1);
            FCurChoice := 0;
         end;
         if IsKeyPressed(KEY_ENTER) then
         begin
            D.AdvanceDialog(FCurChoice);
            FCurChoice := 0;
         end;
      end
      else
      if IsKeyPressed(KEY_ENTER) or IsKeyPressed(KEY_E) then
      begin
         D.AdvanceDialog;
         FCurChoice := 0;
      end;
   end;
   if not D.Active then
   begin
      Tr := TTransformComponent(FPlayer.GetComponentByID(FTRID));
      Spd := 150 * ADelta;
      if IsKeyDown(KEY_W) then
         Tr.Position.Y := Tr.Position.Y - Spd;
      if IsKeyDown(KEY_S) then
         Tr.Position.Y := Tr.Position.Y + Spd;
      if IsKeyDown(KEY_A) then
         Tr.Position.X := Tr.Position.X - Spd;
      if IsKeyDown(KEY_D) then
         Tr.Position.X := Tr.Position.X + Spd;
   end;
   World.Update(ADelta);
end;

procedure TDialogDemoScene.Render;
var
   D: TDialogComponent2D;
   N: PDialogNode2D;
   I: integer;
   Tr, NTr: TTransformComponent;
   DX, DY, Dist: single;
   BX, BY, BW, BH: integer;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 8 - Dialog Tree System (TDialogComponent2D)');
   DrawFooter('WASD=move   E=interact   UP/DOWN=choice   ENTER or 1-2=confirm');
   DrawRectangle(0, SCR_H - FOOTER_H - 80, SCR_W, 80, ColorCreate(50, 40, 30, 255));
   Tr := TTransformComponent(FPlayer.GetComponentByID(FTRID));
   DrawRectangle(Round(Tr.Position.X) - 12, Round(Tr.Position.Y) - 24, 24, 24, COL_ACCENT);
   DrawText('YOU', Round(Tr.Position.X) - 12, Round(Tr.Position.Y), 11, COL_TEXT);
   NTr := TTransformComponent(FNpc.GetComponentByID(FTRID));
   DrawRectangle(Round(NTr.Position.X) - 14, Round(NTr.Position.Y) - 24, 28, 24, COL_GOOD);
   DrawText('ELDER', Round(NTr.Position.X) - 18, Round(NTr.Position.Y), 11, COL_TEXT);
   DrawCircleLines(Round(NTr.Position.X), Round(NTr.Position.Y), 110, ColorCreate(100, 200, 100, 40));
   D := DCmp;
   DX := Tr.Position.X - NTr.Position.X;
   DY := Tr.Position.Y - NTr.Position.Y;
   Dist := Sqrt(DX * DX + DY * DY);
   if (Dist <= 110) and not D.Active then
      DrawText('[E] Speak', Round(NTr.Position.X) - 32, Round(NTr.Position.Y) - 46, 12, COL_WARN);
   if D.Active then
   begin
      N := D.GetCurrentNode;
      if Assigned(N) then
      begin
         BX := 40;
         BY := SCR_H - FOOTER_H - 210;
         BW := SCR_W - 80;
         BH := 190;
         DrawRectangle(BX, BY, BW, BH, ColorCreate(10, 10, 20, 230));
         DrawRectangleLinesEx(RectangleCreate(BX, BY, BW, BH), 2, COL_ACCENT);
         DrawText(PChar(N^.Speaker + ':'), BX + 12, BY + 10, 13, COL_WARN);
         DrawText(PChar(N^.Text), BX + 12, BY + 30, 12, COL_TEXT);
         if N^.ChoiceCount > 0 then
            for I := 0 to N^.ChoiceCount - 1 do
               if I = FCurChoice then
                  DrawText(PChar('> ' + N^.Choices[I].Text), BX + 12, BY + 90 + I * 30, 13, COL_ACCENT)
               else
                  DrawText(PChar('  ' + N^.Choices[I].Text), BX + 12, BY + 90 + I * 30, 13, COL_DIMTEXT)
         else
            DrawText('[ENTER] Continue', BX + BW - 180, BY + BH - 22, 12, COL_DIMTEXT);
      end;
   end;
end;

end.
