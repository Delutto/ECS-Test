unit P2D.Systems.Camera;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math, raylib,
   P2D.Core.ComponentRegistry, P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Components.Transform, P2D.Components.Camera2D;

type
   TCameraSystem = class(TSystem2D)
   private
      FCamEntity: TEntity;
      FTarget   : TEntity;
      FScreenW  : Integer;
      FScreenH  : Integer;

      FTransformID: Integer;
      FCameraID: Integer;
   public
      constructor Create(AWorld: TWorldBase; AScreenW, AScreenH: Integer); reintroduce;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure BeginCameraMode;
      procedure EndCameraMode;
      function  GetRaylibCamera: TCamera2D;

      //property Target: TEntity read FTarget write FTarget;
   end;

implementation

constructor TCameraSystem.Create(AWorld: TWorldBase; AScreenW, AScreenH: Integer);
begin
   inherited Create(AWorld);

   Priority    := 15;
   Name        := 'CameraSystem';

   FCamEntity  := nil;
   FTarget     := nil;
   FScreenW    := AScreenW;
   FScreenH    := AScreenH;
end;

procedure TCameraSystem.Init;
var
   E: TEntity;
   Cam: TCamera2DComponent;
begin
   inherited;

 { Define assinatura para que o cache saiba filtrar câmeras e players.
   O Update usa FCamEntity/FTarget diretamente — GetMatchingEntities é usado apenas aqui no Init para localizar as entidades. }
   RequireComponent(TTransformComponent);

   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
   FCameraID := ComponentRegistry.GetComponentID(TCamera2DComponent);

   FCamEntity := nil;
   FTarget    := nil;
   for E in GetMatchingEntities do
   begin
      Cam := TCamera2DComponent(E.GetComponentByID(FCameraID));
      if Cam <> nil then
      begin
         FCamEntity := E;
         FTarget := Cam.Target;
         Break;
      end;
   end;
end;

procedure TCameraSystem.Update(ADelta: Single);
var
   Cam   : TCamera2DComponent;
   CamTr : TTransformComponent;
   TgtTr : TTransformComponent;
   SW    : Integer;
   SH    : Integer;
   HalfW : Single;
   HalfH : Single;
   HalfWW: Single;
   HalfHW: Single;
begin
   if not Assigned(FCamEntity) then
      Exit;

   Cam   := TCamera2DComponent(FCamEntity.GetComponentByID(FCameraID));
   CamTr := TTransformComponent(FCamEntity.GetComponentByID(FTransformID));

   if not Assigned(Cam) or not Assigned(CamTr) then
      Exit;

   { Dimensões reais da janela neste frame — corretas após qualquer toggle. }
   SW    := GetScreenWidth;
   SH    := GetScreenHeight;
   HalfW := SW / 2;
   HalfH := SH / 2;

   { ── Smooth follow ──────────────────────────────────────────────────── }
   if Assigned(FTarget) and FTarget.Alive then
   begin
      TgtTr := TTransformComponent(FTarget.GetComponentByID(FTransformID));
      if Assigned(TgtTr) then
      begin
         CamTr.Position.X := CamTr.Position.X + (TgtTr.Position.X - CamTr.Position.X) * Cam.FollowSpeed * ADelta;
         CamTr.Position.Y := CamTr.Position.Y + (TgtTr.Position.Y - CamTr.Position.Y) * Cam.FollowSpeed * ADelta;
      end;
   end;

   { ── Clamp nos limites do mundo ──────────────────────────────────────
     Divide pelo Zoom para converter pixels de tela em unidades de mundo. }
   if Cam.UseBounds then
   begin
      HalfWW := HalfW / Cam.Zoom;
      HalfHW := HalfH / Cam.Zoom;

      if CamTr.Position.X < Cam.Bounds.X + HalfWW then
         CamTr.Position.X := Cam.Bounds.X + HalfWW;
      if CamTr.Position.Y < Cam.Bounds.Y + HalfHW then
         CamTr.Position.Y := Cam.Bounds.Y + HalfHW;
      if CamTr.Position.X > Cam.Bounds.Right  - HalfWW then
         CamTr.Position.X := Cam.Bounds.Right  - HalfWW;
      if CamTr.Position.Y > Cam.Bounds.Bottom - HalfHW then
         CamTr.Position.Y := Cam.Bounds.Bottom - HalfHW;
   end;

   { ── Atualiza câmera raylib ──────────────────────────────────────────── }
   Cam.RaylibCamera.Target.X := CamTr.Position.X;
   Cam.RaylibCamera.Target.Y := CamTr.Position.Y;
   Cam.RaylibCamera.Offset.X := HalfW;
   Cam.RaylibCamera.Offset.Y := HalfH;
   Cam.RaylibCamera.Zoom     := Cam.Zoom;
end;

procedure TCameraSystem.BeginCameraMode;
var
   Cam: TCamera2DComponent;
begin
   if not Assigned(FCamEntity) then
      Exit;
   Cam := TCamera2DComponent(FCamEntity.GetComponentByID(FCameraID));
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
   FillChar(Result, SizeOf(Result), 0);
   Result.Zoom := 1;
   if not Assigned(FCamEntity) then
      Exit;
   Cam := TCamera2DComponent(FCamEntity.GetComponentByID(FCameraID));
   if Assigned(Cam) then
      Result := Cam.RaylibCamera;
end;

end.
