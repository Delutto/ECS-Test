unit P2D.Systems.Camera;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math, raylib,
   P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
   P2D.Components.Transform, P2D.Components.Camera2D,
   Mario.Components.Player;

type
   TCameraSystem = class(TSystem2D)
   private
      FCamEntity: TEntity;
      FTarget   : TEntity;
      FScreenW  : Integer;
      FScreenH  : Integer;
   public
      constructor Create(AWorld: TWorldBase; AScreenW, AScreenH: Integer); reintroduce;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure BeginCameraMode;
      procedure EndCameraMode;
      function  GetRaylibCamera: TCamera2D;
   end;

implementation

constructor TCameraSystem.Create(AWorld: TWorldBase; AScreenW, AScreenH: Integer);
begin
   inherited Create(AWorld);

   Priority := 15;
   Name     := 'CameraSystem';
   FScreenW := AScreenW;
   FScreenH := AScreenH;
end;

procedure TCameraSystem.Init;
var
   E: TEntity;
begin
   inherited;

 { Define assinatura para que o cache saiba filtrar câmeras e players.
   O Update usa FCamEntity/FTarget diretamente — GetMatchingEntities é usado apenas aqui no Init para localizar as entidades. }
   RequireComponent(TTransformComponent);

   FCamEntity := nil;
   FTarget    := nil;
   for E in GetMatchingEntities do
   begin
      if {E.Alive and }E.HasComponent(TCamera2DComponent) then
      begin
         FCamEntity := E;
         Break;
      end;
   end;
   for E in GetMatchingEntities do
   begin
      if {E.Alive and }E.HasComponent(TPlayerTag) then
      begin
         FTarget := E;
         Break;
      end;
   end;
end;

procedure TCameraSystem.Update(ADelta: Single);
var
   Cam   : TCamera2DComponent;
   CamTr : TTransformComponent;
   TgtTr : TTransformComponent;
   HalfW : Single;
   HalfH : Single;
   HalfWW: Single; // metade da viewport em unidades do MUNDO (HalfW / Zoom)
   HalfHW: Single; // metade da viewport em unidades do MUNDO (HalfH / Zoom)
begin
   if not Assigned(FCamEntity) then
      Exit;

   Cam   := TCamera2DComponent(FCamEntity.GetComponent(TCamera2DComponent));
   CamTr := TTransformComponent(FCamEntity.GetComponent(TTransformComponent));

   if not Assigned(Cam) or not Assigned(CamTr) then
      Exit;

   HalfW := FScreenW / 2;
   HalfH := FScreenH / 2;

   { ── Smooth follow ──────────────────────────────────────────────────── }
   if Assigned(FTarget) and FTarget.Alive then
   begin
      TgtTr := TTransformComponent(FTarget.GetComponent(TTransformComponent));
      if Assigned(TgtTr) then
      begin
         CamTr.Position.X := CamTr.Position.X + (TgtTr.Position.X - CamTr.Position.X) * Cam.FollowSpeed * ADelta;
         CamTr.Position.Y := CamTr.Position.Y + (TgtTr.Position.Y - CamTr.Position.Y) * Cam.FollowSpeed * ADelta;
      end;
   end;

   { ── Clamp nos limites do mundo ──────────────────────────────────────
    HalfW e HalfH são pixels de TELA.
    O target da câmera opera em coordenadas de MUNDO.
    A metade visível em mundo = HalfScreen / Zoom.
    Divide pelo Zoom para converter tela → mundo. }
   if Cam.UseBounds then
   begin
      HalfWW := HalfW / Cam.Zoom; // ex: 400 / 3.0 ≈ 133 unidades de mundo
      HalfHW := HalfH / Cam.Zoom; // ex: 240 / 3.0 =  80 unidades de mundo

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
   FillChar(Result, SizeOf(Result), 0);
   Result.Zoom := 1;
   if not Assigned(FCamEntity) then
      Exit;
   Cam := TCamera2DComponent(FCamEntity.GetComponent(TCamera2DComponent));
   if Assigned(Cam) then
      Result := Cam.RaylibCamera;
end;

end.
