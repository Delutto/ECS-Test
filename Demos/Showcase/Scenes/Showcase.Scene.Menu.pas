unit Showcase.Scene.Menu;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, raylib, P2D.Core.Scene, P2D.Core.World, Showcase.Common;

type
   TMenuScene = class(TScene2D)
   private
      FScreenW, FScreenH, FSel: integer;
      FLabels: array[0..10] of string;
      FScenes: array[0..10] of string;
   protected
      procedure DoEnter; override;
   public
      constructor Create(AW, AH: integer);
      procedure Update(ADelta: single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Systems.SceneManager;

constructor TMenuScene.Create(AW, AH: integer);
begin
   inherited Create('Menu');

   FScreenW := AW;
   FScreenH := AH;

   FSel := 0;

   FLabels[0] := ' 1  Health and Damage System';
   FScenes[0] := 'Health';
   FLabels[1] := ' 2  Tag Component';
   FScenes[1] := 'Tag';
   FLabels[2] := ' 3  Inventory System';
   FScenes[2] := 'Inventory';
   FLabels[3] := ' 4  Projectile System';
   FScenes[3] := 'Projectile';
   FLabels[4] := ' 5  Interaction System';
   FScenes[4] := 'Interaction';
   FLabels[5] := ' 6  2D Lighting System';
   FScenes[5] := 'Lighting';
   FLabels[6] := ' 7  Day  Night Cycle';
   FScenes[6] := 'DayNight';
   FLabels[7] := ' 8  Dialog Tree System';
   FScenes[7] := 'Dialog';
   FLabels[8] := ' 9  A-Star Pathfinding System';
   FScenes[8] := 'Pathfinding';
   FLabels[9] := '10  Infinite Chunk System';
   FScenes[9] := 'Chunk';
   FLabels[10] := '11  Entity Builder fluent API';
   FScenes[10] := 'Builder';
end;

procedure TMenuScene.DoEnter;
begin
   FSel := 0;
end;

procedure TMenuScene.Update(ADelta: single);
var
   I: integer;
begin
   if IsKeyPressed(KEY_UP) then
      FSel := (FSel - 1 + 11) mod 11;
   if IsKeyPressed(KEY_DOWN) then
      FSel := (FSel + 1) mod 11;
   for I := 0 to 9 do
      if IsKeyPressed(KEY_ZERO + I + 1) then
         FSel := I;
   if IsKeyPressed(KEY_ENTER) or IsKeyPressed(KEY_SPACE) then
      SceneManager.ChangeScene(FScenes[FSel]);
   World.Update(ADelta);
end;

procedure TMenuScene.Render;
const
   IH = 38;
   TY = 120;
var
   I: integer;
   C: TColor;
begin
   ClearBackground(COL_BG);
   DrawHeader('P2DGE Showcase - Main Menu');
   DrawFooter('UP/DOWN or 1-11 = select     ENTER = Open Demo');
   DrawText('Choose a feature demo:', 30, TY - 28, 14, COL_DIMTEXT);
   for I := 0 to 10 do
   begin
      if I = FSel then
      begin
         DrawRectangle(28, TY + I * IH, SCR_W - 56, IH - 4, ColorCreate(80, 140, 220, 50));
         DrawRectangleLinesEx(RectangleCreate(28, TY + I * IH, SCR_W - 56, IH - 4), 2, COL_ACCENT);
         C := COL_ACCENT;
      end
      else
         C := COL_TEXT;
      DrawText(PChar(FLabels[I]), 42, TY + I * IH + 10, 15, C);
   end;
end;

end.
