unit P2D.Systems.ZOrderRender;

{$mode objfpc}{$H+}

interface

uses
   SysUtils,
   fgl,
   raylib,
   P2D.Core.ComponentRegistry,
   P2D.Core.Types,
   P2D.Core.Entity,
   P2D.Core.System,
   P2D.Core.World,
   P2D.Components.Transform,
   P2D.Components.Sprite;

type
   // ── Internal sorting pair ─────────────────────────────────────────────────
   TZEntry = record
      Entity: TEntity;
      ZOrder: Integer;
   end;
   TZEntryArray = array of TZEntry;

   // ── System ────────────────────────────────────────────────────────────────
   TZOrderRenderSystem = class(TSystem2D)
   private
      FSpriteID: Integer;
      FTransformID: Integer;
      FZBuffer: TZEntryArray;
      FZCount: Integer;

      procedure GrowZBuffer(AMinSize: Integer);
      procedure SortZBuffer;
   public
      constructor Create(AWorld: TWorldBase); override;
      procedure Init; override;
      procedure Render; override;
   end;

implementation

 // ─────────────────────────────────────────────────────────────────────────────
 //  Insertion sort — O(n log n) average on nearly-sorted data (typical for ECS
 //  where entities are created roughly in Z order). Stable: same-Z entities keep
 //  their relative creation order from the ECS cache.
 // ─────────────────────────────────────────────────────────────────────────────
procedure TZOrderRenderSystem.SortZBuffer;
var
   I, J: Integer;
   Tmp: TZEntry;
begin
   for I := 1 to FZCount - 1 do
   begin
      Tmp := FZBuffer[I];
      J := I - 1;
      while (J >= 0) and (FZBuffer[J].ZOrder > Tmp.ZOrder) do
      begin
         FZBuffer[J + 1] := FZBuffer[J];
         Dec(J);
      end;
      FZBuffer[J + 1] := Tmp;
   end;
end;

procedure TZOrderRenderSystem.GrowZBuffer(AMinSize: Integer);
var
   NewCap: Integer;
begin
   if Length(FZBuffer) >= AMinSize then
   begin
      Exit;
   end;
   NewCap := AMinSize * 2;
   SetLength(FZBuffer, NewCap);
end;

// ─────────────────────────────────────────────────────────────────────────────
constructor TZOrderRenderSystem.Create(AWorld: TWorldBase);
begin
   inherited Create(AWorld);

   Priority := 100;
   Name := 'ZOrderRenderSystem';
   SetLength(FZBuffer, 64);
   FZCount := 0;
end;

procedure TZOrderRenderSystem.Init;
begin
   inherited;

   RequireComponent(TSpriteComponent);
   RequireComponent(TTransformComponent);
   FSpriteID := ComponentRegistry.GetComponentID(TSpriteComponent);
   FTransformID := ComponentRegistry.GetComponentID(TTransformComponent);
end;

procedure TZOrderRenderSystem.Render;
var
   E: TEntity;
   Spr: TSpriteComponent;
   Tr: TTransformComponent;
   I: Integer;
   Src: TRectangle;
   Dst: TRectangle;
   Org: TVector2;
   ScX: Single;
begin
   // ── Phase 1: populate & sort Z-buffer ─────────────────────────────────────
   FZCount := 0;
   for E in GetMatchingEntities do
   begin
      Spr := TSpriteComponent(E.GetComponentByID(FSpriteID));
      if not (Spr.Enabled and Spr.Visible) then
      begin
         Continue;
      end;
      if Spr.Texture.Id = 0 then
      begin
         Continue;
      end;

      GrowZBuffer(FZCount + 1);
      FZBuffer[FZCount].Entity := E;
      FZBuffer[FZCount].ZOrder := Spr.ZOrder;
      Inc(FZCount);
   end;

   if FZCount = 0 then
   begin
      Exit;
   end;
   SortZBuffer;

   // ── Phase 2: draw in Z order ───────────────────────────────────────────────
   for I := 0 to FZCount - 1 do
   begin
      E := FZBuffer[I].Entity;
      Spr := TSpriteComponent(E.GetComponentByID(FSpriteID));
      Tr := TTransformComponent(E.GetComponentByID(FTransformID));

      if not (Tr.Enabled) then
      begin
         Continue;
      end;

      Src := Spr.SourceRect;
      ScX := 1;
      if Spr.Flip in [flHorizontal, flBoth] then
      begin
         ScX := -1;
      end;
      Src.Width := Src.Width * ScX;

      Dst.X := Tr.Position.X;
      Dst.Y := Tr.Position.Y;
      Dst.Width := Abs(Src.Width) * Tr.Scale.X;
      Dst.Height := Abs(Src.Height) * Tr.Scale.Y;

      Org.X := Spr.Origin.X * Tr.Scale.X;
      Org.Y := Spr.Origin.Y * Tr.Scale.Y;

      DrawTexturePro(Spr.Texture, Src, Dst, Org, Tr.Rotation, ColorCreate(Spr.Tint.R, Spr.Tint.G, Spr.Tint.B, Spr.Tint.A));
   end;
end;

end.
