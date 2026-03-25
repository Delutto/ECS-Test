unit Showcase.Scene.Text;

{$mode objfpc}{$H+}

{ Demo 21 - Text Rendering (TTextComponent2D + TTextSystem2D)
  Two TTextSystem2D instances with different RenderLayers:
    rlWorld  -> inside BeginMode2D (moves with world/camera)
    rlScreen -> after EndMode2D   (fixed HUD position)
  TTextSystem2D uses TResourceManager2D.LoadFont(FontKey, size).
  Empty FontKey -> GetFontDefault(). Supports shadow (1 px offset),
  horizontal alignment (taLeft/taCenter/taRight) and ZOrder.
  Controls: Arrows=move  1/2/3=align  S=shadow  +/-=size  T=tint }
interface

uses
   SysUtils, StrUtils, Math, raylib,
   P2D.Utils.RayLib,
   P2D.Core.Scene, P2D.Core.World, P2D.Core.Entity, P2D.Core.ComponentRegistry, P2D.Core.Types,
   P2D.Components.Transform, P2D.Components.Text,
   P2D.Systems.Text,
   Showcase.Common;

type
   TTextDemoScene = class(TScene2D)
   private
      FScreenW, FScreenH: Integer;
      FWorldLabel, FScreenLabel: TEntity;
      FWorldTextSys, FScreenTextSys: TTextSystem2D;
      FTRID, FTXTID: Integer;
      FColorIdx: Integer;
      function WLText: TTextComponent2D;
      function WLTr: TTransformComponent;
   protected
      procedure DoLoad; override;
      procedure DoEnter; override;
      procedure DoExit; override;
   public
      constructor Create(AW, AH: Integer);
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

implementation

uses
   P2D.Core.System,
   P2D.Systems.SceneManager;

const
   TEXT_COLS: array[0..4] of TColor = (
      (R: 255; G: 255; B: 255; A: 255), (R: 255; G: 220; B: 60; A: 255), (R: 80; G: 220; B: 100; A: 255),
      (R: 80; G: 160; B: 255; A: 255), (R: 255; G: 100; B: 200; A: 255));

constructor TTextDemoScene.Create(AW, AH: Integer);
begin
   inherited Create('Text');
   FScreenW := AW;
   FScreenH := AH;
   FColorIdx := 0;
end;

function TTextDemoScene.WLText: TTextComponent2D;
begin
   Result := TTextComponent2D(FWorldLabel.GetComponentByID(FTXTID));
end;

function TTextDemoScene.WLTr: TTransformComponent;
begin
   Result := TTransformComponent(FWorldLabel.GetComponentByID(FTRID));
end;

procedure TTextDemoScene.DoLoad;
begin
   FWorldTextSys := TTextSystem2D(World.AddSystem(TTextSystem2D.Create(World)));
   FWorldTextSys.RenderLayer := rlWorld;
   FScreenTextSys := TTextSystem2D(World.AddSystem(TTextSystem2D.Create(World)));
   FScreenTextSys.RenderLayer := rlScreen;
end;

procedure TTextDemoScene.DoEnter;
var
   Tr: TTransformComponent;
   Txt: TTextComponent2D;
begin
   FColorIdx := 0;
   FTRID := ComponentRegistry.GetComponentID(TTransformComponent);
   FTXTID := ComponentRegistry.GetComponentID(TTextComponent2D);
   FWorldLabel := World.CreateEntity('WorldLabel');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(DEMO_AREA_CX, DEMO_AREA_CY);
   FWorldLabel.AddComponent(Tr);
   Txt := TTextComponent2D.Create;
   Txt.Text := 'World Space Label';
   Txt.FontKey := '';
   Txt.FontSize := 24;
   Txt.Spacing := 1.5;
   Txt.Color := WHITE;
   Txt.Alignment := taCenter;
   Txt.ZOrder := 10;
   Txt.Shadow := True;
   Txt.ShadowColor := ColorCreate(0, 0, 0, 180);
   FWorldLabel.AddComponent(Txt);
   FScreenLabel := World.CreateEntity('ScreenLabel');
   Tr := TTransformComponent.Create;
   Tr.Position := Vector2Create(SCR_W div 2, SCR_H - FOOTER_H - 40);
   FScreenLabel.AddComponent(Tr);
   Txt := TTextComponent2D.Create;
   Txt.Text := 'Screen Space (fixed HUD)';
   Txt.FontSize := 14;
   Txt.Color := ColorCreate(255, 200, 60, 255);
   Txt.Alignment := taCenter;
   Txt.ZOrder := 200;
   Txt.Shadow := False;
   FScreenLabel.AddComponent(Txt);
   World.Init;
end;

procedure TTextDemoScene.DoExit;
begin
   World.ShutdownSystems;
   World.DestroyAllEntities;
end;

procedure TTextDemoScene.Update(ADelta: Single);
var
   Tr: TTransformComponent;
   Txt: TTextComponent2D;
   Spd: Single;
begin
   if IsKeyPressed(KEY_BACKSPACE) then
   begin
      SceneManager.ChangeScene('Menu');
      Exit;
   end;
   Tr := WLTr;
   Txt := WLText;
   Spd := 150 * ADelta;
   if IsKeyDown(KEY_LEFT) then
      Tr.Position.X := Tr.Position.X - Spd;
   if IsKeyDown(KEY_RIGHT) then
      Tr.Position.X := Tr.Position.X + Spd;
   if IsKeyDown(KEY_UP) then
      Tr.Position.Y := Tr.Position.Y - Spd;
   if IsKeyDown(KEY_DOWN) then
      Tr.Position.Y := Tr.Position.Y + Spd;
   if IsKeyPressed(KEY_ONE) then
      Txt.Alignment := taLeft;
   if IsKeyPressed(KEY_TWO) then
      Txt.Alignment := taCenter;
   if IsKeyPressed(KEY_THREE) then
      Txt.Alignment := taRight;
   if IsKeyPressed(KEY_S) then
      Txt.Shadow := not Txt.Shadow;
   if IsKeyPressed(KEY_EQUAL) then
      Txt.FontSize := Min(48, Txt.FontSize + 2);
   if IsKeyPressed(KEY_MINUS) then
      Txt.FontSize := Max(10, Txt.FontSize - 2);
   if IsKeyPressed(KEY_T) then
   begin
      FColorIdx := (FColorIdx + 1) mod 5;
      Txt.Color := TEXT_COLS[FColorIdx];
   end;
   World.Update(ADelta);
end;

procedure TTextDemoScene.Render;
var
   Txt: TTextComponent2D;
   Tr: TTransformComponent;
   ALN: String;
begin
   ClearBackground(COL_BG);
   World.RenderByLayer(rlWorld);    { includes world-space text system }
   World.RenderByLayer(rlScreen);   { includes screen-space text system }
   DrawHeader('Demo 21 - Text Rendering (TTextComponent2D + TTextSystem2D)');
   DrawFooter('Arrows=move  1/2/3=align  S=shadow  +/-=size  T=colour');
   Txt := WLText;
   Tr := WLTr;
   case Txt.Alignment of
      taLeft:
         ALN := 'LEFT';
      taCenter:
         ALN := 'CENTER';
      taRight:
         ALN := 'RIGHT';
   end;
   DrawPanel(30, DEMO_AREA_Y + 10, 310, 280, 'TTextComponent2D Properties');
   DrawText(PChar('Text      : "' + Txt.Text + '"'), 42, DEMO_AREA_Y + 34, 11, COL_TEXT);
   DrawText(PChar('FontKey   : "' + (IfThen(Txt.FontKey = '', '(default)', Txt.FontKey)) + '"'), 42, DEMO_AREA_Y + 52, 11, COL_DIMTEXT);
   DrawText(PChar(Format('FontSize  : %.0f', [Txt.FontSize])), 42, DEMO_AREA_Y + 70, 11, COL_TEXT);
   DrawText(PChar(Format('Spacing   : %.1f', [Txt.Spacing])), 42, DEMO_AREA_Y + 88, 11, COL_TEXT);
   DrawText(PChar('Alignment : ' + ALN), 42, DEMO_AREA_Y + 106, 11, COL_TEXT);
   DrawText(PChar('Shadow    : ' + IfThen(Txt.Shadow, 'TRUE', 'FALSE')), 42, DEMO_AREA_Y + 124, 11, IfThen(Txt.Shadow, COL_GOOD, COL_DIMTEXT));
   DrawText(PChar(Format('ZOrder    : %d', [Txt.ZOrder])), 42, DEMO_AREA_Y + 142, 11, COL_TEXT);
   DrawText(PChar(Format('Position  : (%.0f,%.0f)', [Tr.Position.X, Tr.Position.Y])), 42, DEMO_AREA_Y + 160, 11, COL_DIMTEXT);
   DrawPanel(30, DEMO_AREA_Y + 300, 310, 100, 'Render Layers');
   DrawText('rlWorld  : inside BeginMode2D', 42, DEMO_AREA_Y + 324, 11, COL_GOOD);
   DrawText('rlScreen : after EndMode2D (HUD)', 42, DEMO_AREA_Y + 348, 11, COL_WARN);
   DrawCircle(Round(Tr.Position.X), Round(Tr.Position.Y), 4, COL_BAD);
end;

end.
