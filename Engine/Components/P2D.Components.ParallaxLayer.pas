unit P2D.Components.ParallaxLayer;

{$mode objfpc}{$H+}

{ =============================================================================
  TParallaxLayerComponent2D

  IMPORTANT: this component stores the texture reference directly so that
  TParallaxSystem2D does NOT need TSpriteComponent.
  If the parallax entity also carried TSpriteComponent, TRenderSystem would
  match it and render the full-resolution texture in world space (inside
  BeginMode2D), multiplied by the camera zoom — producing a giant rectangle
  that covers the tilemap. Keeping the texture here avoids that conflict.
  ============================================================================= }

interface

uses
   raylib,
   P2D.Core.Component;

type
   TParallaxLayerComponent2D = class(TComponent2D)
   public
      { Texture to tile across the background.
      Non-owning reference — the texture is managed externally
      (e.g. by TResourceManager2D or a global ProceduralArt variable). }
      Texture: TTexture2D;

      { Colour modulation applied to every draw call (WHITE = no tint). }
      Tint: TColor;

      { Scroll factors: 0.0 = fixed on screen, 1.0 = moves with the camera.
      Values between 0 and 1 create the parallax depth illusion.
      Note: because the tilemap is drawn inside BeginMode2D with zoom=3,
      a parallax ScrollFactorX of 0.3 gives a visual speed of 0.3/3 = 10%
      of the tilemap's apparent speed. }
      ScrollFactorX: Single;
      ScrollFactorY: Single;

      { When True, the texture is tiled horizontally / vertically to fill
      the virtual canvas without gaps regardless of camera travel. }
      TileH: boolean;
      TileV: boolean;

      { Draw order among parallax layers.
      Lower ZOrder → drawn first → visually further away.
      TParallaxSystem2D sorts entities by this value before rendering. }
      ZOrder: Integer;

      constructor Create; override;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TParallaxLayerComponent2D.Create;
begin
   inherited Create;

   FillChar(Texture, SizeOf(Texture), 0);
   Tint := WHITE;
   ScrollFactorX := 0.3;
   ScrollFactorY := 0.0;
   TileH := True;
   TileV := False;
   ZOrder := 0;
end;

initialization
   ComponentRegistry.Register(TParallaxLayerComponent2D);

end.
