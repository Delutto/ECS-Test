unit P2D.Core.Engine;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math, raylib,
   P2D.Core.InputManager, P2D.Core.Types, P2D.Core.World;

type
   { -------------------------------------------------------------------------
   TEngine2D — inicializa raylib e conduz o loop principal único.

   USO: Crie uma subclasse e sobrescreva os hooks virtuais:
   - OnInit     : carregue assets e crie entidades (janela já existe)
   - OnUpdate   : lógica extra por frame (ex: verificar restart)
   - OnRender   : toda a renderização (chamado entre BeginDrawing/EndDrawing)
   - OnShutdown : libere assets antes de fechar a janela

   O loop de acumulador (fixed timestep) roda inteiramente dentro de Run, que chama FWorld.FixedUpdate, FWorld.Update e os hooks na ordem correta.
   -------------------------------------------------------------------------}
   TEngine2D = class
   private
      FWorld    : TWorld;
      FTitle    : String;
      FScreenW  : Integer;
      FScreenH  : Integer;
      FTargetFPS: Integer;
      FRunning  : Boolean;
      FAlpha    : Single; // Fração do passo físico atual (0..1) para interpolação
   protected
    { Hooks virtuais — sobrescreva na subclasse do jogo concreto.
      Implementações padrão são no-ops seguros (exceto OnRender, que chama FWorld.Render como comportamento básico). }
      procedure OnInit; virtual;
      procedure OnUpdate(ADelta: Single); virtual;
      procedure OnRender; virtual;
      procedure OnShutdown; virtual;
   public
      constructor Create(AWidth, AHeight: Integer; const ATitle: string; AFPS: Integer = 60);
      destructor Destroy; override;

    { Inicia a janela, o áudio e o loop principal.
      Chama os hooks na ordem: OnInit → World.Init → loop → World.Shutdown → OnShutdown. }
      procedure Run;

    { Sinaliza o loop para encerrar no próximo frame. }
      procedure Quit;

      property World    : TWorld  read FWorld;
      property ScreenW  : Integer read FScreenW;
      property ScreenH  : Integer read FScreenH;
      property Running  : Boolean read FRunning;
    { Fração do passo físico pendente (0..1). Use em OnRender para interpolar posições visuais entre passos físicos (ver P2D.Components.Transform.PrevPosition). }
      property Alpha    : Single  read FAlpha;
   end;

implementation

{ TEngine2D }

constructor TEngine2D.Create(AWidth, AHeight: Integer; const ATitle: string; AFPS: Integer);
begin
   inherited Create;

   FScreenW   := AWidth;
   FScreenH   := AHeight;
   FTitle     := ATitle;
   FTargetFPS := AFPS;
   FWorld     := TWorld.Create;
   FRunning   := False;
   FAlpha     := 0.0;
end;

destructor TEngine2D.Destroy;
begin
   FWorld.Free;

   inherited;
end;

{ Hooks — implementações padrão vazias (safe no-ops) }
procedure TEngine2D.OnInit;
begin
   { Sobrescreva para: GenerateAssets, RegisterSystems, LoadLevel, etc. }
end;

procedure TEngine2D.OnUpdate(ADelta: Single);
begin
   { Sobrescreva para: checar restart, input de meta-jogo, transições de cena, etc. }
end;

procedure TEngine2D.OnRender;
begin
 { Comportamento padrão: renderiza todas as camadas sem separação de câmera.
   Adequado para jogos simples que não usam BeginMode2D. Sobrescreva para implementar parallax, câmera 2D e separação rlWorld/rlScreen. }
   ClearBackground(BLACK);
   FWorld.Render;
end;

procedure TEngine2D.OnShutdown;
begin
   { Sobrescreva para: UnloadAssets, fechar conexões, salvar dados, etc. }
end;

{ Loop principal único — nenhuma subclasse deve reescrever este método. }
procedure TEngine2D.Run;
const
   FIXED_DT  = 1.0 / 60.0; // passo físico fixo (60 Hz)
   MAX_DELTA = 0.25;       // teto de delta — evita "spiral of death"
var
   Delta, Accumulator: Single;
begin
   { --- Inicialização de janela e áudio ------------------------------------ }
   InitWindow(FScreenW, FScreenH, PChar(FTitle));
   if not IsWindowReady then
      raise Exception.Create('TEngine2D: Falha ao inicializar janela raylib.');

   SetTargetFPS(FTargetFPS);

   InitAudioDevice;
   if not IsAudioDeviceReady then
      raise Exception.Create('TEngine2D: Falha ao inicializar áudio raylib.');

   try
      { --- OnInit: assets e entidades (contexto OpenGL já disponível) ------- }
      OnInit;

      { --- World.Init: chama TSystem2D.Init em todos os sistemas habilitados
      Deve vir APÓS OnInit para que as entidades já existam quando os sistemas as buscarem (ex: TCameraSystem.Init localiza câmera e player). }
      FWorld.Init;

      FRunning    := True;
      Accumulator := 0.0;

      { --- Loop principal --------------------------------------------------- }
      while FRunning and not WindowShouldClose do
      begin
         Delta       := Min(GetFrameTime, MAX_DELTA);
         Accumulator := Accumulator + Delta;

       { Passos físicos fixos: Physics + Collision rodam aqui. }
         while Accumulator >= FIXED_DT do
         begin
            FWorld.FixedUpdate(FIXED_DT);
            Accumulator := Accumulator - FIXED_DT;
         end;

       { Lógica variável (1× por frame): Input, Animação, Câmera.
         PurgeDestroyed é chamado internamente ao final de FWorld.Update. }
         FWorld.Update(Delta);

         InputManager.Poll;

       { Hook de update extra: lógica de meta-jogo (restart, pause, etc.)
         Rodado após FWorld.Update para que entidades já estejam purgadas. }
         OnUpdate(Delta);

       { Alpha para interpolação visual (disponível via property Alpha). }
         FAlpha := Accumulator / FIXED_DT;

       { Renderização: OnRender é responsável por ClearBackground e toda a
         lógica de câmera/camadas. TEngine2D apenas envolve com Begin/EndDrawing. }
         BeginDrawing;
            OnRender;
         EndDrawing;
      end;

   except on E: Exception do
   begin
      TraceLog(LOG_ERROR, PChar('TEngine2D — Erro fatal: ' + E.Message));
      raise;
   end;
   end;

   { --- Encerramento -------------------------------------------------------- }
   FWorld.Shutdown;
   OnShutdown;        // libera assets do jogo concreto após Shutdown do World
   CloseAudioDevice;
   CloseWindow;
end;

procedure TEngine2D.Quit;
begin
   FRunning := False;
end;

end.

