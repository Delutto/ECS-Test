unit P2D.Systems.TileMap;

{$mode objfpc}{$H+}

interface

uses
  raylib,
  P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Transform, P2D.Components.TileMap;

type
  TTileMapSystem = class(TSystem2D)
  public
    constructor Create(AWorld: TWorld); override;
    procedure Update(ADelta: Single); override;
    procedure Render; override;
  end;

implementation

constructor TTileMapSystem.Create(AWorld: TWorld);
begin
  inherited Create(AWorld);
  Priority := 30;
  Name     := 'TileMapSystem';
end;

procedure TTileMapSystem.Update(ADelta: Single);
begin
  // Tilemap is static – nothing to update each frame
end;

procedure TTileMapSystem.Render;
var
  E   : TEntity;
  TM  : TTileMapComponent;
  Tr  : TTransformComponent;
  R, C: Integer;
  Tile: TTileData;
  Src : TRectangle;
  Dst : TRectangle;
begin
  for E in World.Entities.GetAll do
  begin
    if not E.Alive then Continue;
    if not E.HasComponent(TTileMapComponent)  then Continue;
    if not E.HasComponent(TTransformComponent) then Continue;

    TM := TTileMapComponent(E.GetComponent(TTileMapComponent));
    Tr := TTransformComponent(E.GetComponent(TTransformComponent));

    if not (TM.Enabled and Tr.Enabled) then Continue;
    if TM.TileSet.Id = 0 then Continue;

    for R := 0 to TM.MapRows - 1 do
      for C := 0 to TM.MapCols - 1 do
      begin
        Tile := TM.GetTile(C, R);
        if Tile.TileID = TILE_NONE then Continue;

        Src := TM.GetTileRect(Tile.TileID - 1);
        Dst.X      := Tr.Position.X + C * TM.TileWidth;
        Dst.Y      := Tr.Position.Y + R * TM.TileHeight;
        Dst.Width  := TM.TileWidth;
        Dst.Height := TM.TileHeight;

        DrawTexturePro(TM.TileSet, Src, Dst,
                       Vector2(0, 0), 0, WHITE);
      end;
  end;
end;

end.
