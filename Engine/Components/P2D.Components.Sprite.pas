unit P2D.Components.Sprite;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, raylib,
  P2D.Core.Component, P2D.Core.Types;

type
  TFlip = (flNone, flHorizontal, flVertical, flBoth);

  TSpriteComponent = class(TComponent2D)
  public
    Texture   : TTexture2D;
    SourceRect: TRectangle;  // raylib TRectangle (sub-region of texture)
    Origin    : TVector2;    // pivot point
    Tint      : TColor;
    Flip      : TFlip;
    ZOrder    : Integer;
    Visible   : Boolean;
    constructor Create; override;
    destructor  Destroy; override;
    procedure LoadFromFile(const APath: string);
    procedure SetSourceFull;
  end;

implementation

constructor TSpriteComponent.Create;
begin
  inherited Create;
  FillChar(Texture, SizeOf(Texture), 0);
  FillChar(SourceRect, SizeOf(SourceRect), 0);
  Origin.Create(0, 0);
  Tint    := WHITE;
  Flip    := flNone;
  ZOrder  := 0;
  Visible := True;
end;

destructor TSpriteComponent.Destroy;
begin
  if Texture.Id > 0 then UnloadTexture(Texture);
  inherited;
end;

procedure TSpriteComponent.LoadFromFile(const APath: string);
begin
  if Texture.Id > 0 then UnloadTexture(Texture);
  Texture := LoadTexture(PChar(APath));
  SetSourceFull;
end;

procedure TSpriteComponent.SetSourceFull;
begin
  SourceRect.X      := 0;
  SourceRect.Y      := 0;
  SourceRect.Width  := Texture.Width;
  SourceRect.Height := Texture.Height;
end;

end.
