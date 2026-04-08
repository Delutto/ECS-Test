unit Terraria.Liquid;

{$mode objfpc}{$H+}

{ =============================================================================
  Terraria.Liquid — Static Liquid Placement System

  PURPOSE
  ───────
  Places water, lava, and mud-water tiles into TWorldChunk data after terrain
  generation and before vegetation/decoration placement. No fluid physics is
  simulated — placement is static, driven by rules and per-biome parameters.

  THREE PLACEMENT PASSES (all O(n) in the number of chunk tiles)
  ──────────────────────────────────────────────────────────────
  1. SURFACE LAKES (water / mud-water)
       Detects closed surface depressions by scanning the local surface-Y
       profile of the chunk and its immediate neighbours.
       A depression is a contiguous sequence of columns whose surface Y is
       strictly deeper (higher row-index) than at least one column on each
       side. The water level is set to the MINIMUM of the two boundary
       surface-Y values so water never spills over the depression lip.

  2. UNDERGROUND LAKES (water / mud-water, biome-driven)
       Scans cave air pockets below the surface. For each air cell that has a
       solid tile directly above it (i.e. the bottom of an air column), the
       algorithm floods downward while the tile stays air, collecting the
       cavity. A random fraction of the cavity height (FillRatio) is then
       filled with liquid from the bottom up.

  3. LAVA POOLS (deep zone, world-bottom)
       Any air cell whose world-Y coordinate is >= LavaStartY (default: 80 %
       of map height) is replaced with lava regardless of biome. Lava pools
       spread horizontally because the deep stone layer naturally forms large
       flat cavities carved by the cave system.

  DEPRESSION DETECTION DETAIL
  ───────────────────────────
  For each local column X in the chunk we compute:
    • SY(X)     – surface Y at that column (world-tile coords)
    • leftMin   – the smallest (highest) SY seen scanning LEFT from X until
                  surface Y starts rising continuously for SCAN_RADIUS steps
    • rightMin  – same scanning RIGHT

  A column X is inside a depression if:
    SY(X) > leftMin  AND  SY(X) > rightMin

  The water line for that column is:  WaterY = Min(leftMin, rightMin)
  so the lake surface is always below or equal to the depression lips.

  If the depression is narrower than MIN_LAKE_WIDTH tiles it is ignored to
  avoid trivially tiny puddles.

  LAVA EMISSIVE LIGHT INTEGRATION
  ─────────────────────────────────
  After placement, TLiquidPlacer.SeedLightEmitters is called by the scene to
  register lava tiles as light emitters in TLightSettings (using the generic
  EmitterTileID slot). This requires no changes to TLightMap.

  PERFORMANCE
  ───────────
  • All three passes are O(W × H) per chunk (W = CHUNK_TILES_W,
    H = CHUNK_TILES_H).
  • Surface scan uses a fixed SCAN_RADIUS look-ahead/look-behind, also O(W).
  • No heap allocations during placement.
  ============================================================================= }

interface

uses
   SysUtils, Math,
   Terraria.Common,
   Terraria.WorldChunk,
   Terraria.ChunkManager,
   Terraria.Noise,
   Terraria.Lighting,
   Terraria.LiquidSim;

{ ---------------------------------------------------------------------------
  TLiquidType — the liquid tile that will be placed in the world
--------------------------------------------------------------------------- }
type
   TLiquidType = (ltNone, ltWater, ltLava, ltMudWater);

{ ---------------------------------------------------------------------------
  TLiquidAnimation — controls per-frame visual animation in the renderer
--------------------------------------------------------------------------- }
   TLiquidAnimation = record
      RippleSpeed: Single;   { oscillations per second for surface ripple  }
      RippleAmp: Single;     { amplitude of ripple Y-offset in pixels      }
      FlickerSpeed: Single;  { alpha flicker frequency (lava / emissive)   }
      FlickerAmp: Single;    { amplitude of alpha flicker [0..1]           }
   end;

{ ---------------------------------------------------------------------------
  TLiquidVisual — colour and opacity of a liquid type
--------------------------------------------------------------------------- }
   TLiquidVisual = record
      R, G, B: byte;    { base colour                               }
      Alpha: byte;      { base opacity [0..255]                     }
      Emissive: boolean;{ if True → seeded as light emitter         }
      EmitBrightness: byte;   { light brightness when Emissive=True       }
      EmitR, EmitG, EmitB: byte; { emitted light colour                   }
      Anim: TLiquidAnimation;
   end;

{ ---------------------------------------------------------------------------
  TLiquidBiomeParams — per-biome liquid configuration
  All fields are exposed for editing through TGenEditor.
--------------------------------------------------------------------------- }
   PLiquidBiomeParams = ^TLiquidBiomeParams;

   TLiquidBiomeParams = record
      { ── Surface lakes ──────────────────────────────────────────────── }
      SurfaceLakeEnabled: boolean;
      SurfaceLakeProb: Single;      { probability [0..1] per depression  }
      SurfaceLakeType: TLiquidType; { liquid tile to place               }
      SurfaceMinDepth: Integer;     { minimum depression depth (tiles)   }
      SurfaceMaxFill: Integer;      { maximum tiles to fill from bottom  }

      { ── Underground lakes ──────────────────────────────────────────── }
      UnderLakeEnabled: boolean;
      UnderLakeProb: Single;     { probability per eligible cavity    }
      UnderLakeType: TLiquidType;
      UnderLakeFillRatio: Single;     { fraction of cavity height to fill  }
      UnderLakeMinWorldY: Integer;    { shallowest world-Y allowed         }

      { ── Lava pools (active near world bottom, shared across biomes) ── }
      LavaEnabled: boolean;
      LavaStartY: Integer;          { world-Y below which lava appears   }
      LavaProb: Single;             { per-cell probability (noise-gated) }
   end;

{ ---------------------------------------------------------------------------
  TLiquidParams — top-level record embedded in TGenParams
--------------------------------------------------------------------------- }
   PLiquidParams = ^TLiquidParams;

   TLiquidParams = record
      Plains: TLiquidBiomeParams;
      Desert: TLiquidBiomeParams;
      Forest: TLiquidBiomeParams;

      WaterVisual: TLiquidVisual;
      LavaVisual: TLiquidVisual;
      MudVisual: TLiquidVisual;
   end;

{ ---------------------------------------------------------------------------
  TLiquidPlacer — places liquid tiles into a single TWorldChunk.
  Instantiate once per generator; call PlaceChunk after each GenerateChunk.
--------------------------------------------------------------------------- }
   TLiquidPlacer = class
   private
      FManager: TChunkManager;
      FParams: PLiquidParams;
      FSimulator: TLiquidSimulator;
      FSeed: longint;

      { Returns the TLiquidBiomeParams for the given biome byte }
      function ParamsForBiome(ABiome: byte): PLiquidBiomeParams;

      { Returns the foreground tile byte for a TLiquidType }
      function LiquidTile(ALT: TLiquidType): byte; inline;

      { Returns the biome at world-tile column TX }
      function BiomeAt(ATX: Integer): byte;

      { World-tile coordinates from chunk + local coords }
      function WorldX(AChunk: TWorldChunk; LX: Integer): Integer; inline;
      function WorldY(AChunk: TWorldChunk; LY: Integer): Integer; inline;

      { True if the FG tile at (LX,LY) is solid terrain (not air, not decor) }
      function IsSolid(AChunk: TWorldChunk; LX, LY: Integer): boolean; inline;

      { Writes ATile to (LX,LY) only if the cell is currently TILE_AIR }
      procedure SetLiquid(AChunk: TWorldChunk; LX, LY: Integer; ATile: byte);

      { Deterministic per-column random in [0..1] using noise.
        ASalt differentiates surface / underground / lava streams. }
      function ColRand(ATX: Integer; ASalt: Integer = 0): Single;

      { ── Sub-passes ──────────────────────────────────────────────────── }

      { Fills one detected surface lake — called by PlaceSurfaceLakes.
        Columns [ALakeStartLX .. ALakeEndLX] are filled from the bottom of
        each depression up to its computed water line. }
      procedure FillSurfaceLake(AChunk: TWorldChunk; ALakeStartLX, ALakeEndLX: Integer; ALakeTile: byte; ABP: PLiquidBiomeParams);

      { Pass 1: scan for and fill surface depressions }
      procedure PlaceSurfaceLakes(AChunk: TWorldChunk);

      { Pass 2: fill cave air pockets below the surface }
      procedure PlaceUndergroundLakes(AChunk: TWorldChunk);

      { Pass 3: fill air cells in the deep zone with lava }
      procedure PlaceLavaPools(AChunk: TWorldChunk);
   public
      constructor Create(AManager: TChunkManager; AParams: PLiquidParams; ASeed: longint; ASimulator: TLiquidSimulator = nil);

      { Main entry point — call once per chunk, after full terrain generation
        (tiles, caves, vegetation) and before lighting computation. }
      procedure PlaceChunk(AChunk: TWorldChunk);

      { Updates TLightSettings so TLightMap seeds emissive liquid tiles
        (currently lava) as block emitters during ComputeLighting.
        Call once after world (re)build, before ComputeLighting. }
      procedure SeedLightEmitters(var ASettings: TLightSettings);

      property Params: PLiquidParams read FParams write FParams;
      property Seed: longint write FSeed;
      property Simulator: TLiquidSimulator read FSimulator write FSimulator;
   end;

   { ---------------------------------------------------------------------------
     Helper: returns the default TLiquidParams (Terraria-like values)
   --------------------------------------------------------------------------- }
function DefaultLiquidParams: TLiquidParams;

const
   { Columns to look left/right when scanning for depression borders }
   SCAN_RADIUS = 20;

   { A depression must span at least this many columns to become a lake }
   MIN_LAKE_WIDTH = 3;

   { A depression must be at least this many rows deep (used as default
     SurfaceMinDepth) }
   MIN_DEPR_DEPTH = 2;

   { Maximum rows to inspect downward in a single underground cavity scan }
   MAX_CAVITY_SCAN = 64;

implementation

{ =============================================================================
  DefaultLiquidParams
  ============================================================================= }

function DefaultLiquidParams: TLiquidParams;
var
   WV, LV, MV: TLiquidVisual;
   PlainsBP, DesertBP, ForestBP: TLiquidBiomeParams;
begin
   { ── Water visual ────────────────────────────────────────────────────── }
   WV.R := 40;
   WV.G := 120;
   WV.B := 200;
   WV.Alpha := 180;
   WV.Emissive := False;
   WV.EmitBrightness := 0;
   WV.EmitR := 0;
   WV.EmitG := 0;
   WV.EmitB := 0;
   WV.Anim.RippleSpeed := 1.2;
   WV.Anim.RippleAmp := 0.6;
   WV.Anim.FlickerSpeed := 0.0;
   WV.Anim.FlickerAmp := 0.0;

   { ── Lava visual ─────────────────────────────────────────────────────── }
   LV.R := 220;
   LV.G := 80;
   LV.B := 20;
   LV.Alpha := 220;
   LV.Emissive := True;
   LV.EmitBrightness := 160;
   LV.EmitR := 255;
   LV.EmitG := 140;
   LV.EmitB := 20;
   LV.Anim.RippleSpeed := 0.4;
   LV.Anim.RippleAmp := 0.3;
   LV.Anim.FlickerSpeed := 3.0;
   LV.Anim.FlickerAmp := 0.25;

   { ── Mud-water visual ────────────────────────────────────────────────── }
   MV.R := 80;
   MV.G := 70;
   MV.B := 40;
   MV.Alpha := 200;
   MV.Emissive := False;
   MV.EmitBrightness := 0;
   MV.EmitR := 0;
   MV.EmitG := 0;
   MV.EmitB := 0;
   MV.Anim.RippleSpeed := 0.6;
   MV.Anim.RippleAmp := 0.3;
   MV.Anim.FlickerSpeed := 0.0;
   MV.Anim.FlickerAmp := 0.0;

   { ── Plains ──────────────────────────────────────────────────────────── }
   PlainsBP.SurfaceLakeEnabled := True;
   PlainsBP.SurfaceLakeProb := 0.70;
   PlainsBP.SurfaceLakeType := ltWater;
   PlainsBP.SurfaceMinDepth := MIN_DEPR_DEPTH;
   PlainsBP.SurfaceMaxFill := 8;
   PlainsBP.UnderLakeEnabled := True;
   PlainsBP.UnderLakeProb := 0.55;
   PlainsBP.UnderLakeType := ltWater;
   PlainsBP.UnderLakeFillRatio := 0.40;
   PlainsBP.UnderLakeMinWorldY := 12;
   PlainsBP.LavaEnabled := True;
   PlainsBP.LavaStartY := 200;
   PlainsBP.LavaProb := 0.85;

   { ── Desert ──────────────────────────────────────────────────────────── }
   DesertBP.SurfaceLakeEnabled := False;
   DesertBP.SurfaceLakeProb := 0.0;
   DesertBP.SurfaceLakeType := ltNone;
   DesertBP.SurfaceMinDepth := MIN_DEPR_DEPTH;
   DesertBP.SurfaceMaxFill := 4;
   DesertBP.UnderLakeEnabled := True;
   DesertBP.UnderLakeProb := 0.25;
   DesertBP.UnderLakeType := ltWater;
   DesertBP.UnderLakeFillRatio := 0.25;
   DesertBP.UnderLakeMinWorldY := 20;
   DesertBP.LavaEnabled := True;
   DesertBP.LavaStartY := 200;
   DesertBP.LavaProb := 0.90;

   { ── Forest ──────────────────────────────────────────────────────────── }
   ForestBP.SurfaceLakeEnabled := True;
   ForestBP.SurfaceLakeProb := 0.85;
   ForestBP.SurfaceLakeType := ltMudWater;
   ForestBP.SurfaceMinDepth := MIN_DEPR_DEPTH;
   ForestBP.SurfaceMaxFill := 10;
   ForestBP.UnderLakeEnabled := True;
   ForestBP.UnderLakeProb := 0.65;
   ForestBP.UnderLakeType := ltWater;
   ForestBP.UnderLakeFillRatio := 0.50;
   ForestBP.UnderLakeMinWorldY := 10;
   ForestBP.LavaEnabled := True;
   ForestBP.LavaStartY := 200;
   ForestBP.LavaProb := 0.80;

   Result.Plains := PlainsBP;
   Result.Desert := DesertBP;
   Result.Forest := ForestBP;
   Result.WaterVisual := WV;
   Result.LavaVisual := LV;
   Result.MudVisual := MV;
end;

{ =============================================================================
  TLiquidPlacer — constructor
  ============================================================================= }

constructor TLiquidPlacer.Create(AManager: TChunkManager; AParams: PLiquidParams; ASeed: longint; ASimulator: TLiquidSimulator = nil);
begin
   inherited Create;
   FManager := AManager;
   FParams := AParams;
   FSeed := ASeed;
   FSimulator := ASimulator;
end;

{ =============================================================================
  TLiquidPlacer — inline helpers
  ============================================================================= }

function TLiquidPlacer.ParamsForBiome(ABiome: byte): PLiquidBiomeParams;
begin
   case ABiome of
      BIOME_DESERT:
         Result := @FParams^.Desert;
      BIOME_FOREST:
         Result := @FParams^.Forest;
      else
         Result := @FParams^.Plains;
   end;
end;

function TLiquidPlacer.LiquidTile(ALT: TLiquidType): byte;
begin
   case ALT of
      ltWater:
         Result := TILE_WATER;
      ltLava:
         Result := TILE_LAVA;
      ltMudWater:
         Result := TILE_MUD_WATER;
      else
         Result := TILE_AIR;
   end;
end;

function TLiquidPlacer.BiomeAt(ATX: Integer): byte;
begin
   Result := FManager.GetBiome(ATX);
end;

function TLiquidPlacer.WorldX(AChunk: TWorldChunk; LX: Integer): Integer;
begin
   Result := TChunkManager.ChunkToTileX(AChunk.CX) + LX;
end;

function TLiquidPlacer.WorldY(AChunk: TWorldChunk; LY: Integer): Integer;
begin
   Result := TChunkManager.ChunkToTileY(AChunk.CY) + LY;
end;

function TLiquidPlacer.IsSolid(AChunk: TWorldChunk; LX, LY: Integer): boolean;
var
   T: byte;
begin
   if not AChunk.InLocalBounds(LX, LY) then
   begin
      Result := True;   { treat out-of-bounds as solid border }
      Exit;
   end;
   T := AChunk.GetFG(LX, LY);
   { Air and liquid tiles are NOT solid; everything else (terrain, decor) is }
   Result := (T <> TILE_AIR) and (T < TILE_LIQUID_BOUNDARY);
end;

procedure TLiquidPlacer.SetLiquid(AChunk: TWorldChunk; LX, LY: Integer; ATile: byte);
var
   WX, WY: Integer;
begin
   { Liquid lives in the level maps only — FG tiles stay as terrain. }
   if not AChunk.InLocalBounds(LX, LY) then
      Exit;
   if AChunk.GetFG(LX, LY) <> TILE_AIR then
      Exit;
   if not Assigned(FSimulator) then
      Exit;
   WX := TChunkManager.ChunkToTileX(AChunk.CX) + LX;
   WY := TChunkManager.ChunkToTileY(AChunk.CY) + LY;
   if ATile = TILE_LAVA then
      FSimulator.PlaceLava(WX, WY, LIQ_MAX)
   else
      FSimulator.PlaceWater(WX, WY, LIQ_MAX);
end;

function TLiquidPlacer.ColRand(ATX: Integer; ASalt: Integer): Single;
var
   N: Single;
begin
   { Each salt produces an independent noise stream from the same noise bank }
   N := ValueNoise2D(ATX * 0.37 + FSeed * 0.001, ASalt * 17.3 + FSeed * 0.0013);
   Result := (N + 1.0) * 0.5;   { remap [-1, 1] → [0, 1] }
end;

{ =============================================================================
  Pass 1 helpers
  ============================================================================= }

{ FillSurfaceLake
  ─────────────────────────────────────────────────────────────────────────────
  Fills columns [ALakeStartLX .. ALakeEndLX] of AChunk with ALakeTile.
  For each column the water line is re-computed from its left/right surface
  scan so the lake surface precisely follows the depression boundary.

  Using a dedicated method (instead of inline code in PlaceSurfaceLakes) is
  what eliminates the for-loop variable conflict: FillLX here is completely
  independent of the LX loop variable in the caller.
  ───────────────────────────────────────────────────────────────────────────── }
procedure TLiquidPlacer.FillSurfaceLake(AChunk: TWorldChunk; ALakeStartLX, ALakeEndLX: Integer; ALakeTile: byte; ABP: PLiquidBiomeParams);
var
   FillLX: Integer;   { column iterator — distinct from caller's LX }
   ColWTX, ColSY: Integer;
   ColLeftMin, ColRightMin: Integer;
   ColWaterLine: Integer;
   ColFillRows, ColFillFrom: Integer;
   ColFillTo: Integer;
   ColScanX, ColWTY, ColLY: Integer;
begin
   for FillLX := ALakeStartLX to ALakeEndLX do
   begin
      ColWTX := WorldX(AChunk, FillLX);
      ColSY := FManager.GetSurfaceY(ColWTX);

      { ── Left scan: find the highest (minimum Y) point to the left ───── }
      ColLeftMin := ColSY;
      for ColScanX := ColWTX - SCAN_RADIUS to ColWTX - 1 do
      begin
         ColWTY := FManager.GetSurfaceY(ColScanX);
         if ColWTY < ColLeftMin then
            ColLeftMin := ColWTY;
      end;

      { ── Right scan: find the highest point to the right ──────────────── }
      ColRightMin := ColSY;
      for ColScanX := ColWTX + 1 to ColWTX + SCAN_RADIUS do
      begin
         ColWTY := FManager.GetSurfaceY(ColScanX);
         if ColWTY < ColRightMin then
            ColRightMin := ColWTY;
      end;

      { ── Water line = minimum of the two borders (lowest lip) ─────────── }
      ColWaterLine := Min(ColLeftMin, ColRightMin);

      { ── Compute fill range, clamped to SurfaceMaxFill ─────────────────── }
      ColFillRows := Min(ColSY - ColWaterLine, ABP^.SurfaceMaxFill);
      if ColFillRows <= 0 then
         Continue;

      ColFillTo := ColSY - 1;                    { topmost filled row    }
      ColFillFrom := ColSY - ColFillRows;        { bottommost filled row }

      { ── Write liquid tiles (only into air cells) ─────────────────────── }
      for ColWTY := ColFillFrom to ColFillTo do
      begin
         { Convert world-tile Y to local chunk Y }
         ColLY := ColWTY - TChunkManager.ChunkToTileY(AChunk.CY);
         if AChunk.InLocalBounds(FillLX, ColLY) then
            SetLiquid(AChunk, FillLX, ColLY, ALakeTile);
      end;
   end;
end;

{ =============================================================================
  Pass 1 — Surface lake detection
  =============================================================================

  HOW DEPRESSION DETECTION WORKS
  ─────────────────────────────────
  For each column LX in the chunk (world tile X = WTX):

    leftMin  = min SurfaceY over [WTX - SCAN_RADIUS .. WTX - 1]
    rightMin = min SurfaceY over [WTX + 1 .. WTX + SCAN_RADIUS]

  Note: smaller Y = higher on screen (y increases downward).
  A depression has LARGER Y (lower on screen) than its surroundings.

    waterLine     = Min(leftMin, rightMin)   ← lower lip of the two borders
    deprDepth     = SY(WTX) - waterLine      ← how many rows below both borders

  Column is "in a depression" when:
    deprDepth >= SurfaceMinDepth

  Consecutive depressed columns are accumulated into a lake segment.
  When a segment ends (or the chunk ends), TryCommitLake is called:
    • Width guard : skip if < MIN_LAKE_WIDTH columns
    • Probability : ColRand(centre, 1001) vs SurfaceLakeProb
    • Fill        : delegates to FillSurfaceLake (separate method → no LX clash)
  ============================================================================= }

procedure TLiquidPlacer.PlaceSurfaceLakes(AChunk: TWorldChunk);
var
   LX: Integer;
   WTX, SY: Integer;
   LeftMin, RightMin: Integer;
   WaterLine, DeprDepth: Integer;
   ScanX, ScanSY: Integer;
   Biome: byte;
   BP: PLiquidBiomeParams;
   InLake: boolean;
   LakeStartLX, LakeEndLX: Integer;
   LakeWidth: Integer;
   CentreWTX: Integer;
   R: Single;
   LakeTile: byte;

   { ── TryCommitLake ─────────────────────────────────────────────────────
     Called whenever a depression segment ends (column count >= threshold).
     AEndLX is the last column of the lake (inclusive).
     Uses only variables already in scope; never touches LX. }
   procedure TryCommitLake(AEndLX: Integer);
   var
      CommitBP: PLiquidBiomeParams;
   begin
      if LakeWidth < MIN_LAKE_WIDTH then
         Exit;

      { Evaluate biome at the centre of the lake }
      CentreWTX := WorldX(AChunk, LakeStartLX + LakeWidth div 2);
      CommitBP := ParamsForBiome(BiomeAt(CentreWTX));

      if not CommitBP^.SurfaceLakeEnabled then
         Exit;

      { Probability gate — deterministic, seed-driven }
      R := ColRand(CentreWTX, 1001);
      if R > CommitBP^.SurfaceLakeProb then
         Exit;

      LakeTile := LiquidTile(CommitBP^.SurfaceLakeType);
      if LakeTile = TILE_AIR then
         Exit;

      { Delegate fill to the dedicated method (uses its own FillLX variable) }
      FillSurfaceLake(AChunk, LakeStartLX, AEndLX, LakeTile, CommitBP);
   end;

begin
   InLake := False;
   LakeWidth := 0;
   LakeStartLX := 0;
   LakeEndLX := 0;

   for LX := 0 to CHUNK_TILES_W - 1 do
   begin
      WTX := WorldX(AChunk, LX);
      SY := FManager.GetSurfaceY(WTX);
      Biome := BiomeAt(WTX);
      BP := ParamsForBiome(Biome);

      { ── Left scan ──────────────────────────────────────────────────── }
      LeftMin := SY;
      for ScanX := WTX - SCAN_RADIUS to WTX - 1 do
      begin
         ScanSY := FManager.GetSurfaceY(ScanX);
         if ScanSY < LeftMin then
            LeftMin := ScanSY;
      end;

      { ── Right scan ─────────────────────────────────────────────────── }
      RightMin := SY;
      for ScanX := WTX + 1 to WTX + SCAN_RADIUS do
      begin
         ScanSY := FManager.GetSurfaceY(ScanX);
         if ScanSY < RightMin then
            RightMin := ScanSY;
      end;

      WaterLine := Min(LeftMin, RightMin);
      DeprDepth := SY - WaterLine;

      { ── Accumulate or terminate lake segment ────────────────────────── }
      if BP^.SurfaceLakeEnabled and (DeprDepth >= BP^.SurfaceMinDepth) then
      begin
         if not InLake then
         begin
            { Start of a new depression segment }
            InLake := True;
            LakeStartLX := LX;
            LakeWidth := 1;
         end
         else
            Inc(LakeWidth);
      end
      else
      begin
         if InLake then
         begin
            { We just left a depression. LakeEndLX = LX - 1.
              TryCommitLake uses LakeStartLX, LakeEndLX, and LakeWidth from
              the outer scope — it never reads or writes LX. }
            LakeEndLX := LX - 1;
            TryCommitLake(LakeEndLX);
            InLake := False;
            LakeWidth := 0;
         end;
      end;
   end;

   { ── Lake that reaches the right edge of the chunk ───────────────────── }
   if InLake then
   begin
      LakeEndLX := CHUNK_TILES_W - 1;
      TryCommitLake(LakeEndLX);
   end;
end;

{ =============================================================================
  Pass 2 — Underground lake fill
  =============================================================================

  ALGORITHM
  ──────────
  For each local column (LX), scan downward looking for the TOP of an air
  column that is:
    • Below the surface by at least UnderLakeMinWorldY world rows, AND
    • Has a solid tile directly above it (it is the ceiling of a cave).

  When such a ceiling is found, the cavity is measured downward (up to
  MAX_CAVITY_SCAN rows). A fraction (UnderLakeFillRatio) of the cavity height
  is then filled with liquid from the BOTTOM UP.

  The probability gate uses ColRand(WTX, 2002) so each cavity is independent.

  The outer loop index LY is advanced past each processed cavity with
  "LY := CavityBot + 1" to avoid re-scanning the cavity interior.
  ============================================================================= }

procedure TLiquidPlacer.PlaceUndergroundLakes(AChunk: TWorldChunk);
var
   LX, LY: Integer;
   WTX, WTY: Integer;
   SY: Integer;
   CavityTop, CavityBot: Integer;
   CavityH, FillRows, FillLY: Integer;
   Biome: byte;
   BP: PLiquidBiomeParams;
   LiqTile: byte;
   R: Single;
begin
   for LX := 0 to CHUNK_TILES_W - 1 do
   begin
      WTX := WorldX(AChunk, LX);
      SY := FManager.GetSurfaceY(WTX);
      Biome := BiomeAt(WTX);
      BP := ParamsForBiome(Biome);

      if not BP^.UnderLakeEnabled then
         Continue;

      LY := 0;
      while LY < CHUNK_TILES_H do
      begin
         WTY := WorldY(AChunk, LY);

         { Must be far enough below the surface }
         if WTY < SY + BP^.UnderLakeMinWorldY then
         begin
            Inc(LY);
            Continue;
         end;

         { Must be air }
         if AChunk.GetFG(LX, LY) <> TILE_AIR then
         begin
            Inc(LY);
            Continue;
         end;

         { Must have a solid ceiling directly above (= top of a cave) }
         if (LY > 0) and not IsSolid(AChunk, LX, LY - 1) then
         begin
            { Interior of a tall air column — already handled at its ceiling }
            Inc(LY);
            Continue;
         end;

         { ── Measure the cavity downward ─────────────────────────────── }
         CavityTop := LY;
         CavityBot := LY;
         while (CavityBot < CHUNK_TILES_H - 1) and (AChunk.GetFG(LX, CavityBot + 1) = TILE_AIR) and ((CavityBot - CavityTop) < MAX_CAVITY_SCAN) do
            Inc(CavityBot);

         CavityH := CavityBot - CavityTop + 1;

         { ── Probability gate ─────────────────────────────────────────── }
         R := ColRand(WTX, 2002);
         if R <= BP^.UnderLakeProb then
         begin
            LiqTile := LiquidTile(BP^.UnderLakeType);
            FillRows := Max(1, Round(CavityH * BP^.UnderLakeFillRatio));
            FillRows := Min(FillRows, CavityH);

            { Fill from the bottom of the cavity upward }
            for FillLY := CavityBot downto CavityBot - FillRows + 1 do
               SetLiquid(AChunk, LX, FillLY, LiqTile);
         end;

         { Skip past the cavity interior }
         LY := CavityBot + 1;
      end;
   end;
end;

{ =============================================================================
  Pass 3 — Lava pools (deep zone)
  =============================================================================

  Any air cell at world-Y >= LavaStartY is filled with lava.
  A 2D noise field gates per-cell probability so the lava mass has irregular,
  organic edges instead of a sharp horizontal cutoff. The noise field is
  evaluated at (WX * 0.11, WY * 0.09) — frequencies chosen so lava "blobs"
  span roughly 20–30 tiles horizontally and 15–20 tiles vertically, creating
  the extensive horizontal pools the requirement specifies.
  ============================================================================= }

procedure TLiquidPlacer.PlaceLavaPools(AChunk: TWorldChunk);
var
   LX, LY: Integer;
   WTX, WTY: Integer;
   Biome: byte;
   BP: PLiquidBiomeParams;
   R: Single;
begin
   for LX := 0 to CHUNK_TILES_W - 1 do
   begin
      WTX := WorldX(AChunk, LX);
      Biome := BiomeAt(WTX);
      BP := ParamsForBiome(Biome);

      if not BP^.LavaEnabled then
         Continue;

      for LY := 0 to CHUNK_TILES_H - 1 do
      begin
         WTY := WorldY(AChunk, LY);

         { Only cells in the deep zone }
         if WTY < BP^.LavaStartY then
            Continue;

         { Only air cells }
         if AChunk.GetFG(LX, LY) <> TILE_AIR then
            Continue;

         { Noise-gated probability — varies by column AND row }
         R := (ValueNoise2D(WTX * 0.11 + FSeed * 0.003, WTY * 0.09 + FSeed * 0.002) + 1.0) * 0.5;
         if R <= BP^.LavaProb then
         begin
            if Assigned(FSimulator) then
               FSimulator.PlaceLava(WTX, WTY, LIQ_MAX);
         end;
      end;
   end;
end;

{ =============================================================================
  PlaceChunk — public entry point
  ============================================================================= }

procedure TLiquidPlacer.PlaceChunk(AChunk: TWorldChunk);
begin
   if not Assigned(AChunk) then
      Exit;
   if not Assigned(FParams) then
      Exit;

   PlaceSurfaceLakes(AChunk);      { Pass 1 }
   PlaceUndergroundLakes(AChunk);  { Pass 2 }
   PlaceLavaPools(AChunk);         { Pass 3 }
end;

{ =============================================================================
  SeedLightEmitters
  ============================================================================= }

procedure TLiquidPlacer.SeedLightEmitters(var ASettings: TLightSettings);
begin
   if FParams^.LavaVisual.Emissive then
   begin
      ASettings.EmitterTileID := TILE_LAVA;
      ASettings.EmitterBrightness := FParams^.LavaVisual.EmitBrightness;
      ASettings.EmitterR := FParams^.LavaVisual.EmitR;
      ASettings.EmitterG := FParams^.LavaVisual.EmitG;
      ASettings.EmitterB := FParams^.LavaVisual.EmitB;
   end;
end;

end.
