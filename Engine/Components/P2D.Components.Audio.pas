unit P2D.Components.Audio;

{$mode ObjFPC}{$H+}

{ ============================================================================
  TAudioSourceComponent
  Componente que armazena um TSound raylib e expõe configurações de volume,
  pitch e pan. Não gerencia o ciclo de vida do asset (responsabilidade do
  TResourceManager2D) — armazena apenas o handle retornado pelo manager.

  Uso típico:
    AS := TAudioSourceComponent(E.AddComponent(TAudioSourceComponent.Create));
    AS.Sound   := ResourceManager.LoadSound('assets/audio/jump.wav');
    AS.Volume  := 0.8;
    AS.Pitch   := 1.0;
    AS.Pan     := 0.5;  // 0.0=esquerda, 0.5=centro, 1.0=direita
  ============================================================================ }

interface

uses
   SysUtils,
   P2D.Core.Component;

type
   TAudioComponent = class(TComponent2D)
   private
      FSound      : String;
      FMusic      : String;
      FVolume     : Single;
      FPitch      : Single;
      FPan        : Single;
      FLoop       : Boolean;
      FAutoPlay   : Boolean;
      FPlayOnAwake: Boolean;
      FPlaying    : Boolean;
   public
      constructor Create; override;
      property Sound: String          read FSound       write FSound;
      property Music: String          read FMusic       write FMusic;
      property Volume: Single         read FVolume      write FVolume;
      property Pitch: Single          read FPitch       write FPitch;
      property Pan: Single            read FPan         write FPan;
      property Loop: Boolean          read FLoop        write FLoop;
      property AutoPlay: Boolean      read FAutoPlay    write FAutoPlay;
      property PlayOnAwake: Boolean   read FPlayOnAwake write FPlayOnAwake;
      property Playing: Boolean       read FPlaying     write FPlaying;
   end;

implementation

constructor TAudioComponent.Create;
begin
   inherited Create;

   FSound       := '';
   FMusic       := '';
   FVolume      := 1.0;
   FPitch       := 1.0;
   FPan         := 0.5;
   FLoop        := False;
   FLoop        := False;
   FAutoPlay    := False;
   FPlayOnAwake := False;
   FPlaying     := False;
end;

end.
