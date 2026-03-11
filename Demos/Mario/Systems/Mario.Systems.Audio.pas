unit Mario.Systems.Audio;

{$mode ObjFPC}{$H+}

{ ============================================================================
   TMarioAudioSystem
   Sistema de áudio específico do demo Mario.
   Herda de TAudioSystem (que gerencia UpdateMusicStream e Sons via eventos)
   e acrescenta subscrições nos eventos de gameplay do Mario para disparar
   os sons corretos sem que nenhum sistema de gameplay precise saber quais
   arquivos de audio existem.

   Mapeamento de eventos → sons:
      TCoinCollectedEvent → sfx/coin.wav
      TEnemyStompedEvent  → sfx/stomp.wav
      TPlayerDamagedEvent → sfx/damage.wav
      TPlayerDiedEvent    → sfx/gameover.wav
      TPlayerDiedEvent    → interrompe música de fundo

   Música de fundo:
   Carregada via TResourceManager2D e atribuída à entidade de música
   criada em Mario.Level (CreateMusicPlayer).
  ============================================================================ }

interface

uses
   SysUtils,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Core.Event,
   P2D.Systems.Audio,    // TAudioSystem + TAudioPlaySoundEvent, TAudioPlayMusicEvent
   Mario.Events,         // TCoinCollectedEvent, TEnemyStompedEvent, etc.
   Mario.Common;

   type

   { TMarioAudioSystem }

   TMarioAudioSystem = class(TAudioSystem)
   private
      procedure OnCoinCollected (AEvent: TEvent2D);
      procedure OnEnemyStomped  (AEvent: TEvent2D);
      procedure OnPlayerJump    (AEvent: TEvent2D);
      procedure OnPlayerSpin    (AEvent: TEvent2D);
      procedure OnPlayerDamaged (AEvent: TEvent2D);
      procedure OnPlayerDied    (AEvent: TEvent2D);
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init;     override;
      procedure Shutdown; override;
   end;

implementation

constructor TMarioAudioSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Name := 'MarioAudioSystem';
end;

procedure TMarioAudioSystem.Init;
begin
   inherited;

   { Subscreve eventos de gameplay do Mario }
   World.EventBus.Subscribe(TCoinCollectedEvent, @OnCoinCollected);
   World.EventBus.Subscribe(TEnemyStompedEvent,  @OnEnemyStomped);
   World.EventBus.Subscribe(TPlayerJumpEvent,    @OnPlayerJump);
   World.EventBus.Subscribe(TPlayerSpinEvent,    @OnPlayerSpin);
   World.EventBus.Subscribe(TPlayerDamagedEvent, @OnPlayerDamaged);
   World.EventBus.Subscribe(TPlayerDiedEvent,    @OnPlayerDied);
end;

procedure TMarioAudioSystem.Shutdown;
begin
   World.EventBus.Unsubscribe(TCoinCollectedEvent, @OnCoinCollected);
   World.EventBus.Unsubscribe(TEnemyStompedEvent,  @OnEnemyStomped);
   World.EventBus.Unsubscribe(TPlayerJumpEvent,    @OnPlayerJump);
   World.EventBus.Unsubscribe(TPlayerSpinEvent,    @OnPlayerSpin);
   World.EventBus.Unsubscribe(TPlayerDamagedEvent, @OnPlayerDamaged);
   World.EventBus.Unsubscribe(TPlayerDiedEvent,    @OnPlayerDied);
   { Pai cancela subscrições de áudio e para músicas }
   inherited;
end;

{ ── Handlers ─────────────────────────────────────────────────────────────── }

procedure TMarioAudioSystem.OnCoinCollected(AEvent: TEvent2D);
begin
   World.EventBus.Publish(TAudioPlaySoundEvent.Create(SFX_COIN, 0.9));
end;

procedure TMarioAudioSystem.OnEnemyStomped(AEvent: TEvent2D);
begin
   World.EventBus.Publish(TAudioPlaySoundEvent.Create(SFX_STOMP, 1.0));
end;

procedure TMarioAudioSystem.OnPlayerJump(AEvent: TEvent2D);
begin
   World.EventBus.Publish(TAudioPlaySoundEvent.Create(SFX_JUMP, 1.0));
end;

procedure TMarioAudioSystem.OnPlayerSpin(AEvent: TEvent2D);
begin
   World.EventBus.Publish(TAudioPlaySoundEvent.Create(SFX_SPIN, 1.0));
end;

procedure TMarioAudioSystem.OnPlayerDamaged(AEvent: TEvent2D);
begin
   World.EventBus.Publish(TAudioPlaySoundEvent.Create(SFX_DAMAGE, 1.0));
end;

procedure TMarioAudioSystem.OnPlayerDied(AEvent: TEvent2D);
begin
   { Para a música e toca o som de game over }
   World.EventBus.Publish(TAudioStopMusicEvent.Create);
   World.EventBus.Publish(TAudioPlaySoundEvent.Create(SFX_GAMEOVER, 1.0));
end;

end.
