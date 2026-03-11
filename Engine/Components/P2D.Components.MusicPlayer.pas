unit P2D.Components.MusicPlayer;

{$mode ObjFPC}{$H+}

{ ============================================================================
  TMusicPlayerComponent
  Componente que armazena um TMusic raylib (stream de áudio) e expõe
  configurações de volume, pitch e controle de loop.
  O asset é gerenciado externamente pelo TResourceManager2D.

  Uso típico:
    MP := TMusicPlayerComponent(E.AddComponent(TMusicPlayerComponent.Create));
    MP.Music  := ResourceManager.LoadMusic('assets/audio/overworld.ogg');
    MP.Volume := 0.6;
    MP.Loop   := True;
    MP.AutoPlay := True;   // inicia ao Init do sistema de áudio
  ============================================================================ }

interface

uses
  SysUtils, raylib,
  P2D.Core.Component;

type
  TMusicPlayerComponent = class(TComponent2D)
  private
    FMusic    : TMusic;
    FVolume   : Single;
    FPitch    : Single;
    FAutoPlay : Boolean;
    FLoop     : Boolean;
    FPlaying  : Boolean;
  public
    constructor Create; override;
    property Music    : TMusic  read FMusic    write FMusic;
    property Volume   : Single  read FVolume   write FVolume;
    property Pitch    : Single  read FPitch    write FPitch;
    property AutoPlay : Boolean read FAutoPlay write FAutoPlay;
    property Loop     : Boolean read FLoop     write FLoop;
    property Playing  : Boolean read FPlaying  write FPlaying;
  end;

implementation

constructor TMusicPlayerComponent.Create;
begin
  inherited Create;
  FMusic    := Default(TMusic);
  FVolume   := 1.0;
  FPitch    := 1.0;
  FAutoPlay := False;
  FLoop     := True;
  FPlaying  := False;
end;

end.
