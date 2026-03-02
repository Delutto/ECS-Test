unit P2D.Core.Engine;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, raylib, P2D.Core.Types, P2D.Core.World;

type
  // -------------------------------------------------------------------------
  // TEngine2D – initialises raylib and drives the main loop
  // -------------------------------------------------------------------------
  TEngine2D = class
  private
    FWorld      : TWorld;
    FTitle      : string;
    FScreenW    : Integer;
    FScreenH    : Integer;
    FTargetFPS  : Integer;
    FRunning    : Boolean;
  public
    constructor Create(AWidth, AHeight: Integer;
                       const ATitle: string; AFPS: Integer = 60);
    destructor  Destroy; override;

    procedure Run;
    procedure Quit;

    property World    : TWorld  read FWorld;
    property ScreenW  : Integer read FScreenW;
    property ScreenH  : Integer read FScreenH;
    property Running  : Boolean read FRunning;
  end;

implementation

constructor TEngine2D.Create(AWidth, AHeight: Integer;
                              const ATitle: string; AFPS: Integer);
begin
  inherited Create;
  FScreenW   := AWidth;
  FScreenH   := AHeight;
  FTitle     := ATitle;
  FTargetFPS := AFPS;
  FWorld     := TWorld.Create;
  FRunning   := False;
end;

destructor TEngine2D.Destroy;
begin
  FWorld.Free;
  inherited;
end;

procedure TEngine2D.Run;
var Delta: Single;
begin
  InitWindow(FScreenW, FScreenH, PChar(FTitle));
  SetTargetFPS(FTargetFPS);
  InitAudioDevice;

  FWorld.Init;
  FRunning := True;

  while FRunning and not WindowShouldClose do
  begin
    Delta := GetFrameTime;

    FWorld.Update(Delta);

    BeginDrawing;
      ClearBackground(GetColor($5C94FCFF)); // Mario sky blue
      FWorld.Render;
    EndDrawing;
  end;

  FWorld.Shutdown;
  CloseAudioDevice;
  CloseWindow;
end;

procedure TEngine2D.Quit;
begin
  FRunning := False;
end;

end.