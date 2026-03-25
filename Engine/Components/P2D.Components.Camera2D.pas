unit P2D.Components.Camera2D;

{$mode objfpc}{$H+}

interface

uses
   raylib,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.Component;

type
   TCamera2DComponent = class(TComponent2D)
   public
      RaylibCamera: TCamera2D;
      Zoom: Single;
      FollowSpeed: Single;
      Bounds: TRectF;   // world limits (0,0,0,0 = unlimited)
      UseBounds: boolean;
      Target: TEntity;
      constructor Create; override;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TCamera2DComponent.Create;
begin
   inherited Create;

   FillChar(RaylibCamera, SizeOf(RaylibCamera), 0);
   RaylibCamera.Zoom := 1.0;
   Zoom := 3.0;
   FollowSpeed := 5.0;
   UseBounds := False;
   Bounds.Create(0, 0, 0, 0);

   Target := nil;
end;

initialization
   ComponentRegistry.Register(TCamera2DComponent);

end.
