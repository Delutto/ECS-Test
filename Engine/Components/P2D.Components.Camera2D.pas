unit P2D.Components.Camera2D;

{$mode objfpc}{$H+}

interface

uses raylib, P2D.Core.Component, P2D.Core.Types;

type
  TCamera2DComponent = class(TComponent2D)
  public
    RaylibCamera: TCamera2D;
    Zoom        : Single;
    FollowSpeed : Single;
    Bounds      : TRectF;   // world limits (0,0,0,0 = unlimited)
    UseBounds   : Boolean;
    constructor Create; override;
  end;

implementation

constructor TCamera2DComponent.Create;
begin
  inherited Create;
  FillChar(RaylibCamera, SizeOf(RaylibCamera), 0);
  RaylibCamera.Zoom := 1.0;
  Zoom        := 1.0;
  FollowSpeed := 5.0;
  UseBounds   := False;
  Bounds      := TRectF.Create(0, 0, 0, 0);
end;

end.