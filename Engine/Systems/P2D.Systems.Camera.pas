unit P2D.Systems.Camera;

{$mode objfpc}{$H+}

interface

uses
	SysUtils, Math, raylib, P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
     P2D.Components.Transform, P2D.Components.Camera2D, P2D.Components.Tags;
	 
type
  TCameraSystem = class(TSystem2D)
  private
    FCamEntity: TEntity;
    FTarget   : TEntity;
    FScreenW  : Integer;
    FScreenH  : Integer;
  public
    constructor Create(AWorld: TWorld; AScreenW, AScreenH: Integer); reintroduce;
    procedure Init; override;
    procedure Update(ADelta: Single); override;
    procedure BeginCameraMode;
    procedure EndCameraMode;
    function  GetRaylibCamera: TCamera2D;
  end;
  
implementation

constructor TCameraSystem.Create(AWorld: TWorld; AScreenW, AScreenH: Integer);
begin
	inherited Create(AWorld);
	Priority := 15;
	Name := 'CameraSystem';
	FScreenW := AScreenW;
	FScreenH := AScreenH;
end;

procedure TCameraSystem.Init;
begin
  FCamEntity := nil;
  FTarget := nil;
  for var E in World.Entities.GetAll do
    if E.Alive and E.HasComponent(TCamera2DComponent) then
	begin
		FCamEntity:=E;
		Break;
	end;
  for var E in World.Entities.GetAll do
    if E.Alive and E.HasComponent(TPlayerTag) then
	begin
		FTarget:=E;
		Break;
	end;
end;

procedure TCameraSystem.Update(ADelta: Single);
var
	Cam: TCamera2DComponent;
	CamTr, TgtTr: TTransformComponent;
	HalfW, HalfH: Single;
begin
  if not Assigned(FCamEntity) then
	Exit;
  Cam := TCamera2DComponent(FCamEntity.GetComponent(TCamera2DComponent));
  CamTr := TTransformComponent(FCamEntity.GetComponent(TTransformComponent));
  if not Assigned(Cam) or not Assigned(CamTr) then
	Exit;
  HalfW := FScreenW/2;
  HalfH := FScreenH/2;
  if Assigned(FTarget) and FTarget.Alive then
  begin
    TgtTr:=TTransformComponent(FTarget.GetComponent(TTransformComponent));
    if Assigned(TgtTr) then
	begin
      CamTr.Position.X := CamTr.Position.X + (TgtTr.Position.X - CamTr.Position.X) * Cam.FollowSpeed * ADelta;
      CamTr.Position.Y := CamTr.Position.Y + (TgtTr.Position.Y - CamTr.Position.Y) * Cam.FollowSpeed * ADelta;
    end;
  end;
  if Cam.UseBounds then
  begin
    if CamTr.Position.X < Cam.Bounds.X+HalfW/Cam.Zoom then
		CamTr.Position.X := Cam.Bounds.X + HalfW / Cam.Zoom;
    if CamTr.Position.Y < Cam.Bounds.Y + HalfH / Cam.Zoom then
		CamTr.Position.Y := Cam.Bounds.Y + HalfH / Cam.Zoom;
    if CamTr.Position.X > Cam.Bounds.Right - HalfW / Cam.Zoom then
		CamTr.Position.X := Cam.Bounds.Right - HalfW / Cam.Zoom;
    if CamTr.Position.Y > Cam.Bounds.Bottom-HalfH / Cam.Zoom then
		CamTr.Position.Y := Cam.Bounds.Bottom - HalfH / Cam.Zoom;
  end;
  Cam.RaylibCamera.Target.X := CamTr.Position.X;
  Cam.RaylibCamera.Target.Y := CamTr.Position.Y;
  Cam.RaylibCamera.Offset.X := HalfW;
  Cam.RaylibCamera.Offset.Y := HalfH;
  Cam.RaylibCamera.Zoom := Cam.Zoom;
end;

procedure TCameraSystem.BeginCameraMode;
var
	Cam: TCamera2DComponent;
begin
	if not Assigned(FCamEntity) then
		Exit;
	Cam := TCamera2DComponent(FCamEntity.GetComponent(TCamera2DComponent));
	if Assigned(Cam) then
		BeginMode2D(Cam.RaylibCamera);
end;

procedure TCameraSystem.EndCameraMode;
begin
	EndMode2D;
end;

function TCameraSystem.GetRaylibCamera: TCamera2D;
var
	Cam: TCamera2DComponent;
begin
	FillChar(Result,SizeOf(Result),0);
	Result.Zoom := 1;
	if not Assigned(FCamEntity) then
		Exit;
	Cam := TCamera2DComponent(FCamEntity.GetComponent(TCamera2DComponent));
	if Assigned(Cam) then
		Result:=Cam.RaylibCamera;
end;

end.