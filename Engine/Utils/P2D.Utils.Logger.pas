unit P2D.Utils.Logger;

{$mode objfpc}
{$H+}

interface

uses
   SysUtils,
   Classes;

type
   TLogLevel = (llDebug, llInfo, llWarn, llError);

   { TLogger }
   TLogger = class
   private
      class var FInstance: TLogger;
         FLog: TStringList;
         FLevel: TLogLevel;
         FLogFile: String;
      constructor CreateInstance;
      function GetLevel: TLogLevel;
      procedure SetLevel(Value: TLogLevel);
   public
      class function Instance: TLogger;
      class destructor DestroyClass;

      procedure Log(ALevel: TLogLevel; const AMsg: String);
      procedure Debug(const AMsg: String); inline;
      procedure Info(const AMsg: String); inline;
      procedure Warn(const AMsg: String); inline;
      procedure Error(const AMsg: String); inline;
      procedure SaveToFile(const APath: String);

      procedure SetLogFile(const APath: String);
      procedure Clear;
      function GetLogText: String;
      function GetLogCount: Integer;

      property Level: TLogLevel read GetLevel write SetLevel;
   end;

var
   Logger: TLogger;

implementation

constructor TLogger.CreateInstance;
begin
   inherited Create;

   FLog := TStringList.Create;
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
   if Not Assigned(FInstance) then
   begin
      FInstance := TLogger.CreateInstance;
      Logger := FInstance;
   end;
   Result := FInstance;
end;

class destructor TLogger.DestroyClass;
begin
   FreeAndNil(FInstance);
end;

procedure TLogger.Log(ALevel: TLogLevel; const AMsg: String);
const
   TAGS: array[TLogLevel] of String = ('[DEBUG]', '[INFO] ', '[WARN] ', '[ERROR]');
   {$IFDEF WIN}
   COLORS: array[TLogLevel] of Byte = (7, 10, 14, 12); // Gray, Green, Yellow, Red
   {$ENDIF}
var
   Line: String;
begin
   if ALevel < FLevel then
   begin
      Exit
   end;

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
      begin
         SaveToFile(FLogFile)
      end;
   end;
end;

procedure TLogger.Debug(const AMsg: String);
begin
   Log(llDebug, AMsg);
end;

procedure TLogger.Info(const AMsg: String);
begin
   Log(llInfo, AMsg);
end;

procedure TLogger.Warn(const AMsg: String);
begin
   Log(llWarn, AMsg);
end;

procedure TLogger.Error(const AMsg: String);
begin
   Log(llError, AMsg);
end;

procedure TLogger.SaveToFile(const APath: String);
begin
   FLog.SaveToFile(APath);
end;

procedure TLogger.SetLogFile(const APath: String);
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

function TLogger.GetLogText: String;
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
