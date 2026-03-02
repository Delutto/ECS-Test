unit P2D.Components.TileMap;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, raylib,
  P2D.Core.Component, P2D.Core.Types;

const
  TILE_NONE   = 0;
  TILE_SOLID  = 1;
  TILE_SEMI   = 2;   // one-way platform
  TILE_HAZARD = 3;
  TILE_COIN   = 4;
  TILE_GOAL   = 5;

type
  TTileData = record
    TileID  : Integer;     // texture atlas frame id
    TileType: Integer;     // solid/semi/hazard etc.
    Solid   : Boolean;
  end;
  TTileRow = array of TTileData;
  TTileGrid = array of TTileRow;

  TTileMapComponent = class(TComponent2D)
  public
    TileWidth  : Integer;
    TileHeight : Integer;
    MapCols    : Integer;
    MapRows    : Integer;
    Grid       : TTileGrid;
    TileSet    : TTexture2D;
    TileSetCols: Integer;

    constructor Create; override;
    destructor  Destroy; override;

    procedure SetSize(ACols, ARows: Integer);
    procedure SetTile(ACol, ARow, ATileID, ATileType: Integer);
    function  GetTile(ACol, ARow: Integer): TTileData;
    function  GetTileRect(ATileID: Integer): TRectangle;
    function  GetTileWorldRect(ACol, ARow: Integer): TRectF;
    procedure LoadTileSet(const APath: string; ACols: Integer);
    procedure LoadFromString(const AData: string);
  end;

implementation

constructor TTileMapComponent.Create;
begin
  inherited Create;
  TileWidth   := 16;
  TileHeight  := 16;
  MapCols     := 0;
  MapRows     := 0;
  TileSetCols := 1;
  FillChar(TileSet, SizeOf(TileSet), 0);
end;

destructor TTileMapComponent.Destroy;
begin
  if TileSet.Id > 0 then UnloadTexture(TileSet);
  inherited;
end;

procedure TTileMapComponent.SetSize(ACols, ARows: Integer);
var R, C: Integer;
begin
  MapCols := ACols;
  MapRows := ARows;
  SetLength(Grid, ARows);
  for R := 0 to ARows - 1 do
  begin
    SetLength(Grid[R], ACols);
    for C := 0 to ACols - 1 do
    begin
      Grid[R][C].TileID   := TILE_NONE;
      Grid[R][C].TileType := TILE_NONE;
      Grid[R][C].Solid    := False;
    end;
  end;
end;

procedure TTileMapComponent.SetTile(ACol, ARow, ATileID, ATileType: Integer);
begin
  if (ARow < 0) or (ARow >= MapRows) or (ACol < 0) or (ACol >= MapCols) then Exit;
  Grid[ARow][ACol].TileID   := ATileID;
  Grid[ARow][ACol].TileType := ATileType;
  Grid[ARow][ACol].Solid    := ATileType = TILE_SOLID;
end;

function TTileMapComponent.GetTile(ACol, ARow: Integer): TTileData;
begin
  FillChar(Result, SizeOf(Result), 0);
  if (ARow >= 0) and (ARow < MapRows) and (ACol >= 0) and (ACol < MapCols) then
    Result := Grid[ARow][ACol];
end;

function TTileMapComponent.GetTileRect(ATileID: Integer): TRectangle;
var TX, TY: Integer;
begin
  if TileSetCols < 1 then TileSetCols := 1;
  TX := (ATileID mod TileSetCols) * TileWidth;
  TY := (ATileID div TileSetCols) * TileHeight;
  Result.X      := TX;
  Result.Y      := TY;
  Result.Width  := TileWidth;
  Result.Height := TileHeight;
end;

function TTileMapComponent.GetTileWorldRect(ACol, ARow: Integer): TRectF;
begin
  Result.Create(ACol * TileWidth, ARow * TileHeight, TileWidth, TileHeight);
end;

procedure TTileMapComponent.LoadTileSet(const APath: string; ACols: Integer);
begin
  if TileSet.Id > 0 then UnloadTexture(TileSet);
  TileSet     := LoadTexture(PChar(APath));
  TileSetCols := ACols;
end;

procedure TTileMapComponent.LoadFromString(const AData: string);
var
  Lines: TStringList;
  R, C : Integer;
  Tok  : string;
  Val  : Integer;
  TTyp : Integer;
  Parts: TStringArray;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AData;
    if Lines.Count = 0 then Exit;
    SetSize(Length(Lines[0].Split([','])), Lines.Count);
    for R := 0 to Lines.Count - 1 do
    begin
      Parts := Lines[R].Split([',']);
      for C := 0 to High(Parts) do
      begin
        if C >= MapCols then Break;
        Val := StrToIntDef(Trim(Parts[C]), 0);
        if Val = 1 then TTyp := TILE_SOLID
        else if Val = 2 then TTyp := TILE_SEMI
        else TTyp := TILE_NONE;
        SetTile(C, R, Val, TTyp);
      end;
    end;
  finally
    Lines.Free;
  end;
end;

end.
