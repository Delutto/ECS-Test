unit Mario.Components.Fish;

{$mode objfpc}{$H+}

interface

uses
   P2D.Core.Component;

type
   TFishComponent = class(TComponent2D)
   public
      Speed: Single;        { horizontal swim speed (world-units/s)       }
      Direction: Single;    { -1 = left, +1 = right                       }
      WallCooldown: Single; { seconds before another wall-flip is allowed }
      OscAmplitude: Single; { vertical oscillation force amplitude (N)    }
      OscFrequency: Single; { oscillation cycles per second (Hz)          }
      OscTimer: Single;     { accumulated oscillation time (seconds)      }
      constructor Create; override;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TFishComponent.Create;
begin
   inherited Create;

   Speed := 55.0;
   Direction := -1.0;
   WallCooldown := 0.0;
   OscAmplitude := 700.0;
   OscFrequency := 0.8;
   OscTimer := 0.0;
end;

initialization
   ComponentRegistry.Register(TFishComponent);

end.
