unit P2D.Systems.Audio;

{$mode ObjFPC}{$H+}

{ ============================================================================
  TAudioSystem
  Sistema ECS responsável por atualizar streams de música (UpdateMusicStream)
  e reagir a eventos do EventBus para reproduzir sons e controlar música.

  Arquitetura de comunicação:
    Qualquer sistema publica um TAudioPlaySoundEvent ou TAudioPlayMusicEvent
    no EventBus → TAudioSystem executa o comando no mesmo fim de frame.

  Ciclo de vida:
    Init     → itera MusicPlayer com AutoPlay=True e inicia reprodução;
               subscreve eventos de áudio no EventBus.
    Update   → chama UpdateMusicStream para cada música ativa.
    Shutdown → para todas as músicas; cancela subscrições.

  Sistemas que queiram disparar sons devem publicar eventos — nunca
  chamar PlaySound diretamente. Isso mantém o acoplamento zero entre
  sistemas de gameplay e a camada de áudio.
  ============================================================================ }

interface

uses
  SysUtils, raylib,
  P2D.Core.System,
  P2D.Core.World,
  P2D.Core.Entity,
  P2D.Core.Event,
  P2D.Components.MusicPlayer;

{ ── Eventos de áudio publicados por outros sistemas ────────────────────────── }
type
  { Solicita a reprodução de um som por nome de arquivo }
  TAudioPlaySoundEvent = class(TEvent2D)
  public
    FileName : string;
    Volume   : Single;
    Pitch    : Single;
    Pan      : Single;
    constructor Create(const AFileName: string; AVolume: Single = 1.0; APitch: Single = 1.0; APan: Single = 0.5);
  end;

  { Solicita a reprodução de uma faixa de música por nome de arquivo }
  TAudioPlayMusicEvent = class(TEvent2D)
  public
    FileName    : string;
    Volume      : Single;
    FadeIn      : Boolean; // reservado para uso futuro
    constructor Create(const AFileName: string; AVolume: Single = 1.0; AFadeIn: Boolean = False);
  end;

  { Solicita a parada de todas as músicas }
  TAudioStopMusicEvent = class(TEvent2D)
  public
    constructor Create;
  end;

  { Solicita ajuste de volume global (0.0 a 1.0) }
  TAudioSetVolumeEvent = class(TEvent2D)
  public
    MasterVolume : Single;
    constructor Create(AVolume: Single);
  end;

{ ── Sistema ─────────────────────────────────────────────────────────────── }
  TAudioSystem = class(TSystem2D)
  private
    { Callbacks vinculados ao EventBus }
    procedure OnPlaySound(AEvent: TEvent2D);
    procedure OnPlayMusic(AEvent: TEvent2D);
    procedure OnStopMusic(AEvent: TEvent2D);
    procedure OnSetVolume(AEvent: TEvent2D);
    { Helpers internos }
    procedure StartMusic(AMP: TMusicPlayerComponent);
  public
    constructor Create(AWorld: TWorldBase); override;
    procedure Init;     override;
    procedure Update(ADelta: Single); override;
    procedure StopAllMusic;
    procedure Shutdown; override;
  end;

implementation

uses
  P2D.Core.ResourceManager,
  P2D.Utils.Logger;

{ ── Implementações dos eventos ──────────────────────────────────────────── }

constructor TAudioPlaySoundEvent.Create(const AFileName: string; AVolume, APitch, APan: Single);
begin
  inherited Create;
  FileName := AFileName;
  Volume   := AVolume;
  Pitch    := APitch;
  Pan      := APan;
end;

constructor TAudioPlayMusicEvent.Create(const AFileName: string; AVolume: Single; AFadeIn: Boolean);
begin
  inherited Create;
  
  FileName := AFileName;
  Volume   := AVolume;
  FadeIn   := AFadeIn;
end;

constructor TAudioStopMusicEvent.Create;
begin
  inherited Create;
end;

constructor TAudioSetVolumeEvent.Create(AVolume: Single);
begin
  inherited Create;
  
  MasterVolume := AVolume;
end;

{ ── TAudioSystem ─────────────────────────────────────────────────────────── }

constructor TAudioSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority    := 50;           // após física e colisão, antes de render
   Name        := 'AudioSystem';
   RenderLayer := rlScreen;     // não renderiza nada, mas pertence ao loop de tela
end;

procedure TAudioSystem.Init;
var
   E  : TEntity;
   MP : TMusicPlayerComponent;
begin
   inherited;

   RequireComponent(TMusicPlayerComponent);

   { Inicia músicas marcadas como AutoPlay }
   for E in GetMatchingEntities do
   begin
      //if not E.Alive then
      //   Continue;
      MP := TMusicPlayerComponent(E.GetComponent(TMusicPlayerComponent));
      if Assigned(MP) and MP.AutoPlay then
         StartMusic(MP);
   end;

   { Subscreve eventos de áudio no EventBus global da World }
   World.EventBus.Subscribe(TAudioPlaySoundEvent, @OnPlaySound);
   World.EventBus.Subscribe(TAudioPlayMusicEvent, @OnPlayMusic);
   World.EventBus.Subscribe(TAudioStopMusicEvent, @OnStopMusic);
   World.EventBus.Subscribe(TAudioSetVolumeEvent, @OnSetVolume);

   {$IFDEF DEBUG}
   Logger.Info('[AudioSystem] Initialized');
   {$ENDIF}
end;

procedure TAudioSystem.Update(ADelta: Single);
var
   E  : TEntity;
   MP : TMusicPlayerComponent;
begin
   { UpdateMusicStream deve ser chamado todo frame para músicas ativas }
   for E in GetMatchingEntities do
   begin
      //if not E.Alive then
      //   Continue;
      MP := TMusicPlayerComponent(E.GetComponent(TMusicPlayerComponent));
      if not Assigned(MP) then
         Continue;
      if MP.Playing then
         UpdateMusicStream(MP.Music) { raylib exige UpdateMusicStream todo frame para alimentar o buffer }
      else if MP.AutoPlay and (MP.Music.CtxType <> 0) then
         StartMusic(MP); { Entidade recém-criada (ex: após restart) com AutoPlay=True: inicia automaticamente sem precisar de um novo Init do sistema. }
   end;
end;

procedure TAudioSystem.Shutdown;
begin
  StopAllMusic;
  World.EventBus.Unsubscribe(TAudioPlaySoundEvent, @OnPlaySound);
  World.EventBus.Unsubscribe(TAudioPlayMusicEvent, @OnPlayMusic);
  World.EventBus.Unsubscribe(TAudioStopMusicEvent, @OnStopMusic);
  World.EventBus.Unsubscribe(TAudioSetVolumeEvent, @OnSetVolume);
  {$IFDEF DEBUG}
	Logger.Info('[AudioSystem] Shutdown');
  {$ENDIF}
  inherited;
end;

{ ── Helpers internos ─────────────────────────────────────────────────────── }

procedure TAudioSystem.StartMusic(AMP: TMusicPlayerComponent);
begin
   if AMP.Music.CtxType = 0 then
      Exit; // handle inválido
   SetMusicVolume(AMP.Music, AMP.Volume);
   SetMusicPitch (AMP.Music, AMP.Pitch);
   PlayMusicStream(AMP.Music);
   AMP.Playing := True;
   {$IFDEF DEBUG}
   Logger.Debug('[AudioSystem] Music started');
   {$ENDIF}
end;

procedure TAudioSystem.StopAllMusic;
var
  E  : TEntity;
  MP : TMusicPlayerComponent;
begin
  for E in GetMatchingEntities do
  begin
    //if not E.Alive then
    //   Continue;
    MP := TMusicPlayerComponent(E.GetComponent(TMusicPlayerComponent));
    if Assigned(MP) and MP.Playing then
    begin
      StopMusicStream(MP.Music);
      MP.Playing := False;
    end;
  end;
end;

{ ── Handlers de eventos ──────────────────────────────────────────────────── }

procedure TAudioSystem.OnPlaySound(AEvent: TEvent2D);
var
  Ev  : TAudioPlaySoundEvent;
  Snd : TSound;
begin
  Ev  := TAudioPlaySoundEvent(AEvent);
  Snd := TResourceManager2D.Instance.LoadSound(Ev.FileName);
  if Snd.FrameCount = 0 then
  begin
	{$IFDEF DEBUG}
    Logger.Warn('[AudioSystem] Sound not found: ' + Ev.FileName);
	{$ENDIF}
    Exit;
  end;
  SetSoundVolume(Snd, Ev.Volume);
  SetSoundPitch (Snd, Ev.Pitch);
  SetSoundPan   (Snd, Ev.Pan);
  PlaySound(Snd);
  {$IFDEF DEBUG}
  Logger.Debug('[AudioSystem] Sound played: ' + Ev.FileName);
  {$ENDIF}
end;

procedure TAudioSystem.OnPlayMusic(AEvent: TEvent2D);
var
  Ev  : TAudioPlayMusicEvent;
  E   : TEntity;
  MP  : TMusicPlayerComponent;
begin
  Ev := TAudioPlayMusicEvent(AEvent);
  StopAllMusic;
  for E in GetMatchingEntities do
  begin
    //if not E.Alive then
    //   Continue;
    MP := TMusicPlayerComponent(E.GetComponent(TMusicPlayerComponent));
    if Assigned(MP) then
    begin
      MP.Music  := TResourceManager2D.Instance.LoadMusic(Ev.FileName);
      MP.Volume := Ev.Volume;
      StartMusic(MP);
      Break; // usa o primeiro player disponível
    end;
  end;
end;

procedure TAudioSystem.OnStopMusic(AEvent: TEvent2D);
begin
  StopAllMusic;
end;

procedure TAudioSystem.OnSetVolume(AEvent: TEvent2D);
var
  Ev : TAudioSetVolumeEvent;
begin
  Ev := TAudioSetVolumeEvent(AEvent);
  SetMasterVolume(Ev.MasterVolume);
  {$IFDEF DEBUG}
  Logger.Debug(Format('[AudioSystem] Master volume set to %.2f', [Ev.MasterVolume]));
  {$ENDIF}
end;

end.
