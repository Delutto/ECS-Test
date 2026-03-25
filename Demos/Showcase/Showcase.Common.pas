unit Showcase.Common;

{$mode objfpc}{$H+}

interface

uses
   raylib;

const
   SCR_W = 1024;
   SCR_H = 768;
   HEADER_H = 44;
   FOOTER_H = 56;
   DEMO_AREA_Y = HEADER_H;
   DEMO_AREA_H = SCR_H - HEADER_H - FOOTER_H;
   DEMO_AREA_CX = SCR_W div 2;
   DEMO_AREA_CY = DEMO_AREA_Y + DEMO_AREA_H div 2;
   COL_BG: TColor = (R: 30; G: 30; B: 40; A: 255);
   COL_HEADER: TColor = (R: 20; G: 20; B: 30; A: 255);
   COL_FOOTER: TColor = (R: 20; G: 20; B: 30; A: 255);
   COL_TEXT: TColor = (R: 220; G: 220; B: 220; A: 255);
   COL_ACCENT: TColor = (R: 80; G: 180; B: 255; A: 255);
   COL_GOOD: TColor = (R: 80; G: 220; B: 100; A: 255);
   COL_WARN: TColor = (R: 255; G: 200; B: 60; A: 255);
   COL_BAD: TColor = (R: 255; G: 80; B: 80; A: 255);
   COL_DIMTEXT: TColor = (R: 140; G: 140; B: 150; A: 255);

procedure DrawHeader(const T: string);
procedure DrawFooter(const T: string);
procedure DrawPanel(AX, AY, AW, AH: integer; const ATitle: string = '');

implementation

procedure DrawHeader(const T: string);
begin
   DrawRectangle(0, 0, SCR_W, HEADER_H, COL_HEADER);
   DrawLine(0, HEADER_H - 1, SCR_W, HEADER_H - 1, COL_ACCENT);
   DrawText(PChar(T), 14, 12, 17, COL_ACCENT);
   DrawText('BACKSPACE = Menu', SCR_W - 210, 14, 13, COL_DIMTEXT);
end;

procedure DrawFooter(const T: string);
begin
   DrawRectangle(0, SCR_H - FOOTER_H, SCR_W, FOOTER_H, COL_FOOTER);
   DrawLine(0, SCR_H - FOOTER_H, SCR_W, SCR_H - FOOTER_H, COL_ACCENT);
   DrawText(PChar(T), 14, SCR_H - FOOTER_H + 10, 13, COL_DIMTEXT);
end;

procedure DrawPanel(AX, AY, AW, AH: integer; const ATitle: string);
begin
   DrawRectangle(AX, AY, AW, AH, ColorCreate(40, 40, 55, 230));
   DrawRectangleLinesEx(RectangleCreate(AX, AY, AW, AH), 2, COL_ACCENT);
   if ATitle <> '' then
   begin
      DrawRectangle(AX + 2, AY + 2, AW - 4, 22, ColorCreate(50, 50, 70, 240));
      DrawText(PChar(ATitle), AX + 8, AY + 6, 13, COL_TEXT);
   end;
end;

end.
