unit P2D.Components.Pathfinder;
{$mode objfpc}{$H+}
interface
uses SysUtils,Math,P2D.Core.Component,P2D.Core.Types,P2D.Core.Pathfinding;
type
  TPathFollowMode2D=(pfmStop,pfmLoop,pfmPingPong,pfmChase);
  TPathfinderComponent2D=class(TComponent2D)
  public
    TargetX,TargetY:Single; TargetID:Cardinal;
    Path:TPathArray2D; PathLength,PathIndex:Integer; PathDirty:Boolean;
    MoveSpeed:Single; FollowMode:TPathFollowMode2D;
    Stopped,Arrived:Boolean;
    GridRef:TAStarGrid2D; TileSize:Integer;
    GridOffsetX,GridOffsetY:Single;
    RepathInterval,RepathTimer:Single;
    constructor Create;override;
    destructor Destroy;override;
    procedure WorldToGrid(WX,WY:Single;out C,R:Integer);
    procedure GridToWorld(C,R:Integer;out WX,WY:Single);
  end;
implementation
uses P2D.Core.ComponentRegistry;
constructor TPathfinderComponent2D.Create;
begin inherited Create;
  TargetX:=0;TargetY:=0;TargetID:=0;PathLength:=0;PathIndex:=0;
  PathDirty:=True;MoveSpeed:=80;FollowMode:=pfmStop;
  Stopped:=True;Arrived:=False;GridRef:=nil;
  TileSize:=16;GridOffsetX:=0;GridOffsetY:=0;
  RepathInterval:=0.5;RepathTimer:=0;end;
destructor TPathfinderComponent2D.Destroy;
begin SetLength(Path,0);inherited;end;
procedure TPathfinderComponent2D.WorldToGrid(WX,WY:Single;out C,R:Integer);
begin C:=Trunc((WX-GridOffsetX)/TileSize);R:=Trunc((WY-GridOffsetY)/TileSize);end;
procedure TPathfinderComponent2D.GridToWorld(C,R:Integer;out WX,WY:Single);
begin WX:=GridOffsetX+C*TileSize+TileSize*0.5;WY:=GridOffsetY+R*TileSize+TileSize*0.5;end;
initialization ComponentRegistry.Register(TPathfinderComponent2D);
end.
