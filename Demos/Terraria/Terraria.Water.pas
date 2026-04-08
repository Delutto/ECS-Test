unit Terraria.Water;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Math,
   Terraria.Common,
   Terraria.WorldChunk,
   Terraria.ChunkManager,
   Terraria.GenParams;

const
   MAX_WATER = 200;
   PRESSURE_THRESH = 198;
   MIN_FLOW = 1;
   FLOW_RATE = 5;
   WATER_SIM_HZ = 20;
   WATER_SIM_DT: Single = 1.0 / WATER_SIM_HZ;
   WATER_LM_BUCKETS = 1024;
   WATER_LM_P1 = 73856093;
   WATER_LM_P2 = 19349669;

type
   TWaterRow = array[0..CHUNK_TILES_W - 1] of byte;

   TWaterChunk = class
   public
      Data: array[0..CHUNK_TILES_H - 1] of TWaterRow;
      CX, CY: Integer;
      NextInBucket: TWaterChunk;
      FHasWater: boolean;
      constructor Create(ACX, ACY: Integer);
      function GetLevel(LX, LY: Integer): byte; inline;
      procedure SetLevel(LX, LY: Integer; ALevel: byte); inline;
      procedure Fill(ALevel: byte);
      procedure UpdateHasWater;
   end;

   TPassCache = array[0..CHUNK_TILES_H - 1, 0..CHUNK_TILES_W - 1] of boolean;

   TWaterMap = class
   private
      FBuckets: array[0..WATER_LM_BUCKETS - 1] of TWaterChunk;
      FManager: TChunkManager;
      FStepParity: Integer;
      FSimAccum: Single;

      function HashKey(ACX, ACY: Integer): Integer; inline;
      function FindChunk(ACX, ACY: Integer): TWaterChunk;
      function GetOrCreate(ACX, ACY: Integer): TWaterChunk;
      procedure FreeAllChunks;
      procedure BuildPassCache(AChunk: TWorldChunk; out ACache: TPassCache);
      procedure SimStep(ALeftToRight: boolean);
      function RawGet(WX, WY: Integer): byte; inline;
      procedure RawSet(WX, WY: Integer; ALevel: byte); inline;
   public
      constructor Create(AManager: TChunkManager);
      destructor Destroy; override;
      procedure Update(ADelta: Single);
      function GetLevel(WX, WY: Integer): byte;
      procedure SetLevel(WX, WY, ALevel: Integer);
      function HasWater(WX, WY: Integer): boolean; inline;
      procedure Clear;
      procedure PlaceSurfaceLakes(ACX, ACY: Integer; AChunk: TWorldChunk; const AParams: TWaterBiomeParams);
      procedure PlaceUndergroundLakes(ACX, ACY: Integer; AChunk: TWorldChunk; const AParams: TWaterBiomeParams);
   end;

implementation

{ ===========================================================================
  TWaterChunk
  =========================================================================== }

constructor TWaterChunk.Create(ACX, ACY: Integer);
begin
   inherited Create;
   CX := ACX;
   CY := ACY;
   NextInBucket := nil;
   FHasWater := False;
   FillChar(Data, SizeOf(Data), 0);
end;

function TWaterChunk.GetLevel(LX, LY: Integer): byte;
begin
   if (LX >= 0) and (LX < CHUNK_TILES_W) and (LY >= 0) and (LY < CHUNK_TILES_H) then
      Result := Data[LY][LX]
   else
      Result := 0;
end;

procedure TWaterChunk.SetLevel(LX, LY: Integer; ALevel: byte);
begin
   if (LX >= 0) and (LX < CHUNK_TILES_W) and (LY >= 0) and (LY < CHUNK_TILES_H) then
   begin
      Data[LY][LX] := ALevel;
      if ALevel > 0 then
         FHasWater := True;
   end;
end;

procedure TWaterChunk.Fill(ALevel: byte);
begin
   FillChar(Data, SizeOf(Data), ALevel);
   FHasWater := ALevel > 0;
end;

procedure TWaterChunk.UpdateHasWater;
var
   LX, LY: Integer;
begin
   FHasWater := False;
   for LY := 0 to CHUNK_TILES_H - 1 do
      for LX := 0 to CHUNK_TILES_W - 1 do
         if Data[LY][LX] > 0 then
         begin
            FHasWater := True;
            Exit;
         end;
end;

{ ===========================================================================
  TWaterMap - private
  =========================================================================== }

function TWaterMap.HashKey(ACX, ACY: Integer): Integer;
begin
   Result := ((ACX * WATER_LM_P1) xor (ACY * WATER_LM_P2)) and (WATER_LM_BUCKETS - 1);
   if Result < 0 then
      Result := Result + WATER_LM_BUCKETS;
end;

function TWaterMap.FindChunk(ACX, ACY: Integer): TWaterChunk;
var
   C: TWaterChunk;
begin
   C := FBuckets[HashKey(ACX, ACY)];
   while Assigned(C) do
   begin
      if (C.CX = ACX) and (C.CY = ACY) then
      begin
         Result := C;
         Exit;
      end;
      C := C.NextInBucket;
   end;
   Result := nil;
end;

function TWaterMap.GetOrCreate(ACX, ACY: Integer): TWaterChunk;
var
   Bkt: Integer;
   C: TWaterChunk;
begin
   C := FindChunk(ACX, ACY);
   if Assigned(C) then
   begin
      Result := C;
      Exit;
   end;
   Bkt := HashKey(ACX, ACY);
   C := TWaterChunk.Create(ACX, ACY);
   C.NextInBucket := FBuckets[Bkt];
   FBuckets[Bkt] := C;
   Result := C;
end;

procedure TWaterMap.FreeAllChunks;
var
   I: Integer;
   C, N: TWaterChunk;
begin
   for I := 0 to WATER_LM_BUCKETS - 1 do
   begin
      C := FBuckets[I];
      while Assigned(C) do
      begin
         N := C.NextInBucket;
         C.Free;
         C := N;
      end;
      FBuckets[I] := nil;
   end;
end;

procedure TWaterMap.BuildPassCache(AChunk: TWorldChunk; out ACache: TPassCache);
var
   LX, LY: Integer;
   Tile: byte;
begin
   for LY := 0 to CHUNK_TILES_H - 1 do
      for LX := 0 to CHUNK_TILES_W - 1 do
      begin
         Tile := AChunk.GetFG(LX, LY);
         ACache[LY][LX] := (Tile = TILE_AIR) or (Tile >= TILE_SHRUB);
      end;
end;

function TWaterMap.RawGet(WX, WY: Integer): byte;
var
   C: TWaterChunk;
begin
   C := FindChunk(TChunkManager.TileToChunkX(WX), TChunkManager.TileToChunkY(WY));
   if Assigned(C) then
      Result := C.GetLevel(TChunkManager.TileToLocalX(WX), TChunkManager.TileToLocalY(WY))
   else
      Result := 0;
end;

procedure TWaterMap.RawSet(WX, WY: Integer; ALevel: byte);
var
   C: TWaterChunk;
begin
   C := FindChunk(TChunkManager.TileToChunkX(WX), TChunkManager.TileToChunkY(WY));
   if Assigned(C) then
      C.SetLevel(TChunkManager.TileToLocalX(WX), TChunkManager.TileToLocalY(WY), ALevel);
end;

procedure TWaterMap.SimStep(ALeftToRight: boolean);
var
   AllChunks: array[0..511] of TWorldChunk;
   WaterChunks: array[0..511] of TWaterChunk;
   ChunkCount, I, LX, LY: Integer;
   WChunk, WCkUp, WCkDn, WCkLt, WCkRt: TWaterChunk;
   WorldChunk: TWorldChunk;
   Pass: TPassCache;
   Water, NeighW, Cap, Diff, Half, Move: Integer;
   PU, PD, PL, PR: boolean;
   WD, WU, WLeft, WRight: Integer;
   LastCol, LastRow: Integer;
   BX, BY: Integer;
begin
   ChunkCount := FManager.GetLoadedInRange(-10000, WORLD_MIN_CY - 1, 10000, WORLD_MAX_CY + 1, AllChunks, 512);
   if ChunkCount = 0 then
      Exit;

   for I := 0 to ChunkCount - 1 do
      WaterChunks[I] := FindChunk(AllChunks[I].CX, AllChunks[I].CY);

   LastCol := CHUNK_TILES_W - 1;
   LastRow := CHUNK_TILES_H - 1;

   for I := 0 to ChunkCount - 1 do
   begin
      WChunk := WaterChunks[I];
      if not Assigned(WChunk) or not WChunk.FHasWater then
         Continue;

      WorldChunk := AllChunks[I];
      BX := TChunkManager.ChunkToTileX(WorldChunk.CX);
      BY := TChunkManager.ChunkToTileY(WorldChunk.CY);

      BuildPassCache(WorldChunk, Pass);

      WCkUp := FindChunk(WorldChunk.CX, WorldChunk.CY - 1);
      WCkDn := FindChunk(WorldChunk.CX, WorldChunk.CY + 1);
      WCkLt := FindChunk(WorldChunk.CX - 1, WorldChunk.CY);
      WCkRt := FindChunk(WorldChunk.CX + 1, WorldChunk.CY);

      for LY := LastRow downto 0 do
      begin
         if ALeftToRight then
         begin
            for LX := 0 to LastCol do
            begin
               Water := WChunk.Data[LY][LX];
               if Water = 0 then
                  Continue;
               if not Pass[LY][LX] then
                  Continue;

               { Fall down }
               if LY < LastRow then
               begin
                  PD := Pass[LY + 1][LX];
                  WD := WChunk.Data[LY + 1][LX];
               end
               else
               if Assigned(WCkDn) then
               begin
                  PD := (FManager.GetFG(BX + LX, BY + CHUNK_TILES_H) = TILE_AIR);
                  WD := WCkDn.Data[0][LX];
               end
               else
               begin
                  PD := False;
                  WD := MAX_WATER;
               end;

               if PD then
               begin
                  Cap := MAX_WATER - WD;
                  Move := Min(Water, Cap);
                  if Move >= MIN_FLOW then
                  begin
                     WChunk.Data[LY][LX] := byte(Water - Move);
                     if LY < LastRow then
                        WChunk.Data[LY + 1][LX] := byte(WD + Move)
                     else
                     if Assigned(WCkDn) then
                     begin
                        WCkDn.Data[0][LX] := byte(WD + Move);
                        WCkDn.FHasWater := True;
                     end;
                     Water := Water - Move;
                  end;
               end;

               { Spread left }
               if LX > 0 then
               begin
                  PL := Pass[LY][LX - 1];
                  WLeft := WChunk.Data[LY][LX - 1];
               end
               else
               if Assigned(WCkLt) then
               begin
                  PL := (FManager.GetFG(BX - 1, BY + LY) = TILE_AIR);
                  WLeft := WCkLt.Data[LY][LastCol];
               end
               else
               begin
                  PL := False;
                  WLeft := MAX_WATER;
               end;

               if (Water > 0) and PL then
               begin
                  Diff := Water - WLeft;
                  if Diff > 1 then
                  begin
                     Half := Min(Diff div 2, FLOW_RATE);
                     if Half >= MIN_FLOW then
                     begin
                        WChunk.Data[LY][LX] := byte(Water - Half);
                        if LX > 0 then
                           WChunk.Data[LY][LX - 1] := byte(WLeft + Half)
                        else
                        if Assigned(WCkLt) then
                        begin
                           WCkLt.Data[LY][LastCol] := byte(WLeft + Half);
                           WCkLt.FHasWater := True;
                        end;
                        Water := Water - Half;
                     end;
                  end;
               end;

               { Spread right }
               if LX < LastCol then
               begin
                  PR := Pass[LY][LX + 1];
                  WRight := WChunk.Data[LY][LX + 1];
               end
               else
               if Assigned(WCkRt) then
               begin
                  PR := (FManager.GetFG(BX + CHUNK_TILES_W, BY + LY) = TILE_AIR);
                  WRight := WCkRt.Data[LY][0];
               end
               else
               begin
                  PR := False;
                  WRight := MAX_WATER;
               end;

               if (Water > 0) and PR then
               begin
                  Diff := Water - WRight;
                  if Diff > 1 then
                  begin
                     Half := Min(Diff div 2, FLOW_RATE);
                     if Half >= MIN_FLOW then
                     begin
                        WChunk.Data[LY][LX] := byte(Water - Half);
                        if LX < LastCol then
                           WChunk.Data[LY][LX + 1] := byte(WRight + Half)
                        else
                        if Assigned(WCkRt) then
                        begin
                           WCkRt.Data[LY][0] := byte(WRight + Half);
                           WCkRt.FHasWater := True;
                        end;
                        Water := Water - Half;
                     end;
                  end;
               end;

               { Pressure: rise up }
               if Water >= PRESSURE_THRESH then
               begin
                  if LY > 0 then
                  begin
                     PU := Pass[LY - 1][LX];
                     WU := WChunk.Data[LY - 1][LX];
                  end
                  else
                  if Assigned(WCkUp) then
                  begin
                     PU := (FManager.GetFG(BX + LX, BY - 1) = TILE_AIR);
                     WU := WCkUp.Data[LastRow][LX];
                  end
                  else
                  begin
                     PU := False;
                     WU := MAX_WATER;
                  end;

                  if PU then
                  begin
                     Cap := MAX_WATER - WU;
                     Move := Min(Water - PRESSURE_THRESH, Min(Cap, FLOW_RATE));
                     if Move >= MIN_FLOW then
                     begin
                        WChunk.Data[LY][LX] := byte(Water - Move);
                        if LY > 0 then
                           WChunk.Data[LY - 1][LX] := byte(WU + Move)
                        else
                        if Assigned(WCkUp) then
                        begin
                           WCkUp.Data[LastRow][LX] := byte(WU + Move);
                           WCkUp.FHasWater := True;
                        end;
                     end;
                  end;
               end;
            end; { LX L->R }
         end
         else
         begin
            for LX := LastCol downto 0 do
            begin
               Water := WChunk.Data[LY][LX];
               if Water = 0 then
                  Continue;
               if not Pass[LY][LX] then
                  Continue;

               { Fall down }
               if LY < LastRow then
               begin
                  PD := Pass[LY + 1][LX];
                  WD := WChunk.Data[LY + 1][LX];
               end
               else
               if Assigned(WCkDn) then
               begin
                  PD := (FManager.GetFG(BX + LX, BY + CHUNK_TILES_H) = TILE_AIR);
                  WD := WCkDn.Data[0][LX];
               end
               else
               begin
                  PD := False;
                  WD := MAX_WATER;
               end;

               if PD then
               begin
                  Cap := MAX_WATER - WD;
                  Move := Min(Water, Cap);
                  if Move >= MIN_FLOW then
                  begin
                     WChunk.Data[LY][LX] := byte(Water - Move);
                     if LY < LastRow then
                        WChunk.Data[LY + 1][LX] := byte(WD + Move)
                     else
                     if Assigned(WCkDn) then
                     begin
                        WCkDn.Data[0][LX] := byte(WD + Move);
                        WCkDn.FHasWater := True;
                     end;
                     Water := Water - Move;
                  end;
               end;

               { Spread right first (reversed pass) }
               if LX < LastCol then
               begin
                  PR := Pass[LY][LX + 1];
                  WRight := WChunk.Data[LY][LX + 1];
               end
               else
               if Assigned(WCkRt) then
               begin
                  PR := (FManager.GetFG(BX + CHUNK_TILES_W, BY + LY) = TILE_AIR);
                  WRight := WCkRt.Data[LY][0];
               end
               else
               begin
                  PR := False;
                  WRight := MAX_WATER;
               end;

               if (Water > 0) and PR then
               begin
                  Diff := Water - WRight;
                  if Diff > 1 then
                  begin
                     Half := Min(Diff div 2, FLOW_RATE);
                     if Half >= MIN_FLOW then
                     begin
                        WChunk.Data[LY][LX] := byte(Water - Half);
                        if LX < LastCol then
                           WChunk.Data[LY][LX + 1] := byte(WRight + Half)
                        else
                        if Assigned(WCkRt) then
                        begin
                           WCkRt.Data[LY][0] := byte(WRight + Half);
                           WCkRt.FHasWater := True;
                        end;
                        Water := Water - Half;
                     end;
                  end;
               end;

               { Spread left }
               if LX > 0 then
               begin
                  PL := Pass[LY][LX - 1];
                  WLeft := WChunk.Data[LY][LX - 1];
               end
               else
               if Assigned(WCkLt) then
               begin
                  PL := (FManager.GetFG(BX - 1, BY + LY) = TILE_AIR);
                  WLeft := WCkLt.Data[LY][LastCol];
               end
               else
               begin
                  PL := False;
                  WLeft := MAX_WATER;
               end;

               if (Water > 0) and PL then
               begin
                  Diff := Water - WLeft;
                  if Diff > 1 then
                  begin
                     Half := Min(Diff div 2, FLOW_RATE);
                     if Half >= MIN_FLOW then
                     begin
                        WChunk.Data[LY][LX] := byte(Water - Half);
                        if LX > 0 then
                           WChunk.Data[LY][LX - 1] := byte(WLeft + Half)
                        else
                        if Assigned(WCkLt) then
                        begin
                           WCkLt.Data[LY][LastCol] := byte(WLeft + Half);
                           WCkLt.FHasWater := True;
                        end;
                        Water := Water - Half;
                     end;
                  end;
               end;

               { Pressure: rise up }
               if Water >= PRESSURE_THRESH then
               begin
                  if LY > 0 then
                  begin
                     PU := Pass[LY - 1][LX];
                     WU := WChunk.Data[LY - 1][LX];
                  end
                  else
                  if Assigned(WCkUp) then
                  begin
                     PU := (FManager.GetFG(BX + LX, BY - 1) = TILE_AIR);
                     WU := WCkUp.Data[LastRow][LX];
                  end
                  else
                  begin
                     PU := False;
                     WU := MAX_WATER;
                  end;

                  if PU then
                  begin
                     Cap := MAX_WATER - WU;
                     Move := Min(Water - PRESSURE_THRESH, Min(Cap, FLOW_RATE));
                     if Move >= MIN_FLOW then
                     begin
                        WChunk.Data[LY][LX] := byte(Water - Move);
                        if LY > 0 then
                           WChunk.Data[LY - 1][LX] := byte(WU + Move)
                        else
                        if Assigned(WCkUp) then
                        begin
                           WCkUp.Data[LastRow][LX] := byte(WU + Move);
                           WCkUp.FHasWater := True;
                        end;
                     end;
                  end;
               end;
            end; { LX R->L }
         end;
      end; { LY }

      WChunk.UpdateHasWater;
   end; { chunks }
end;

{ ===========================================================================
  TWaterMap - public
  =========================================================================== }

constructor TWaterMap.Create(AManager: TChunkManager);
begin
   inherited Create;
   FManager := AManager;
   FStepParity := 0;
   FSimAccum := 0;
   FillChar(FBuckets, SizeOf(FBuckets), 0);
end;

destructor TWaterMap.Destroy;
begin
   FreeAllChunks;
   inherited;
end;

procedure TWaterMap.Update(ADelta: Single);
begin
   FSimAccum := FSimAccum + ADelta;
   if FSimAccum >= WATER_SIM_DT then
   begin
      FSimAccum := FSimAccum - WATER_SIM_DT;
      if FSimAccum > WATER_SIM_DT then
         FSimAccum := 0;
      SimStep(FStepParity = 0);
      FStepParity := 1 - FStepParity;
   end;
end;

function TWaterMap.GetLevel(WX, WY: Integer): byte;
begin
   Result := RawGet(WX, WY);
end;

procedure TWaterMap.SetLevel(WX, WY, ALevel: Integer);
var
   CX, CY: Integer;
   C: TWaterChunk;
   Clamped: byte;
begin
   if ALevel < 0 then
      Clamped := 0
   else
   if ALevel > MAX_WATER then
      Clamped := MAX_WATER
   else
      Clamped := byte(ALevel);
   CX := TChunkManager.TileToChunkX(WX);
   CY := TChunkManager.TileToChunkY(WY);
   C := GetOrCreate(CX, CY);
   C.SetLevel(TChunkManager.TileToLocalX(WX), TChunkManager.TileToLocalY(WY), Clamped);
end;

function TWaterMap.HasWater(WX, WY: Integer): boolean;
begin
   Result := RawGet(WX, WY) > 0;
end;

procedure TWaterMap.Clear;
begin
   FreeAllChunks;
   FSimAccum := 0;
end;

procedure TWaterMap.PlaceSurfaceLakes(ACX, ACY: Integer; AChunk: TWorldChunk; const AParams: TWaterBiomeParams);
var
   LX, LY, WX, WY, SY, FillTop: Integer;
   TileAbove: byte;
   WChunk: TWaterChunk;
begin
   if not AParams.SurfaceEnabled then
      Exit;
   WChunk := GetOrCreate(ACX, ACY);

   for LX := 0 to CHUNK_TILES_W - 1 do
   begin
      WX := TChunkManager.ChunkToTileX(ACX) + LX;
      SY := FManager.GetSurfaceY(WX);

      if (TChunkManager.ChunkToTileY(ACY) > SY) or (TChunkManager.ChunkToTileY(ACY) + CHUNK_TILES_H <= SY) then
         Continue;

      FillTop := -1;
      for LY := 0 to CHUNK_TILES_H - 1 do
         if AChunk.GetFG(LX, LY) <> TILE_AIR then
         begin
            FillTop := LY;
            Break;
         end;
      if FillTop < 0 then
         Continue;

      WY := TChunkManager.ChunkToTileY(ACY) + FillTop;
      if WY <= SY then
         Continue;

      if FillTop > 0 then
         TileAbove := AChunk.GetFG(LX, FillTop - 1)
      else
         TileAbove := TILE_AIR;
      if TileAbove <> TILE_AIR then
         Continue;

      LY := FillTop - 1;
      while (LY >= 0) and (LY >= FillTop - AParams.SurfaceLakeDepth) do
      begin
         if AChunk.GetFG(LX, LY) = TILE_AIR then
            WChunk.SetLevel(LX, LY, MAX_WATER)
         else
            Break;
         Dec(LY);
      end;
   end;

   WChunk.UpdateHasWater;
end;

procedure TWaterMap.PlaceUndergroundLakes(ACX, ACY: Integer; AChunk: TWorldChunk; const AParams: TWaterBiomeParams);
var
   LX, LY, WX, WY, SY, D: Integer;
   AirRun, FillStart, FillRows, R, FillLY: Integer;
   WChunk: TWaterChunk;
begin
   if not AParams.UndergroundEnabled then
      Exit;
   WChunk := GetOrCreate(ACX, ACY);

   for LX := 0 to CHUNK_TILES_W - 1 do
   begin
      WX := TChunkManager.ChunkToTileX(ACX) + LX;
      SY := FManager.GetSurfaceY(WX);
      AirRun := 0;
      FillStart := -1;

      for LY := 0 to CHUNK_TILES_H - 1 do
      begin
         WY := TChunkManager.ChunkToTileY(ACY) + LY;
         D := WY - SY;

         if D < AParams.UndergroundMinDepth then
         begin
            AirRun := 0;
            FillStart := -1;
            Continue;
         end;

         if AChunk.GetFG(LX, LY) = TILE_AIR then
         begin
            if AirRun = 0 then
               FillStart := LY;
            Inc(AirRun);
         end
         else
         begin
            if AirRun >= 2 then
            begin
               FillRows := Min(AirRun, AParams.UndergroundFillRows);
               for R := 0 to FillRows - 1 do
               begin
                  FillLY := FillStart + AirRun - 1 - R;
                  if (FillLY >= 0) and (FillLY < CHUNK_TILES_H) and (AChunk.GetFG(LX, FillLY) = TILE_AIR) then
                     WChunk.SetLevel(LX, FillLY, MAX_WATER);
               end;
            end;
            AirRun := 0;
            FillStart := -1;
         end;
      end;

      if AirRun >= 2 then
      begin
         FillRows := Min(AirRun, AParams.UndergroundFillRows);
         for R := 0 to FillRows - 1 do
         begin
            FillLY := FillStart + AirRun - 1 - R;
            if (FillLY >= 0) and (FillLY < CHUNK_TILES_H) and (AChunk.GetFG(LX, FillLY) = TILE_AIR) then
               WChunk.SetLevel(LX, FillLY, MAX_WATER);
         end;
      end;
   end;

   WChunk.UpdateHasWater;
end;

end.
