unit P2D.Components.Transform;

{$mode objfpc}{$H+}

interface

uses
   raylib,
   P2D.Core.Component;

type
   TTransformComponent = class(TComponent2D)
   public
      Position: TVector2;
      PrevPosition: TVector2;
      Scale: TVector2;
      Rotation: Single;      // Degrees
      constructor Create; override;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TTransformComponent.Create;
begin
   inherited Create;

   Position := Vector2Create(0, 0);
   PrevPosition := Vector2Create(0, 0);
   Scale := Vector2Create(1, 1);
   Rotation := 0;
end;

initialization
   ComponentRegistry.Register(TTransformComponent);

end.
