unit P2D.Systems.Text;

{$mode objfpc}
{$H+}

{ Renders all entities carrying TTextComponent2D + TTransformComponent.
  Works on both rlWorld (floating score labels) and rlScreen (HUD labels).
  Set RenderLayer on the system instance to match your use-case. }

interface

uses
   SysUtils,
   raylib,
   P2D.Core.ComponentRegistry,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Core.ResourceManager,
   P2D.Components.Transform,
   P2D.Components.Text;

type
   TTextSystem2D = class(TSystem2D)
   private
      FTextID: Integer;
      FTransformID: Integer;

      function GetFont(const AKey: String; ASize: Single): TFont;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Render; override;
   end;

implementation

constructor TTextSystem2D.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 110;       // after ZOrderRenderSystem (100)
   Name := 'TextSystem';
   RenderLayer := rlWorld;   // caller can override to rlScreen for HUD labels
end;

function TTextSystem2D.GetFont(const AKey: String; ASize: Single): TFont;
begin
   if AKey = '' then
   begin
      Result := GetFontDefault
   end
   else
   begin
      Result := TResourceManager2D.Instance.LoadFont(AKey, Round(ASize))
   end;
end;

procedure TTextSystem2D.Init;
begin
   inherited;

   RequireComponent(TTextComponent2D);
   RequireComponent(TTransformComponent);
   FTextID := ComponentRegistry.GetComponentID(TTextComponent2D);
   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
end;

procedure TTextSystem2D.Render;
var
   E: TEntity;
   TC: TTextComponent2D;
   Tr: TTransformComponent;
   F: TFont;
   Pos: TVector2;
   Sz: TVector2;
   OffX: Single;
begin
   for E In GetMatchingEntities do
   begin
      TC := TTextComponent2D(E.GetComponentByID(FTextID));
      Tr := TTransformComponent(E.GetComponentByID(FTransformID));

      if Not Assigned(TC) Or Not Assigned(Tr) then
      begin
         Continue
      end;
      if Not (TC.Enabled And Tr.Enabled) then
	     begin
         Continue
      end;
      if TC.Text = '' then
	     begin
         Continue
      end;

      F := GetFont(TC.FontKey, TC.FontSize);
      Sz := MeasureTextEx(F, Pchar(TC.Text), TC.FontSize, TC.Spacing);

    // Horizontal alignment
      case TC.Alignment of
         taCenter:
         begin
            OffX := -Sz.X * 0.5
         end;
         taRight:
         begin
            OffX := -Sz.X
         end;
         else
         begin
            OffX := 0
         end;
      end;

      Pos.X := Tr.Position.X + OffX;
      Pos.Y := Tr.Position.Y;

    // Optional drop shadow (1-pixel offset)
      if TC.Shadow then
      begin
         Pos.X := Pos.X + 1;
         Pos.Y := Pos.Y + 1;
         DrawTextEx(F, Pchar(TC.Text), Pos, TC.FontSize, TC.Spacing, TC.ShadowColor);
         Pos.X := Pos.X - 1;
         Pos.Y := Pos.Y - 1;
      end;

      DrawTextEx(F, Pchar(TC.Text), Pos, TC.FontSize, TC.Spacing, TC.Color);
   end;
end;

end.
