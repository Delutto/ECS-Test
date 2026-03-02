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
    constructor Create(AWidth, AHeight: Integer; const ATitle: string; AFPS: Integer = 60);
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
const
  FIXED_DT  = 1.0 / 60.0; // passo físico fixo
  MAX_DELTA = 0.25;       // cap para evitar "spiral of death"
var
  Delta, Accumulator, Alpha: Single;
begin
  InitWindow(FScreenW, FScreenH, PChar(FTitle));
  if not IsWindowReady then
    raise Exception.Create('TEngine2D: Falha ao inicializar janela raylib.');
  SetTargetFPS(FTargetFPS);
  InitAudioDevice;
  if not IsAudioDeviceReady then
    raise Exception.Create('TEngine2D: Falha ao inicializar áudio raylib.');

   try
      FWorld.Init;
      FRunning  := True;
      Accumulator := 0.0;

      while FRunning and not WindowShouldClose do
      begin
         // Clamp para evitar explosão de física em lag spikes
         Delta := Min(GetFrameTime, MAX_DELTA);
         Accumulator := Accumulator + Delta;

         // Passos físicos fixos
         while Accumulator >= FIXED_DT do
         begin
            FWorld.FixedUpdate(FIXED_DT); // física determinística
            Accumulator := Accumulator - FIXED_DT;
         end;

         // Alpha para interpolação visual (opcional)
         Alpha := Accumulator / FIXED_DT;
         FWorld.Update(Delta); // lógica de jogo (input, animação, câmera)

         BeginDrawing;
         ClearBackground(GetColor($5C94FCFF));
         FWorld.Render;
         EndDrawing;
      end;
   except on E: Exception do
   begin
      TraceLog(LOG_ERROR, PChar('Erro fatal: ' + E.Message));
      raise;
   end;
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
