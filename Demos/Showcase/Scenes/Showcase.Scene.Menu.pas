unit Showcase.Scene.Menu;

{$mode objfpc}{$H+}

{ P2DGE Showcase - Main Menu
  Scrollable list of all 26 feature demos.
  UP/DOWN or mouse wheel scrolls. ENTER opens selected demo. }
interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Scene, P2D.Core.World, Showcase.Common;

const
   TOTAL_DEMOS = 26;
   VISIBLE_ROWS = 13;

type
   TMenuScene = class(TScene2D)
   private
      FScreenW, FScreenH, FSel, FScroll: Integer;
      FLabels: array[0..TOTAL_DEMOS - 1] of String;
      FScenes: array[0..TOTAL_DEMOS - 1] of String;
      procedure ScrollTo(AIdx: Integer);
   protected
      procedure DoEnter; override;
   public
      constructor Create(AW, AH: Integer);
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Systems.SceneManager;

constructor TMenuScene.Create(AW, AH: Integer);
begin
   inherited Create('Menu');
   FScreenW := AW;
   FScreenH := AH;
   FSel := 0;
   FScroll := 0;
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
   FLabels[6] := ' 7  Day and Night Cycle';
   FScenes[6] := 'DayNight';
   FLabels[7] := ' 8  Dialog Tree System';
   FScenes[7] := 'Dialog';
   FLabels[8] := ' 9  A-Star Pathfinding';
   FScenes[8] := 'Pathfinding';
   FLabels[9] := '10  Infinite Chunk System';
   FScenes[9] := 'Chunk';
   FLabels[10] := '11  Entity Builder (fluent API)';
   FScenes[10] := 'Builder';
   FLabels[11] := '12  Sprite Rendering and Z-Order';
   FScenes[11] := 'Sprite';
   FLabels[12] := '13  Animation System';
   FScenes[12] := 'Animation';
   FLabels[13] := '14  Physics and Collision';
   FScenes[13] := 'Physics';
   FLabels[14] := '15  Camera System';
   FScenes[14] := 'Camera';
   FLabels[15] := '16  Parallax Backgrounds';
   FScenes[15] := 'Parallax';
   FLabels[16] := '17  Particle Emitter';
   FScenes[16] := 'Particles';
   FLabels[17] := '18  Finite State Machine';
   FScenes[17] := 'StateMachine';
   FLabels[18] := '19  Timer Component';
   FScenes[18] := 'Timer';
   FLabels[19] := '20  Tween and Easing';
   FScenes[19] := 'Tween';
   FLabels[20] := '21  Text Rendering';
   FScenes[20] := 'Text';
   FLabels[21] := '22  Input Action Maps';
   FScenes[21] := 'Input';
   FLabels[22] := '23  Audio System';
   FScenes[22] := 'Audio';
   FLabels[23] := '24  Event Bus';
   FScenes[23] := 'EventBus';
   FLabels[24] := '25  Resource Manager';
   FScenes[24] := 'ResourceManager';
   FLabels[25] := '26  Debug and Utilities';
   FScenes[25] := 'Debug';
end;

procedure TMenuScene.ScrollTo(AIdx: Integer);
begin
   if AIdx < FScroll then
      FScroll := AIdx
   else
   if AIdx >= FScroll + VISIBLE_ROWS then
      FScroll := AIdx - VISIBLE_ROWS + 1;
   if FScroll < 0 then
      FScroll := 0;
   if FScroll > TOTAL_DEMOS - VISIBLE_ROWS then
      FScroll := TOTAL_DEMOS - VISIBLE_ROWS;
   FSel := AIdx;
end;

procedure TMenuScene.DoEnter;
begin
   FSel := 0;
   FScroll := 0;
end;

procedure TMenuScene.Update(ADelta: Single);
var
   I: Integer;
   W: Single;
begin
   if IsKeyPressed(KEY_UP) then
      ScrollTo(Max(0, FSel - 1));
   if IsKeyPressed(KEY_DOWN) then
      ScrollTo(Min(TOTAL_DEMOS - 1, FSel + 1));
   W := GetMouseWheelMove;
   if W > 0 then
      ScrollTo(Max(0, FSel - 1));
   if W < 0 then
      ScrollTo(Min(TOTAL_DEMOS - 1, FSel + 1));
   for I := 0 to 8 do
      if IsKeyPressed(KEY_ZERO + I + 1) then
         ScrollTo(I);
   if IsKeyPressed(KEY_ENTER) or IsKeyPressed(KEY_SPACE) then
      SceneManager.ChangeScene(FScenes[FSel]);
   World.Update(ADelta);
end;

procedure TMenuScene.Render;
const
   IH = 42;
   TY = DEMO_AREA_Y + 32;
var
   I, ScreenI, Entry: Integer;
   C: TColor;
begin
   ClearBackground(COL_BG);
   DrawHeader('Pascal 2D Game Engine Showcase');
   DrawFooter('UP/DOWN or Wheel=scroll   1-9=jump   ENTER=open demo');
   DrawText('Engine Feature Demos (26 total):', 30, TY - 22, 13, COL_DIMTEXT);
   for ScreenI := 0 to VISIBLE_ROWS - 1 do
   begin
      Entry := FScroll + ScreenI;
      if Entry >= TOTAL_DEMOS then
         Break;
      if Entry = FSel then
      begin
         DrawRectangle(28, TY + ScreenI * IH, SCR_W - 56, IH - 3, ColorCreate(80, 140, 220, 50));
         DrawRectangleLinesEx(RectangleCreate(28, TY + ScreenI * IH, SCR_W - 56, IH - 3), 2, COL_ACCENT);
         C := COL_ACCENT;
      end
      else
         if Entry < 11 then
            C := COL_TEXT
         else
            C := ColorCreate(180, 230, 255, 255);
      DrawText(PChar(FLabels[Entry]), 42, TY + ScreenI * IH + 12, 15, C);
   end;
   if TOTAL_DEMOS > VISIBLE_ROWS then
   begin
      DrawText(PChar(Format('[%d/%d]', [FSel + 1, TOTAL_DEMOS])), SCR_W - 80, TY - 22, 13, COL_DIMTEXT);
      DrawRectangle(SCR_W - 22, TY, 6, VISIBLE_ROWS * IH, ColorCreate(40, 40, 60, 255));
      DrawRectangle(SCR_W - 22, TY + Round(FScroll / (TOTAL_DEMOS - VISIBLE_ROWS) * (VISIBLE_ROWS * IH - 30)),
         6, 30, COL_ACCENT);
   end;
   { Separator between original (1-11) and new (12-26) demos }
   DrawLine(28, TY + 11 * IH - 4, SCR_W - 28, TY + 11 * IH - 4, ColorCreate(80, 80, 100, 140));
end;

function IfThen(B: boolean; const T, F: TColor): TColor;
begin
   if B then
      Result := T
   else
      Result := F;
end;

end.
