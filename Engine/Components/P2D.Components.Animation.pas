unit P2D.Components.Animation;

{$mode objfpc}
{$H+}

interface

uses
   SysUtils,
   fgl,
   raylib,
   P2D.Core.Component,
   P2D.Core.Types;

type
   TAnimFrame = record
      SourceRect: TRectangle;
      Duration: Single;   // seconds
   end;
   TAnimFrameArray = array of TAnimFrame;

   TAnimation = class
   public
      Name: String;
      Frames: TAnimFrameArray;
      Loop: Boolean;
      constructor Create(const AName: String; ALoop: Boolean = True);
      procedure AddFrame(const ARect: TRectangle; ADuration: Single = 0.1);
      function FrameCount: Integer;
   end;

   TAnimationMap = specialize TFPGMapObject<String, TAnimation>;

   TAnimationComponent = class(TComponent2D)
   private
      FAnimations: TAnimationMap;
      FCurrent: TAnimation;
      FCurrentName: String;
      FFrameIndex: Integer;
      FTimer: Single;
      FFinished: Boolean;
   public
      constructor Create; override;
      destructor Destroy; override;

      procedure AddAnimation(AAnim: TAnimation);
      procedure Play(const AName: String; const AForceRestart: Boolean = False);
      procedure Tick(ADelta: Single; out ARect: TRectangle);

      property CurrentName: String read FCurrentName;
      property FrameIndex: Integer read FFrameIndex;
      property Finished: Boolean read FFinished;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

{ TAnimation }
constructor TAnimation.Create(const AName: String; ALoop: Boolean);
begin
   inherited Create;

   Name := AName;
   Loop := ALoop;
   SetLength(Frames, 0);
end;

procedure TAnimation.AddFrame(const ARect: TRectangle; ADuration: Single);
var
   Idx: Integer;
begin
   Idx := Length(Frames);
   SetLength(Frames, Idx + 1);
   Frames[Idx].SourceRect := ARect;
   Frames[Idx].Duration := ADuration;
end;

function TAnimation.FrameCount: Integer;
begin
   Result := Length(Frames);
end;

// ---------------------------------------------------------------------------
// TAnimationComponent
constructor TAnimationComponent.Create;
begin
   inherited Create;

   FAnimations := TAnimationMap.Create(True);
   FCurrent := nil;
   FFrameIndex := 0;
   FTimer := 0;
   FFinished := False;
end;

destructor TAnimationComponent.Destroy;
begin
   FAnimations.Free;

   inherited;
end;

procedure TAnimationComponent.AddAnimation(AAnim: TAnimation);
begin
   FAnimations[AAnim.Name] := AAnim;
end;

procedure TAnimationComponent.Play(const AName: String; const AForceRestart: Boolean = False);
begin
   if (Not AForceRestart) And SameText(FCurrentName, AName) then
   begin
      Exit
   end;

   // Tenta buscar a nova animação no mapa
   if FAnimations.TryGetData(AName, FCurrent) then
   begin
      // Se encontrou, configura como atual e reseta os contadores
      FCurrentName := AName;
      FFrameIndex := 0;
      FTimer := 0;
      FFinished := False;
   end;
   // Se não encontrou a animação, FCurrent permanece o anterior ou nil, e nada acontece.
end;

procedure TAnimationComponent.Tick(ADelta: Single; out ARect: TRectangle);
begin
   FillChar(ARect, SizeOf(ARect), 0);
   if Not Assigned(FCurrent) Or (FCurrent.FrameCount = 0) then
   begin
      Exit
   end;

   ARect := FCurrent.Frames[FFrameIndex].SourceRect;

   if FFinished And Not FCurrent.Loop then
   begin
      Exit
   end;

   FTimer := FTimer + ADelta;
   while FTimer >= FCurrent.Frames[FFrameIndex].Duration do
   begin
      FTimer := FTimer - FCurrent.Frames[FFrameIndex].Duration;
      Inc(FFrameIndex);
      if FFrameIndex >= FCurrent.FrameCount then
      begin
         if FCurrent.Loop then
         begin
            FFrameIndex := 0
         end
         else
         begin
            FFrameIndex := FCurrent.FrameCount - 1;
            FFinished := True;
            Break;
         end;
      end;
   end;
end;

initialization
   ComponentRegistry.Register(TAnimationComponent);

end.
