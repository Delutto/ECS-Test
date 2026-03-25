unit Showcase.Scene.Tag;

{$mode objfpc}{$H+}

{ Demo 2 - Tag Component
  Type a tag name then ENTER to highlight matching entities.
  TAB cycles selection. ESC clears filter. }
interface

uses
   SysUtils, raylib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity,
   P2D.Core.ComponentRegistry, P2D.Components.Tag, Showcase.Common;

const
   MAX_TAG_ENT = 6;

type
   TTagDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH, FSel: integer;
      FEntities: array[0..MAX_TAG_ENT - 1] of TEntity;
      FFilter, FTyping: string;
      FMatch: array[0..MAX_TAG_ENT - 1] of boolean;
      procedure BuildEntities;
      procedure ApplyFilter;
      function TC(I: integer): TTagComponent2D;
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

constructor TTagDemoScene.Create(AW, AH: integer);
begin
   inherited Create('Tag');

   FScreenW := AW;
   FScreenH := AH;
end;

function TTagDemoScene.TC(I: integer): TTagComponent2D;
begin
   Result := TTagComponent2D(FEntities[I].GetComponentByID(ComponentRegistry.GetComponentID(TTagComponent2D)));
end;

procedure TTagDemoScene.BuildEntities;
const
   N: array[0..5] of string = ('Goblin', 'Dragon', 'Wizard', 'Slime', 'Knight', 'Merchant');
   TS: array[0..5] of string = ('enemy damageable movable', 'enemy damageable boss flying', 'player damageable movable magic',
      'enemy damageable movable small', 'player damageable movable armored', 'npc friendly shop');
var
   I, J: integer;
   E: TEntity;
   T: TTagComponent2D;
   P: TStringArray;
begin
   for I := 0 to MAX_TAG_ENT - 1 do
   begin
      E := World.CreateEntity(N[I]);
      T := TTagComponent2D.Create;
      P := TS[I].Split(' ');
      for J := 0 to Length(P) - 1 do
         T.AddTag(P[J]);
      E.AddComponent(T);
      FEntities[I] := E;
      FMatch[I] := True;
   end;
end;

procedure TTagDemoScene.ApplyFilter;
var
   I: integer;
   T: TTagComponent2D;
begin
   for I := 0 to MAX_TAG_ENT - 1 do
      if FFilter = '' then
         FMatch[I] := True
      else
      begin
         T := TC(I);
         FMatch[I] := Assigned(T) and T.HasTag(FFilter);
      end;
end;

procedure TTagDemoScene.DoLoad;
begin
end;

procedure TTagDemoScene.DoEnter;
begin
   FSel := 0;
   FFilter := '';
   FTyping := '';
   BuildEntities;
   World.Init;
   ApplyFilter;
end;

procedure TTagDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TTagDemoScene.Update(ADelta: single);
var
   K: integer;
   C: char;
begin
   if IsKeyPressed(KEY_BACKSPACE) and (FTyping = '') then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   if IsKeyPressed(KEY_TAB) then
      FSel := (FSel + 1) mod MAX_TAG_ENT;
   if IsKeyPressed(KEY_BACKSPACE) and (Length(FTyping) > 0) then
      FTyping := Copy(FTyping, 1, Length(FTyping) - 1);
   for K := KEY_A to KEY_Z do
      if IsKeyPressed(K) then
      begin
         C := Chr(Ord('a') + (K - KEY_A));
         FTyping := FTyping + C;
      end;
   if IsKeyPressed(KEY_ENTER) then
   begin
      FFilter := FTyping;
      FTyping := '';
      ApplyFilter;
   end;
   if IsKeyPressed(KEY_ESCAPE) then
   begin
      FFilter := '';
      FTyping := '';
      ApplyFilter;
   end;
   World.Update(ADelta);
end;

procedure TTagDemoScene.Render;
const
   CW = 150;
   CH = 120;
   PX = 40;
   PY = DEMO_AREA_Y + 30;
   GAP = 8;
var
   I, X, Y, T: integer;
   T2: TTagComponent2D;
   BC: TColor;
begin
   ClearBackground(COL_BG);
   DrawHeader('Demo 2 - Tag Component (TTagComponent2D)');
   DrawFooter('Type tag + ENTER=filter   ESC=clear   TAB=select');
   for I := 0 to MAX_TAG_ENT - 1 do
   begin
      X := PX + (I mod 3) * (CW + GAP);
      Y := PY + (I div 3) * (CH + GAP);
      if FMatch[I] then
         BC := COL_ACCENT
      else
         BC := COL_DIMTEXT;
      if I = FSel then
         DrawRectangleLinesEx(RectangleCreate(X - 3, Y - 3, CW + 6, CH + 6), 3, COL_ACCENT);
      DrawRectangle(X, Y, CW, CH, ColorCreate(40, 40, 55, 220));
      DrawRectangleLinesEx(RectangleCreate(X, Y, CW, CH), 2, BC);
      DrawText(PChar(FEntities[I].Name), X + 6, Y + 6, 13, COL_TEXT);
      T2 := TC(I);
      if Assigned(T2) then
         for T := 0 to T2.Count - 1 do
            if (FFilter <> '') and SameText(T2.GetTag(T), FFilter) then
               DrawText(PChar(T2.GetTag(T)), X + 6, Y + 26 + T * 16, 11, COL_GOOD)
            else
               DrawText(PChar(T2.GetTag(T)), X + 6, Y + 26 + T * 16, 11, COL_DIMTEXT);
      if not FMatch[I] and (FFilter <> '') then
         DrawText('no match', X + 6, Y + CH - 18, 11, COL_BAD);
   end;
   DrawPanel(520, DEMO_AREA_Y + 30, 480, 120, 'Filter');
   DrawText('Active filter:', 530, DEMO_AREA_Y + 56, 13, COL_DIMTEXT);
   DrawText(PChar('"' + FFilter + '"'), 530, DEMO_AREA_Y + 74, 15, COL_WARN);
   DrawText(PChar('Typing: ' + FTyping + '_'), 530, DEMO_AREA_Y + 98, 13, COL_TEXT);
   DrawPanel(520, DEMO_AREA_Y + 160, 480, 180, 'Selected');
   T2 := TC(FSel);
   DrawText(PChar('Entity: ' + FEntities[FSel].Name), 530, DEMO_AREA_Y + 186, 14, COL_TEXT);
   if Assigned(T2) then
      for T := 0 to T2.Count - 1 do
         DrawText(PChar('  + ' + T2.GetTag(T)), 530, DEMO_AREA_Y + 206 + T * 18, 12, COL_GOOD);
end;

end.
