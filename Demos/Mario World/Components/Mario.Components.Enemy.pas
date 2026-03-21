unit Mario.Components.Enemy;

{$mode objfpc}{$H+}

interface

uses
   P2D.Core.Component;

type
   TGoombaComponent = class(TComponent2D)
   public
      Speed        : Single;
      Direction    : Single;  // -1 = left,  +1 = right
      WallCooldown : Single;  // seconds remaining before another wall-flip is allowed
      constructor Create; override;
   end; 

implementation

uses
   P2D.Core.ComponentRegistry;

{ TGoombaComponent }
constructor TGoombaComponent.Create;
begin
   inherited Create;

   Speed        := 60;
   Direction    := -1;
   WallCooldown := 0.0;
end;

initialization
   ComponentRegistry.Register(TGoombaComponent);

end.
