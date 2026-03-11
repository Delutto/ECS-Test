unit P2D.Core.InputManager;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, fgl, P2D.Core.InputAction;

{ ============================================================================
  TInputManager
  Serviço global que gerencia múltiplos TInputActionMap.
  Deve ter Poll chamado uma vez por frame (pelo TEngine2D).
  ============================================================================ }

type
  TMapList = specialize TFPGObjectList<TInputActionMap>;

  TInputManager = class
  private
    FMaps    : TMapList;
    function FindMap(const AName: string): TInputActionMap;
  public
    constructor Create;
    destructor Destroy; override;

    { Cria ou retorna um mapa existente }
    function AddMap(const AName: string): TInputActionMap;
    function GetMap(const AName: string): TInputActionMap;
    procedure RemoveMap(const AName: string);

    { Atualiza todos os mapas habilitados — chamar 1x por frame }
    procedure Poll;

    { Atalhos: consulta action em qualquer mapa }
    function IsDown    (const AMap, AAction: string): Boolean;
    function IsPressed (const AMap, AAction: string): Boolean;
    function IsReleased(const AMap, AAction: string): Boolean;
    function AxisValue (const AMap, AAction: string): Single;

    { Remapear em tempo real: substitui todos os bindings de uma action }
    procedure RemapAction(const AMap, AAction: string;
      const ANewBinding: TInputBinding);
  end;

{ Instância global de conveniência (opcional) }
var
  InputManager: TInputManager;

implementation

{ ─────────────────────────────────────────────────────────────────────────── }

constructor TInputManager.Create;
begin
  inherited Create;
  FMaps := TMapList.Create(True); // lista dona dos mapas
end;

destructor TInputManager.Destroy;
begin
  FMaps.Free;
  inherited;
end;

function TInputManager.FindMap(const AName: string): TInputActionMap;
var
  M: TInputActionMap;
begin
  Result := nil;
  for M in FMaps do
    if M.Name = AName then
    begin
      Result := M;
      Exit;
    end;
end;

function TInputManager.AddMap(const AName: string): TInputActionMap;
begin
  Result := FindMap(AName);
  if Assigned(Result) then Exit;
  Result := TInputActionMap.Create(AName);
  FMaps.Add(Result);
end;

function TInputManager.GetMap(const AName: string): TInputActionMap;
begin
  Result := FindMap(AName);
end;

procedure TInputManager.RemoveMap(const AName: string);
var
  M: TInputActionMap;
begin
  M := FindMap(AName);
  if Assigned(M) then
    FMaps.Remove(M); // lista dona — libera o objeto
end;

procedure TInputManager.Poll;
var
  M: TInputActionMap;
begin
  for M in FMaps do
    M.Poll;
end;

function TInputManager.IsDown(const AMap, AAction: string): Boolean;
var
  M: TInputActionMap;
begin
  M := FindMap(AMap);
  Result := Assigned(M) and M.IsDown(AAction);
end;

function TInputManager.IsPressed(const AMap, AAction: string): Boolean;
var
  M: TInputActionMap;
begin
  M := FindMap(AMap);
  Result := Assigned(M) and M.IsPressed(AAction);
end;

function TInputManager.IsReleased(const AMap, AAction: string): Boolean;
var
  M: TInputActionMap;
begin
  M := FindMap(AMap);
  Result := Assigned(M) and M.IsReleased(AAction);
end;

function TInputManager.AxisValue(const AMap, AAction: string): Single;
var
  M: TInputActionMap;
begin
  M := FindMap(AMap);
  if Assigned(M) then Result := M.AxisValue(AAction)
  else Result := 0.0;
end;

procedure TInputManager.RemapAction(const AMap, AAction: string;
  const ANewBinding: TInputBinding);
var
  M: TInputActionMap;
  A: TInputAction;
begin
  M := FindMap(AMap);
  if not Assigned(M) then Exit;
  A := M.GetAction(AAction);
  if not Assigned(A) then Exit;
  A.ClearBindings;
  A.AddBinding(ANewBinding);
end;

initialization
  InputManager := TInputManager.Create;

finalization
  InputManager.Free;
  InputManager := nil;

end.
