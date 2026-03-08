unit P2D.Components.Audio;

{$mode objfpc}{$H+}

interface

uses
   P2D.Core.Component;

type
   TAudioSourceComponent = class(TComponent2D)
   public
      SoundName: String;      // Arquivo de som (TSound)
      MusicName: String;      // Arquivo de música (TMusic) – prioridade sobre SoundName
      Volume: Single;          // 0..1
      Pitch: Single;           // 1.0 = normal
      Loop: Boolean;
      AutoPlay: Boolean;       // Tocar automaticamente quando o componente for ativado
      PlayOnAwake: Boolean;    // Tocar ao ser adicionado à entidade
      IsPlaying: Boolean;      // Estado atual (gerenciado pelo sistema)
      constructor Create; override;
   end;

implementation

constructor TAudioSourceComponent.Create;
begin
   inherited Create;

   Volume := 1.0;
   Pitch := 1.0;
   Loop := False;
   AutoPlay := True;
   PlayOnAwake := True;
   IsPlaying := False;
end;

end.
