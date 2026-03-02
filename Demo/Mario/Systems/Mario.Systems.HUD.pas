unit Mario.Systems.HUD;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, raylib,
  P2D.Core.Entity, P2D.Core.System, P2D.Core.World,
  P2D.Components.Tags;

type
  THUDSystem = class(TSystem2D)
  private
    FScreenW: Integer;
    FScreenH: Integer;
  public
    constructor Create(AWorld: TWorld; AW, AH: Integer); reintroduce;
    procedure Update(ADelta: Single); override;
    procedure Render; override;
  end;

implementation

constructor THUDSystem.Create(AWorld: TWorld; AW, AH: Integer);
begin
  inherited Create(AWorld);
  Priority := 200;
  Name     := 'HUDSystem';
  FScreenW := AW;
  FScreenH := AH;
end;

procedure THUDSystem.Update(ADelta: Single);
begin end;

procedure THUDSystem.Render;
var
  E   : TEntity;
  PC  : TPlayerComponent;
  HUD : string;
begin
  PC := nil;
  for E in World.Entities.GetAll do
    if E.Alive and E.HasComponent(TPlayerComponent) then
    begin
      PC := TPlayerComponent(E.GetComponent(TPlayerComponent));
      Break;
    end;

  if not Assigned(PC) then Exit;

  // Panel
  DrawRectangle(0, 0, FScreenW, 32, RayColor(0, 0, 0, 160));

  // Score
  HUD := Format('SCORE  %07d', [PC.Score]);
  DrawText(PChar(HUD), 20, 8, 18, YELLOW);

  // Coins
  HUD := Format('x%02d', [PC.Coins]);
  DrawText(PChar(HUD), FScreenW div 2 - 40, 8, 18, YELLOW);
  DrawText('COINS', FScreenW div 2 - 100, 8, 18, WHITE);

  // Lives
  HUD := Format('LIVES  %d', [PC.Lives]);
  DrawText(PChar(HUD), FScreenW - 200, 8, 18, WHITE);

  // Controls hint
  DrawText('Arrows/WASD: Move   Space/W: Jump   Shift/Z: Run',
           10, FScreenH - 22, 12, RayColor(220,220,220,200));

  // Game over
  if PC.State = psDead then
  begin
    DrawRectangle(0, 0, FScreenW, FScreenH, RayColor(0,0,0,160));
    DrawText('GAME OVER', FScreenW div 2 - 90, FScreenH div 2 - 20, 40, RED);
    DrawText('Press R to restart', FScreenW div 2 - 110,
             FScreenH div 2 + 30, 22, WHITE);
  end;
end;

end.