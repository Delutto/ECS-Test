unit P2D.Systems.Parallax;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, raylib,
  P2D.Core.ComponentRegistry,
  P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.Sprite,
  P2D.Components.ParallaxLayer, P2D.Components.Camera2D;

type
  { TParallaxSystem2D
    Renders all parallax-layer entities using tiled DrawTexturePro calls,
    offset by (CameraX * ScrollFactorX, CameraY * ScrollFactorY).

    RenderLayer = rlWorld so it participates in BeginMode2D. However,
    because the offset is already in screen space (after accounting for
    the camera matrix) the system uses a NEGATIVE camera offset to render
    the background at the apparent camera-relative position.

    Priority = 29 — just before TTileMapSystem (30) so backgrounds are
    drawn behind tiles. }
  TParallaxSystem2D = class(TSystem2D)
  private
    FParallaxID : Integer;
    FSpriteID   : Integer;
    FTransformID: Integer;
    FCameraID   : Integer;
    FCamEntity  : TEntity;

    FScreenW: Integer;
    FScreenH: Integer;
  public
    constructor Create(AWorld: TWorldBase; AScreenW, AScreenH: Integer); reintroduce;
    procedure Init; override;
    procedure Render; override;
  end;

implementation

constructor TParallaxSystem2D.Create(AWorld: TWorldBase; AScreenW, AScreenH: Integer);
begin
  inherited Create(AWorld);
  
  Priority    := 29;
  Name        := 'ParallaxSystem';
  RenderLayer := rlWorld;
  FScreenW    := AScreenW;
  FScreenH    := AScreenH;
  FCamEntity  := nil;
end;

procedure TParallaxSystem2D.Init;
var
  E: TEntity;
begin
  inherited;

  RequireComponent(TParallaxLayerComponent2D);
  RequireComponent(TSpriteComponent);
  RequireComponent(TTransformComponent);

  FParallaxID  := ComponentRegistry.GetComponentID(TParallaxLayerComponent2D);
  FSpriteID    := ComponentRegistry.GetComponentID(TSpriteComponent);
  FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
  FCameraID    := ComponentRegistry.GetComponentID(TCamera2DComponent);

  // Locate camera entity
  FCamEntity := nil;
  for E in World.Entities.GetAll do
    if E.HasComponent(TCamera2DComponent) then
    begin
      FCamEntity := E;
      Break;
    end;
end;

procedure TParallaxSystem2D.Render;
var
  E        : TEntity;
  PL       : TParallaxLayerComponent2D;
  Spr      : TSpriteComponent;
  Tr       : TTransformComponent;
  Cam      : TCamera2DComponent;
  CamX     : Single;
  CamY     : Single;
  OffX     : Single;
  OffY     : Single;
  DrawX    : Single;
  DrawY    : Single;
  RepeatX  : Integer;
  RepeatXI : Integer;
  TexW     : Integer;
  TexH     : Integer;
  Src      : TRectangle;
  Dst      : TRectangle;
begin
  // Resolve camera position once
  CamX := 0; CamY := 0;
  if Assigned(FCamEntity) and FCamEntity.Alive then
  begin
    Cam  := TCamera2DComponent(FCamEntity.GetComponentByID(FCameraID));
    if Assigned(Cam) then
    begin
      CamX := Cam.RaylibCamera.Target.X;
      CamY := Cam.RaylibCamera.Target.Y;
    end;
  end;

  for E in GetMatchingEntities do
  begin
    PL  := TParallaxLayerComponent2D(E.GetComponentByID(FParallaxID));
    Spr := TSpriteComponent(E.GetComponentByID(FSpriteID));
    Tr  := TTransformComponent(E.GetComponentByID(FTransformID));

    if not (PL.Enabled and Spr.Enabled and Tr.Enabled) then
	  Continue;
    if Spr.Texture.Id = 0 then
	  Continue;

    TexW := Spr.Texture.Width;
    TexH := Spr.Texture.Height;

    // Compute scroll offset in screen/world space
    OffX := -(CamX * PL.ScrollFactorX);
    OffY := -(CamY * PL.ScrollFactorY);

    // Wrap horizontally so the texture tiles seamlessly
    if PL.TileH and (TexW > 0) then
      OffX := OffX - Floor(OffX / TexW) * TexW;

    // Source = full texture
    Src.X      := 0; Src.Y := 0;
    Src.Width  := TexW;
    Src.Height := TexH;

    // Draw enough copies to fill the screen width
    RepeatX := 1;
    if PL.TileH and (TexW > 0) then
      RepeatX := Ceil((FScreenW / TexW)) + 2;

    DrawY := Tr.Position.Y + OffY;

    for RepeatXI := 0 to RepeatX - 1 do
    begin
      DrawX       := Tr.Position.X + OffX + RepeatXI * TexW - TexW;
      Dst.X       := DrawX;
      Dst.Y       := DrawY;
      Dst.Width   := TexW * Tr.Scale.X;
      Dst.Height  := TexH * Tr.Scale.Y;
      DrawTexturePro(Spr.Texture, Src, Dst,
                     Vector2Create(0, 0), 0,
                     ColorCreate(Spr.Tint.R, Spr.Tint.G, Spr.Tint.B, Spr.Tint.A));
    end;
  end;
end;

end.
