unit P2D.Utils.Debug;

{$mode ObjFPC}{$H+}

interface

uses
   Classes,
   SysUtils,
   raylib,
   P2D.Core.Types;

type
   { TDebugDraw }
   TDebugDraw = class
   private
      FEnabled: Boolean;
      FShowColliders: Boolean;
      FShowGrid: Boolean;
      FShowFPS: Boolean;
      FShowEntityCount: Boolean;
      FGridSize: Integer;
      FGridColor: TColor;
      class var FInstance: TDebugDraw;
   public
      constructor Create;
      class function Instance: TDebugDraw;
      class procedure FreeInstance;

      procedure DrawRect(const ARect: TRectangle; AColor: TColor);
      procedure DrawCircle(const APosition: TVector2; ARadius: Single; AColor: TColor);
      procedure DrawLine(const AStart, AEnd: TVector2; AColor: TColor);
      procedure DrawText(const AText: String; const APosition: TVector2; AFontSize: Integer; AColor: TColor);
      procedure DrawGrid(const ACameraTarget: TVector2);
      procedure DrawCross(const APosition: TVector2; ASize: Single; AColor: TColor);

      property Enabled: Boolean read FEnabled write FEnabled;
      property ShowColliders: Boolean read FShowColliders write FShowColliders;
      property ShowGrid: Boolean read FShowGrid write FShowGrid;
      property ShowFPS: Boolean read FShowFPS write FShowFPS;
      property ShowEntityCount: boolean read FShowEntityCount write FShowEntityCount;
      property GridSize: Integer read FGridSize write FGridSize;
      property GridColor: TColor read FGridColor write FGridColor;
   end;

implementation

{ TDebugDraw }

constructor TDebugDraw.Create;
begin
   inherited Create;

   FEnabled := True;
   FShowColliders := False;
   FShowGrid := False;
   FShowFPS := True;
   FShowEntityCount := False;
   FGridSize := 32;
   FGridColor := ColorCreate(255, 255, 255, 50);
end;

class function TDebugDraw.Instance: TDebugDraw;
begin
   if FInstance = nil then
   begin
      FInstance := TDebugDraw.Create;
   end;
   Result := FInstance;
end;

class procedure TDebugDraw.FreeInstance;
begin
   FreeAndNil(FInstance);
end;

procedure TDebugDraw.DrawRect(const ARect: TRectangle; AColor: TColor);
begin
   if not FEnabled then
   begin
      Exit;
   end;
   DrawRectangleLinesEx(ARect, 1, AColor);
end;

procedure TDebugDraw.DrawCircle(const APosition: TVector2; ARadius: Single; AColor: TColor);
begin
   if not FEnabled then
   begin
      Exit;
   end;
   DrawCircleLines(Trunc(APosition.X), Trunc(APosition.Y), ARadius, AColor);
end;

procedure TDebugDraw.DrawLine(const AStart, AEnd: TVector2; AColor: TColor);
begin
   if not FEnabled then
   begin
      Exit;
   end;
   raylib.DrawLineV(AStart, AEnd, AColor);
end;

procedure TDebugDraw.DrawText(const AText: String; const APosition: TVector2; AFontSize: Integer; AColor: TColor);
begin
   if not FEnabled then
   begin
      Exit;
   end;
   raylib.DrawText(PChar(AText), Trunc(APosition.X), Trunc(APosition.Y), AFontSize, AColor);
end;

procedure TDebugDraw.DrawGrid(const ACameraTarget: TVector2);
var
   ScreenWidth, ScreenHeight: Integer;
   StartX, StartY, EndX, EndY: Integer;
   X, Y: Integer;
begin
   if not FEnabled or not FShowGrid then
   begin
      Exit;
   end;

   ScreenWidth := GetScreenWidth;
   ScreenHeight := GetScreenHeight;

   StartX := (Trunc(ACameraTarget.X) div FGridSize - 1) * FGridSize;
   StartY := (Trunc(ACameraTarget.Y) div FGridSize - 1) * FGridSize;
   EndX := StartX + ScreenWidth + FGridSize * 2;
   EndY := StartY + ScreenHeight + FGridSize * 2;

   // Vertical lines
   X := StartX;
   while X <= EndX do
   begin
      DrawLine(Vector2Create(X, StartY), Vector2Create(X, EndY), FGridColor);
      X := X + FGridSize;
   end;

   // Horizontal lines
   Y := StartY;
   while Y <= EndY do
   begin
      DrawLine(Vector2Create(StartX, Y), Vector2Create(EndX, Y), FGridColor);
      Y := Y + FGridSize;
   end;
end;

procedure TDebugDraw.DrawCross(const APosition: TVector2; ASize: Single; AColor: TColor);
var
   HalfSize: Single;
begin
   if not FEnabled then
   begin
      Exit;
   end;

   HalfSize := ASize / 2;

   DrawLine(Vector2Create(APosition.X - HalfSize, APosition.Y), Vector2Create(APosition.X + HalfSize, APosition.Y), AColor);

   DrawLine(Vector2Create(APosition.X, APosition.Y - HalfSize), Vector2Create(APosition.X, APosition.Y + HalfSize), AColor);
end;

initialization

finalization
   TDebugDraw.FreeInstance;

end.
