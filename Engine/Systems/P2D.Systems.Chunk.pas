unit P2D.Systems.Chunk;
{$mode objfpc}{$H+}
interface
uses SysUtils,Math,fgl,raylib,
     P2D.Core.ComponentRegistry,P2D.Core.Types,P2D.Core.Entity,
     P2D.Core.System,P2D.Core.World,
     P2D.Components.Transform,P2D.Components.Camera2D,P2D.Components.Chunk;
type
  TChunkMap2D=specialize TFPGMap<Integer,TEntity>;
  TOnChunkGenerateProc2D=procedure(CX,CY:Integer;AChunk:TChunkComponent2D) of object;
  TChunkSystem2D=class(TSystem2D)
  private
    FTransformID,FCameraID,FChunkID:Integer;
    FCamEntity:TEntity;
    FLoadedChunks:TChunkMap2D;
    FTileSize,FTileSetCols:Integer;
    FTileSet:TTexture2D;
    function  ChunkKey(CX,CY:Integer):Integer;inline;
    procedure LoadChunk(CX,CY:Integer);
    procedure UnloadChunk(CX,CY:Integer);
  public
    OnGenerateChunk:TOnChunkGenerateProc2D;
    constructor Create(AW:TWorldBase;TS:Integer=16;TSC:Integer=1);reintroduce;
    destructor Destroy;override;
    procedure Init;override;
    procedure Update(DT:Single);override;
    procedure Shutdown;override;
    procedure SetTileSet(const ATex:TTexture2D;ACols:Integer=1);
    property TileSize:Integer read FTileSize;
  end;
implementation
uses P2D.Common,P2D.Core.Events;
constructor TChunkSystem2D.Create(AW:TWorldBase;TS,TSC:Integer);
begin inherited Create(AW);Priority:=35;Name:='ChunkSystem';
  FTileSize:=TS;FTileSetCols:=TSC;FillChar(FTileSet,SizeOf(FTileSet),0);
  FLoadedChunks:=TChunkMap2D.Create;FCamEntity:=nil;OnGenerateChunk:=nil;end;
destructor TChunkSystem2D.Destroy;begin FLoadedChunks.Free;inherited;end;
function TChunkSystem2D.ChunkKey(CX,CY:Integer):Integer;
begin Result:=CX*100000+CY;end;
procedure TChunkSystem2D.SetTileSet(const ATex:TTexture2D;ACols:Integer);
begin FTileSet:=ATex;FTileSetCols:=ACols;end;
procedure TChunkSystem2D.Init;
var E:TEntity;
begin inherited Init;
  RequireComponent(TChunkComponent2D);RequireComponent(TTransformComponent);
  FTransformID:=ComponentRegistry.GetComponentID(TTransformComponent);
  FCameraID:=ComponentRegistry.GetComponentID(TCamera2DComponent);
  FChunkID:=ComponentRegistry.GetComponentID(TChunkComponent2D);
  FCamEntity:=nil;
  for E in World.Entities.GetAll do
    if E.Alive and Assigned(E.GetComponentByID(FCameraID))then begin
      FCamEntity:=E;Break;end;end;
procedure TChunkSystem2D.Shutdown;
begin FLoadedChunks.Clear;FCamEntity:=nil;inherited Shutdown;end;
procedure TChunkSystem2D.LoadChunk(CX,CY:Integer);
var E:TEntity;Ch:TChunkComponent2D;Tr:TTransformComponent;K:Integer;
begin K:=ChunkKey(CX,CY);if FLoadedChunks.IndexOf(K)>=0 then Exit;
  E:=World.CreateEntity(Format('Chunk_%d_%d',[CX,CY]));
  Tr:=TTransformComponent.Create;Tr.Position.X:=CX*CHUNK_SIZE*FTileSize;
  Tr.Position.Y:=CY*CHUNK_SIZE*FTileSize;E.AddComponent(Tr);
  Ch:=TChunkComponent2D.Create;Ch.ChunkX:=CX;Ch.ChunkY:=CY;
  Ch.TileSize:=FTileSize;Ch.TileSet:=FTileSet;Ch.TileSetCols:=FTileSetCols;
  Ch.IsLoaded:=True;E.AddComponent(Ch);
  if Assigned(OnGenerateChunk)then OnGenerateChunk(CX,CY,Ch);
  FLoadedChunks.Add(K,E);
  World.EventBus.Publish(TChunkLoadedEvent2D.Create(CX,CY));end;
procedure TChunkSystem2D.UnloadChunk(CX,CY:Integer);
var K,Idx:Integer;E:TEntity;
begin K:=ChunkKey(CX,CY);Idx:=FLoadedChunks.IndexOf(K);if Idx<0 then Exit;
  E:=FLoadedChunks.Data[Idx];FLoadedChunks.Delete(Idx);
  if Assigned(E)then World.DestroyEntity(E.ID);
  World.EventBus.Publish(TChunkUnloadedEvent2D.Create(CX,CY));end;
procedure TChunkSystem2D.Update(DT:Single);
var Cam:TCamera2DComponent;CamTr:TTransformComponent;
    CX,CY,CCX,CCY,K,I,DC:Integer;
    Del:array of Integer;
begin if not Assigned(FCamEntity)or not FCamEntity.Alive then Exit;
  Cam:=TCamera2DComponent(FCamEntity.GetComponentByID(FCameraID));
  CamTr:=TTransformComponent(FCamEntity.GetComponentByID(FTransformID));
  if not Assigned(Cam)or not Assigned(CamTr)then Exit;
  CCX:=Trunc(CamTr.Position.X/(CHUNK_SIZE*FTileSize));
  CCY:=Trunc(CamTr.Position.Y/(CHUNK_SIZE*FTileSize));
  for CX:=CCX-CHUNK_LOAD_RADIUS to CCX+CHUNK_LOAD_RADIUS do
    for CY:=CCY-CHUNK_LOAD_RADIUS to CCY+CHUNK_LOAD_RADIUS do
      LoadChunk(CX,CY);
  SetLength(Del,FLoadedChunks.Count);DC:=0;
  for I:=0 to FLoadedChunks.Count-1 do begin
    K:=FLoadedChunks.Keys[I];CX:=K div 100000;CY:=K mod 100000;
    if(Abs(CX-CCX)>CHUNK_UNLOAD_RADIUS)or(Abs(CY-CCY)>CHUNK_UNLOAD_RADIUS)then
    begin Del[DC]:=K;Inc(DC);end;end;
  for I:=0 to DC-1 do begin
    K:=Del[I];CX:=K div 100000;CY:=K mod 100000;UnloadChunk(CX,CY);end;end;
end.
