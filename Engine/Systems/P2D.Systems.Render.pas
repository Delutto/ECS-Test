unit P2D.Systems.Render;


{$mode objfpc}{$H+}

interface
uses
	SysUtils, Math, raylib, P2D.Core.Types, P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
     P2D.Components.Transform, P2D.Components.Sprite;
	 
type
  TRenderSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorld); override;
    procedure Update(ADelta: Single); override;
    procedure Render; override;
  end;
  
implementation

constructor TRenderSystem.Create(AWorld: TWorld);
begin
	inherited Create(AWorld);
	Priority := 100;
	Name := 'RenderSystem';
end;

procedure TRenderSystem.Update(ADelta: Single);
begin

end;

procedure TRenderSystem.Render;
var
	E: TEntity;
	Tr: TTransformComponent;
	Spr: TSpriteComponent;
    Src, Dst: TRectangle;
	Org: TVector2;
	ScX: Single;
begin
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then
		Continue;
    if not E.HasComponent(TSpriteComponent) then
		Continue;
    if not E.HasComponent(TTransformComponent) then
		Continue;
    Spr := TSpriteComponent(E.GetComponent(TSpriteComponent));
    Tr := TTransformComponent(E.GetComponent(TTransformComponent));
    if not(Spr.Enabled and Tr.Enabled and Spr.Visible) then
		Continue;
    if Spr.Texture.Id = 0 then
		Continue;
    Src := Spr.SourceRect;
	ScX := 1;
    if Spr.Flip in[flHorizontal,flBoth] then
		ScX := -1;
    Src.Width := Src.Width * ScX;
    Dst.X := Tr.Position.X;
	Dst.Y := Tr.Position.Y;
    Dst.Width := Abs(Src.Width) * Tr.Scale.X;
	Dst.Height := Abs(Src.Height) * Tr.Scale.Y;
    Org.X := Spr.Origin.X * Tr.Scale.X;
	Org.Y := Spr.Origin.Y * Tr.Scale.Y;
    DrawTexturePro(Spr.Texture,Src,Dst,Org,Tr.Rotation, RayColor(Spr.Tint.R,Spr.Tint.G,Spr.Tint.B,Spr.Tint.A));
  end;
end;
end.