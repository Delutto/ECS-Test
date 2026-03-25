unit P2D.Components.Chunk;
{$mode objfpc}{$H+}
interface
uses SysUtils,raylib,P2D.Core.Component,P2D.Core.Types,P2D.Common;
type
  TChunkTileData2D=array[0..CHUNK_SIZE-1,0..CHUNK_SIZE-1]of Integer;
  TChunkComponent2D=class(TComponent2D)
  public
    ChunkX,ChunkY:Integer;
    Tiles:TChunkTileData2D;
    IsLoaded,IsDirty:Boolean;
    TileSize,TileSetCols:Integer;
    TileSet:TTexture2D;
    constructor Create;override;
    function  WorldX:Single;inline;
    function  WorldY:Single;inline;
    function  GetTile(C,R:Integer):Integer;
    procedure SetTile(C,R,ID:Integer);
  end;
implementation
uses P2D.Core.ComponentRegistry;
constructor TChunkComponent2D.Create;
begin inherited Create;
  ChunkX:=0;ChunkY:=0;FillChar(Tiles,SizeOf(Tiles),0);
  IsLoaded:=False;IsDirty:=False;TileSize:=16;TileSetCols:=1;
  FillChar(TileSet,SizeOf(TileSet),0);end;
function TChunkComponent2D.WorldX:Single;begin Result:=ChunkX*CHUNK_SIZE*TileSize;end;
function TChunkComponent2D.WorldY:Single;begin Result:=ChunkY*CHUNK_SIZE*TileSize;end;
function TChunkComponent2D.GetTile(C,R:Integer):Integer;
begin if(C>=0)and(C<CHUNK_SIZE)and(R>=0)and(R<CHUNK_SIZE)then
  Result:=Tiles[R][C]else Result:=0;end;
procedure TChunkComponent2D.SetTile(C,R,ID:Integer);
begin if(C>=0)and(C<CHUNK_SIZE)and(R>=0)and(R<CHUNK_SIZE)then
  begin Tiles[R][C]:=ID;IsDirty:=True;end;end;
initialization ComponentRegistry.Register(TChunkComponent2D);
end.
