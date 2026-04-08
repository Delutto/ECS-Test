unit Terraria.LiquidRender;

{$mode objfpc}{$H+}

{ Renders water and lava from TLiquidSimulator.WaterMap / LavaMap.
  Uses only PUBLIC API: TLiqLevelMap.FindChunk, TLiqLevelChunk.Data/HasLiquid. }

interface

uses
   SysUtils, Math, raylib,
   Terraria.Common,
   Terraria.WorldChunk,
   Terraria.ChunkManager,
   Terraria.Lighting,
   Terraria.Liquid,
   Terraria.LiquidSim;

type
   TLiquidRenderer = class
   private
      FParams: PLiquidParams;
      FLightMap: TLightMap;
      FSim: TLiquidSimulator;

      function VisualFor(ATile: byte): TLiquidVisual;
      function TileHash(WX, WY: Integer): Single; inline;
      procedure DrawLiquidQuad(WX, WY: Integer; PX, PY, PH: Single; IsSurface: boolean; const AVis: TLiquidVisual);
   public
      constructor Create(AParams: PLiquidParams; ALightMap: TLightMap; ASim: TLiquidSimulator);

      procedure RenderChunk(AChunk: TWorldChunk);

      property Params: PLiquidParams read FParams write FParams;
      property LightMap: TLightMap read FLightMap write FLightMap;
      property Sim: TLiquidSimulator read FSim write FSim;
   end;

implementation

function TLiquidRenderer.VisualFor(ATile: byte): TLiquidVisual;
begin
   case ATile of
      TILE_WATER:
         Result := FParams^.WaterVisual;
      TILE_LAVA:
         Result := FParams^.LavaVisual;
      else
         FillChar(Result, SizeOf(Result), 0);
   end;
end;

function TLiquidRenderer.TileHash(WX, WY: Integer): Single;
var
   H: cardinal;
begin
   H := cardinal(WX) * 1664525 xor cardinal(WY) * 22695477;
   H := H xor (H shr 16);
   Result := (H and $FFFF) / 65535.0 * 6.2831853;
end;

procedure TLiquidRenderer.DrawLiquidQuad(WX, WY: Integer; PX, PY, PH: Single; IsSurface: boolean; const AVis: TLiquidVisual);
const
   TWO_PI = 6.2831853;
var
   T, Hash, RipOff, AlphaMod: Single;
   FinalAlpha, TR, TG, TB: Integer;
   Light: TRGBLight;
   DrawCol, SurfCol: TColor;
begin
   if AVis.Alpha = 0 then
      Exit;
   T := GetTime;
   Hash := TileHash(WX, WY);
   if IsSurface and (AVis.Anim.RippleSpeed > 0) then
   begin
      RipOff := Sin(T * AVis.Anim.RippleSpeed * TWO_PI + Hash) * AVis.Anim.RippleAmp;
      PY := PY + RipOff;
      PH := PH - RipOff;
      if PH < 1.0 then
         PH := 1.0;
   end;
   AlphaMod := 1.0;
   if AVis.Anim.FlickerSpeed > 0 then
      AlphaMod := 1.0 + Sin(T * AVis.Anim.FlickerSpeed * TWO_PI + Hash * 0.73) * AVis.Anim.FlickerAmp;
   FinalAlpha := Round(AVis.Alpha * AlphaMod);
   if FinalAlpha < 0 then
      FinalAlpha := 0;
   if FinalAlpha > 255 then
      FinalAlpha := 255;
   if Assigned(FLightMap) and FLightMap.Settings.Enabled then
   begin
      Light := FLightMap.GetLight(WX, WY);
      TR := Round(AVis.R * Light.R / 255);
      TG := Round(AVis.G * Light.G / 255);
      TB := Round(AVis.B * Light.B / 255);
   end
   else
   begin
      TR := AVis.R;
      TG := AVis.G;
      TB := AVis.B;
   end;
   if TR > 255 then
      TR := 255;
   if TG > 255 then
      TG := 255;
   if TB > 255 then
      TB := 255;
   DrawCol := ColorCreate(byte(TR), byte(TG), byte(TB), byte(FinalAlpha));
   DrawRectangleRec(RectangleCreate(PX, PY, TILE_SIZE, PH), DrawCol);
   if IsSurface then
   begin
      SurfCol := ColorCreate(byte(Min(255, TR + 50)), byte(Min(255, TG + 50)), byte(Min(255, TB + 50)), byte(Min(255, FinalAlpha + 30)));
      DrawRectangleRec(RectangleCreate(PX, PY, TILE_SIZE, 1.0), SurfCol);
   end;
end;

constructor TLiquidRenderer.Create(AParams: PLiquidParams; ALightMap: TLightMap; ASim: TLiquidSimulator);
begin
   inherited Create;
   FParams := AParams;
   FLightMap := ALightMap;
   FSim := ASim;
end;

procedure TLiquidRenderer.RenderChunk(AChunk: TWorldChunk);
var
   LX, LY, WX, WY: Integer;
   BaseWX, BaseWY, PX, PY, PH: Single;
   WaterLevel, LavaLevel: Integer;
   WaterAbove, LavaAbove: boolean;
   WVis, LVis: TLiquidVisual;
   { FindChunk is PUBLIC in TLiqLevelMap — no visibility issue. }
   WaterChunk: TLiqLevelChunk;
   LavaChunk: TLiqLevelChunk;
begin
   if not Assigned(FParams) or not Assigned(FSim) then
      Exit;

   { Quick early-out: skip chunk if neither map has liquid here. }
   WaterChunk := FSim.WaterMap.FindChunk(AChunk.CX, AChunk.CY);
   LavaChunk := FSim.LavaMap.FindChunk(AChunk.CX, AChunk.CY);
   if (not Assigned(WaterChunk) or not WaterChunk.HasLiquid) and (not Assigned(LavaChunk) or not LavaChunk.HasLiquid) then
      Exit;

   BaseWX := AChunk.CX * CHUNK_PIXEL_W;
   BaseWY := AChunk.CY * CHUNK_PIXEL_H;
   WVis := FParams^.WaterVisual;
   LVis := FParams^.LavaVisual;

   for LY := 0 to CHUNK_TILES_H - 1 do
      for LX := 0 to CHUNK_TILES_W - 1 do
      begin
         { Read levels directly from chunk Data arrays — O(1), no hash lookup. }
         WaterLevel := 0;
         LavaLevel := 0;
         if Assigned(WaterChunk) then
            WaterLevel := WaterChunk.Data[LY][LX];
         if Assigned(LavaChunk) then
            LavaLevel := LavaChunk.Data[LY][LX];
         if (WaterLevel = 0) and (LavaLevel = 0) then
            Continue;

         WX := TChunkManager.ChunkToTileX(AChunk.CX) + LX;
         WY := TChunkManager.ChunkToTileY(AChunk.CY) + LY;
         PX := BaseWX + LX * TILE_SIZE;

         { Lava (lower layer) }
         if LavaLevel > 0 then
         begin
            PH := LavaLevel * TILE_SIZE / LIQ_MAX;
            if PH < 1.0 then
               PH := 1.0;
            PY := BaseWY + LY * TILE_SIZE + (TILE_SIZE - PH);
            LavaAbove := (LY > 0) and Assigned(LavaChunk) and (LavaChunk.Data[LY - 1][LX] > 0);
            DrawLiquidQuad(WX, WY, PX, PY, PH, not LavaAbove, LVis);
         end;

         { Water (top layer) }
         if WaterLevel > 0 then
         begin
            PH := WaterLevel * TILE_SIZE / LIQ_MAX;
            if PH < 1.0 then
               PH := 1.0;
            PY := BaseWY + LY * TILE_SIZE + (TILE_SIZE - PH);
            WaterAbove := (LY > 0) and Assigned(WaterChunk) and (WaterChunk.Data[LY - 1][LX] > 0);
            DrawLiquidQuad(WX, WY, PX, PY, PH, not WaterAbove, WVis);
         end;
      end;
end;

end.
