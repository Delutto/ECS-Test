unit P2D.Core.System;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, P2D.Core.Types, P2D.Core.Entity;

type
  // Forward declaration
  TWorld = class;

  // -------------------------------------------------------------------------
  // Base class for all systems
  // -------------------------------------------------------------------------
  TSystem2D = class
  private
    FWorld   : TWorld;
    FPriority: TSystemPriority;
    FEnabled : Boolean;
    FName    : string;
  public
    constructor Create(AWorld: TWorld); virtual;
    procedure Init;    virtual;
    procedure Update(ADelta: Single); virtual; abstract;
    procedure Render;  virtual;
    procedure Shutdown; virtual;

    property World    : TWorld           read FWorld;
    property Priority : TSystemPriority  read FPriority write FPriority;
    property Enabled  : Boolean          read FEnabled  write FEnabled;
    property Name     : string           read FName     write FName;
  end;

  TSystem2DClass = class of TSystem2D;

implementation

uses P2D.Core.World;

constructor TSystem2D.Create(AWorld: TWorld);
begin
  inherited Create;
  FWorld    := AWorld;
  FPriority := 0;
  FEnabled  := True;
end;

procedure TSystem2D.Init;
begin

end;
procedure TSystem2D.Render;
begin

end;

procedure TSystem2D.Shutdown;
begin

end;

end.