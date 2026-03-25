unit P2D.Core.InputManager;

{$mode ObjFPC}{$H+}

interface

uses
   Classes,
   SysUtils,
   fgl,
   P2D.Core.InputAction;

{ ============================================================================
  TInputManager
  Serviço global que gerencia múltiplos TInputActionMap.
  Deve ter Poll chamado uma vez por frame (pelo TEngine2D).
  ============================================================================ }

type
   TMapList = specialize TFPGObjectList<TInputActionMap>;

   TInputManager = class
   private
      FMaps: TMapList;
      function FindMap(const AName: String): TInputActionMap;
   public
      constructor Create;
      destructor Destroy; override;

      { Cria ou retorna um mapa existente }
      function AddMap(const AName: String): TInputActionMap;
      function GetMap(const AName: String): TInputActionMap;
      procedure RemoveMap(const AName: String);

      { Atualiza todos os mapas habilitados — chamar 1x por frame }
      procedure Poll;

      { Atalhos: consulta action em qualquer mapa }
      function IsDown(const AMap, AAction: String): boolean;
      function IsPressed(const AMap, AAction: String): boolean;
      function IsReleased(const AMap, AAction: String): boolean;
      function AxisValue(const AMap, AAction: String): Single;

      { Remapear em tempo real: substitui todos os bindings de uma action }
      procedure RemapAction(const AMap, AAction: String; const ANewBinding: TInputBinding);
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

function TInputManager.FindMap(const AName: String): TInputActionMap;
var
   M: TInputActionMap;
begin
   Result := nil;
   for M in FMaps do
   begin
      if M.Name = AName then
      begin
         Result := M;
         Exit;
      end;
   end;
end;

function TInputManager.AddMap(const AName: String): TInputActionMap;
begin
   Result := FindMap(AName);
   if Assigned(Result) then
   begin
      Exit;
   end;
   Result := TInputActionMap.Create(AName);
   FMaps.Add(Result);
end;

function TInputManager.GetMap(const AName: String): TInputActionMap;
begin
   Result := FindMap(AName);
end;

procedure TInputManager.RemoveMap(const AName: String);
var
   M: TInputActionMap;
begin
   M := FindMap(AName);
   if Assigned(M) then
   begin
      FMaps.Remove(M);
   end; // lista dona — libera o objeto
end;

procedure TInputManager.Poll;
var
   M: TInputActionMap;
begin
   for M in FMaps do
   begin
      M.Poll;
   end;
end;

function TInputManager.IsDown(const AMap, AAction: String): boolean;
var
   M: TInputActionMap;
begin
   M := FindMap(AMap);
   Result := Assigned(M) and M.IsDown(AAction);
end;

function TInputManager.IsPressed(const AMap, AAction: String): boolean;
var
   M: TInputActionMap;
begin
   M := FindMap(AMap);
   Result := Assigned(M) and M.IsPressed(AAction);
end;

function TInputManager.IsReleased(const AMap, AAction: String): boolean;
var
   M: TInputActionMap;
begin
   M := FindMap(AMap);
   Result := Assigned(M) and M.IsReleased(AAction);
end;

function TInputManager.AxisValue(const AMap, AAction: String): Single;
var
   M: TInputActionMap;
begin
   M := FindMap(AMap);
   if Assigned(M) then
   begin
      Result := M.AxisValue(AAction);
   end
   else
   begin
      Result := 0.0;
   end;
end;

procedure TInputManager.RemapAction(const AMap, AAction: String; const ANewBinding: TInputBinding);
var
   M: TInputActionMap;
   A: TInputAction;
begin
   M := FindMap(AMap);
   if not Assigned(M) then
   begin
      Exit;
   end;
   A := M.GetAction(AAction);
   if not Assigned(A) then
   begin
      Exit;
   end;
   A.ClearBindings;
   A.AddBinding(ANewBinding);
end;

initialization
   InputManager := TInputManager.Create;

finalization
   InputManager.Free;
   InputManager := nil;

end.
