unit P2D.Systems.Render;

{$mode objfpc}
{$H+}

interface

uses
   SysUtils,
   Math,
   raylib,
   P2D.Core.ComponentRegistry,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Components.Transform,
   P2D.Components.Sprite;

type
   { TRenderSystem }
   TRenderSystem = class(TSystem2D)
   private
      FTSpriteID: Integer;
      FTransformID: Integer;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Update(ADelta: Single); override;
      procedure Render; override;
   end;

implementation

constructor TRenderSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 100;
   Name := 'RenderSystem';
end;

procedure TRenderSystem.Init;
begin
   inherited;

   RequireComponent(TSpriteComponent);
   RequireComponent(TTransformComponent);

   FTSpriteID := ComponentRegistry.GetComponentID(TSpriteComponent);
   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
end;

procedure TRenderSystem.Update(ADelta: Single);
begin

end;

procedure TRenderSystem.Render;
var
   E: TEntity;
   Tr: TTransformComponent;
   Spr: TSpriteComponent;
   Src: TRectangle;
   Dst: TRectangle;
   Org: TVector2;
   ScX: Single;
   TexColor: TColor;
begin
   for E In GetMatchingEntities do
   begin
      Spr := TSpriteComponent(E.GetComponentByID(FTSpriteID));
      Tr := TTransformComponent(E.GetComponentByID(FTransformID));

      if Not Assigned(Spr) Or Not Assigned(Tr) then
      begin
         Continue
      end;

      if Not (Spr.Enabled And Tr.Enabled And Spr.Visible) then
      begin
         Continue
      end;
      if Spr.Texture.Id = 0 then
      begin
         Continue
      end;

      Src := Spr.SourceRect;

      // Apply flip
      ScX := 1;
      if Spr.Flip In [flHorizontal, flBoth] then
      begin
         ScX := -1
      end;
      Src.Width := Src.Width * ScX;

      Dst.X := Tr.Position.X;
      Dst.Y := Tr.Position.Y;
      Dst.Width := Abs(Src.Width) * Tr.Scale.X;
      Dst.Height := Abs(Src.Height) * Tr.Scale.Y;

      Org.X := Spr.Origin.X * Tr.Scale.X;
      Org.Y := Spr.Origin.Y * Tr.Scale.Y;

      TexColor.Create(Spr.Tint.R, Spr.Tint.G, Spr.Tint.B, Spr.Tint.A);
      DrawTexturePro(Spr.Texture, Src, Dst, Org, Tr.Rotation, TexColor);
   end;
end;

end.
