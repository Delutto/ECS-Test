unit P2D.Utils.Logger;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, Classes;

type
   TLogLevel = (llDebug, llInfo, llWarn, llError);

   { TLogger }
   TLogger = class
   private
      class var FInstance: TLogger;
      FLog: TStringList;
      FLevel: TLogLevel;
      FLogFile: string;
      constructor CreateInstance;
      function GetLevel: TLogLevel;
      procedure SetLevel(Value: TLogLevel);
   public
      class function Instance: TLogger;
      class destructor DestroyClass;

      procedure Log(ALevel: TLogLevel; const AMsg: string);
      procedure Debug(const AMsg: string); inline;
      procedure Info(const AMsg: string);  inline;
      procedure Warn(const AMsg: string);  inline;
      procedure Error(const AMsg: string); inline;
      procedure SaveToFile(const APath: string);

      procedure SetLogFile(const APath: string);
      procedure Clear;
      function GetLogText: string;
      function GetLogCount: Integer;

      property Level: TLogLevel read GetLevel write SetLevel;
   end;

var
   Logger: TLogger;

implementation

constructor TLogger.CreateInstance;
begin
  inherited Create;

  FLog   := TStringList.Create;
  FLevel := llDebug;
end;

function TLogger.GetLevel: TLogLevel;
begin
   Result := FLevel;
end;

procedure TLogger.SetLevel(Value: TLogLevel);
begin
   FLevel := Value;
end;

class function TLogger.Instance: TLogger;
begin
  if not Assigned(FInstance) then
  begin
    FInstance := TLogger.CreateInstance;
    Logger    := FInstance;
  end;
  Result := FInstance;
end;

class destructor TLogger.DestroyClass;
begin
  FreeAndNil(FInstance);
end;

procedure TLogger.Log(ALevel: TLogLevel; const AMsg: string);
const
  TAGS: array[TLogLevel] of string = ('[DEBUG]', '[INFO] ', '[WARN] ', '[ERROR]');
  {$IFDEF WIN}
  COLORS: array[TLogLevel] of Byte = (7, 10, 14, 12); // Gray, Green, Yellow, Red
  {$ENDIF}
var
   Line: string;
begin
   if ALevel < FLevel then
      Exit;

   Line := Format('%s %s %s', [FormatDateTime('hh:nn:ss.zzz', Now), TAGS[ALevel], AMsg]);
   FLog.Add(Line);

   {$IFDEF WIN}
   // Colored console output on Windows
   TextColor(COLORS[ALevel]);
   WriteLn(Line);
   NormVideo;
   {$ELSE}
   WriteLn(Line);
   {$ENDIF}

   // Auto-save critical errors
   if ALevel = llError then
   begin
      if FLogFile <> '' then
         SaveToFile(FLogFile);
   end;
end;

procedure TLogger.Debug(const AMsg: string);
begin
   Log(llDebug, AMsg);
end;

procedure TLogger.Info(const AMsg: string);
begin
   Log(llInfo,  AMsg);
end;

procedure TLogger.Warn(const AMsg: string);
begin
   Log(llWarn,  AMsg);
end;

procedure TLogger.Error(const AMsg: string);
begin
   Log(llError, AMsg);
end;

procedure TLogger.SaveToFile(const APath: string);
begin
   FLog.SaveToFile(APath);
end;

procedure TLogger.SetLogFile(const APath: string);
begin
   FLogFile := APath;
   {$IFDEF DEBUG}
   WriteLn('[Logger] Log file set to: ', APath);
   {$ENDIF}
end;

procedure TLogger.Clear;
begin
   FLog.Clear;
   {$IFDEF DEBUG}
   WriteLn('[Logger] Log cleared');
   {$ENDIF}
end;

function TLogger.GetLogText: string;
begin
   Result := FLog.Text;
end;

function TLogger.GetLogCount: Integer;
begin
   Result := FLog.Count;
end;

initialization
   TLogger.Instance;

end.
