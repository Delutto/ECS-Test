unit P2D.Core.Engine;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math, raylib,
   P2D.Common,
   P2D.Core.Types, P2D.Core.World, P2D.Core.InputManager;

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

   { TEngine2D }

   TEngine2D = class
   private
      FWorld         : TWorld;
      FTitle         : string;
      FVirtualW      : Integer;
      FVirtualH      : Integer;
      FTargetFPS     : Integer;
      FRunning       : Boolean;
      FAlpha    : Single; // Fração do passo físico atual (0..1) para interpolação
      FRenderTexture : TRenderTexture2D;
      FRTScale       : Single;
      FRTOffsetX     : Single;
      FRTOffsetY     : Single;
      FLastPhysW     : Integer;
      FLastPhysH     : Integer;

      procedure RecalcScale;
      procedure BlitVirtualCanvas;
      procedure HandleFullscreenToggle;
   protected
    { Hooks virtuais — sobrescreva na subclasse do jogo concreto.
      Implementações padrão são no-ops seguros (exceto OnRender, que chama FWorld.Render como comportamento básico). }
      procedure OnInit; virtual;
      procedure OnUpdate(ADelta: Single); virtual;
      procedure OnRender; virtual;
      procedure OnShutdown; virtual;
      procedure OnScreenResized(ANewW, ANewH: Integer); virtual;
   public
      constructor Create(AWindowW, AWindowH: Integer; const ATitle: string; AFPS: Integer = 60; AVirtualW: Integer = 0; AVirtualH: Integer = 0);
      destructor Destroy; override;

    { Inicia a janela, o áudio e o loop principal.
      Chama os hooks na ordem: OnInit → World.Init → loop → World.Shutdown → OnShutdown. }
      procedure Run;
    { Sinaliza o loop para encerrar no próximo frame. }
      procedure Quit;

      { Resizes the physical window and recalculates scale. }
      procedure SetWindowResolution(AWidth, AHeight: Integer);

      { Maps physical mouse/touch position to virtual canvas coordinates. }
      function ScreenToVirtual(const APhysical: TVector2): TVector2;
      function VirtualToScreen(const AVirtual: TVector2): TVector2;

      property World    : TWorld   read FWorld;
      property ScreenW  : Integer  read FVirtualW;
      property ScreenH  : Integer  read FVirtualH;
      property WindowW  : Integer  read FLastPhysW;
      property WindowH  : Integer  read FLastPhysH;
      property Running  : Boolean  read FRunning;
    { Fração do passo físico pendente (0..1). Use em OnRender para interpolar posições visuais entre passos físicos (ver P2D.Components.Transform.PrevPosition). }
      property Alpha    : Single   read FAlpha;
      property RTScale  : Single   read FRTScale;
   end;

implementation

{ TEngine2D }
constructor TEngine2D.Create(AWindowW, AWindowH: Integer; const ATitle: string; AFPS: Integer; AVirtualW: Integer; AVirtualH: Integer);
begin
   inherited Create;
   FTitle     := ATitle;
   FTargetFPS := AFPS;
   FWorld     := TWorld.Create;
   FRunning   := False;
   FAlpha     := 0.0;
   FLastPhysW := AWindowW;
   FLastPhysH := AWindowH;
   FRTScale   := 1.0;
   FRTOffsetX := 0.0;
   FRTOffsetY := 0.0;
   if (AVirtualW > 0) and (AVirtualH > 0) then
   begin
      FVirtualW := AVirtualW;
      FVirtualH := AVirtualH;
   end
   else
   begin
      FVirtualW := AWindowW;
      FVirtualH := AWindowH;
   end;
end;

destructor TEngine2D.Destroy;
begin
   FWorld.Free;
   inherited;
end;

procedure TEngine2D.RecalcScale;
var
   PhysW, PhysH  : Integer;
   ScaleX, ScaleY: Single;
begin
   PhysW  := GetScreenWidth;
   PhysH  := GetScreenHeight;
   ScaleX := PhysW / FVirtualW;
   ScaleY := PhysH / FVirtualH;
   FRTScale   := Min(ScaleX, ScaleY);
   FRTOffsetX := (PhysW - FVirtualW * FRTScale) * 0.5;
   FRTOffsetY := (PhysH - FVirtualH * FRTScale) * 0.5;
   FLastPhysW := PhysW;
   FLastPhysH := PhysH;
end;

procedure TEngine2D.BlitVirtualCanvas;
var
   Src, Dst: TRectangle;
begin
   Src.X      :=  0;
   Src.Y      :=  0;
   Src.Width  :=  FVirtualW;
   Src.Height := -FVirtualH;   { negative flips the Y axis }
   Dst.X      := FRTOffsetX;
   Dst.Y      := FRTOffsetY;
   Dst.Width  := FVirtualW * FRTScale;
   Dst.Height := FVirtualH * FRTScale;
   DrawTexturePro(FRenderTexture.Texture, Src, Dst, Vector2Create(0, 0), 0, WHITE);
end;

procedure TEngine2D.HandleFullscreenToggle;
begin
   if not (IsKeyDown(KEY_LEFT_ALT) or IsKeyDown(KEY_RIGHT_ALT)) then
      Exit;
   if not IsKeyPressed(KEY_ENTER) then
      Exit;

   ToggleFullscreen;
   RecalcScale;
   OnScreenResized(GetScreenWidth, GetScreenHeight);
end;

procedure TEngine2D.SetWindowResolution(AWidth, AHeight: Integer);
begin
   if IsWindowFullscreen then
      ToggleFullscreen;

   SetWindowSize(AWidth, AHeight);
   SetWindowPosition((GetMonitorWidth(GetCurrentMonitor)  - AWidth)  div 2, (GetMonitorHeight(GetCurrentMonitor) - AHeight) div 2);
   RecalcScale;
   OnScreenResized(AWidth, AHeight);
end;

function TEngine2D.ScreenToVirtual(const APhysical: TVector2): TVector2;
begin
   Result.X := (APhysical.X - FRTOffsetX) / FRTScale;
   Result.Y := (APhysical.Y - FRTOffsetY) / FRTScale;
end;

function TEngine2D.VirtualToScreen(const AVirtual: TVector2): TVector2;
begin
   Result.X := AVirtual.X * FRTScale + FRTOffsetX;
   Result.Y := AVirtual.Y * FRTScale + FRTOffsetY;
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

procedure TEngine2D.OnScreenResized(ANewW, ANewH: Integer);
begin
   { No-op padrão. Sobrescreva para propagar as novas dimensões a cenas, sistemas de HUD, câmera, render targets, etc. }
end;

{ Loop principal único — nenhuma subclasse deve reescrever este método. }
procedure TEngine2D.Run;
var
   Delta, Accumulator: Single;
begin
   { --- Inicialização de janela e áudio ------------------------------------ }
   InitWindow(FLastPhysW, FLastPhysH, PChar(FTitle));
   if not IsWindowReady then
      raise Exception.Create('TEngine2D: Falha ao inicializar janela raylib.');

   SetTargetFPS(FTargetFPS);

   InitAudioDevice;
   if not IsAudioDeviceReady then
      raise Exception.Create('TEngine2D: Falha ao inicializar áudio raylib.');

   { RenderTexture2D requires an active GL context — create after InitWindow. }
   FRenderTexture := LoadRenderTexture(FVirtualW, FVirtualH);
   RecalcScale;

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
         { Detect OS-level window resize. }
         if (GetScreenWidth <> FLastPhysW) or (GetScreenHeight <> FLastPhysH) then
            RecalcScale;

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

         { Verifica ALT+ENTER antes do hook OnUpdate para que o jogo já receba o delta com as dimensões corretas neste frame. }
         HandleFullscreenToggle;

       { Hook de update extra: lógica de meta-jogo (restart, pause, etc.)
         Rodado após FWorld.Update para que entidades já estejam purgadas. }
         OnUpdate(Delta);

       { Alpha para interpolação visual (disponível via property Alpha). }
         FAlpha := Accumulator / FIXED_DT;

       { Render game into the virtual canvas. }
         BeginTextureMode(FRenderTexture);
            OnRender;
         EndTextureMode;

         { Blit scaled canvas onto the physical screen. }
         BeginDrawing;
            ClearBackground(BLACK);
            BlitVirtualCanvas;
         EndDrawing;
      end;

   except on E: Exception do
   begin
      {$IFDEF DEBUG}
      TraceLog(LOG_ERROR, PChar('TEngine2D — Erro fatal: ' + E.Message));
      {$ENDIF}
      try
         FWorld.Shutdown;
         OnShutdown;
         if FRenderTexture.Id > 0 then
         UnloadRenderTexture(FRenderTexture);
         CloseAudioDevice;
         CloseWindow;
      except
      {$IFDEF DEBUG}
         TraceLog(LOG_ERROR, PChar('TEngine2D — Erro fatal: ' + E.Message));
      {$ENDIF}
      end;
   end;
   end;

   { --- Encerramento -------------------------------------------------------- }
   FWorld.Shutdown;
   OnShutdown;        // libera assets do jogo concreto após Shutdown do World
   UnloadRenderTexture(FRenderTexture);
   CloseAudioDevice;
   CloseWindow;
end;

procedure TEngine2D.Quit;
begin
   FRunning := False;
end;

end.

