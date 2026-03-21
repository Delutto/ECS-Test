unit P2D.Components.ParallaxLayer;

{$mode objfpc}{$H+}

{ ─────────────────────────────────────────────────────────────────────────────
  TParallaxLayerComponent2D — horizontal/vertical parallax scrolling layer.

  DESIGN
  ──────
  • Each parallax layer entity carries:
      - A TTransformComponent (base world position + rendering anchor)
      - A TSpriteComponent (the background texture to tile)
      - This TParallaxLayerComponent2D (scroll factors + tiling config)

  • TParallaxSystem2D reads the camera's world position every frame and
    recomputes the draw offset:
        DrawOffsetX = CameraX * ScrollFactorX
        DrawOffsetY = CameraY * ScrollFactorY

  • TileH / TileV flags control whether the texture is tiled horizontally
    and/or vertically to cover the full screen without gaps.

  • ZOrder on TSpriteComponent controls depth:
      Z=-10 → far background; Z=-1 → near background; Z=0 → tilemap.
  ───────────────────────────────────────────────────────────────────────────── }

interface

uses
   P2D.Core.Component;

type
   TParallaxLayerComponent2D = class(TComponent2D)
   public
      ScrollFactorX: Single;  // 0.0=fixed, 0.5=half speed, 1.0=moves with camera
      ScrollFactorY: Single;
      TileH        : Boolean; // tile texture horizontally
      TileV        : Boolean; // tile texture vertically
      constructor Create; override;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TParallaxLayerComponent2D.Create;
begin
   inherited Create;

   ScrollFactorX := 0.3;  // slow-moving background default
   ScrollFactorY := 0.0;  // typically no vertical scroll in platformers
   TileH         := True;
   TileV         := False;
end;

initialization
   ComponentRegistry.Register(TParallaxLayerComponent2D);

end.
