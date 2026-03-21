unit P2D.Components.InputMap;

{$mode ObjFPC}{$H+}

{ ============================================================================
  TInputMapComponent
  Componente que vincula uma entidade a um TInputActionMap específico.
  Permite que sistemas consultem o mapa de input da entidade sem depender
  de nomes globais hard-coded.

  Uso típico:
    Comp := TInputMapComponent(E.AddComponent(TInputMapComponent.Create));
    Comp.MapName := 'Player1';
  ============================================================================ }

interface

uses
  SysUtils, P2D.Core.Component, P2D.Core.InputAction, P2D.Core.InputManager;

type
   TInputMapComponent = class(TComponent2D)
   private
      FMapName : string;
      function GetMap: TInputActionMap;
   public
      constructor Create; override;
      { Atalhos que delegam para o InputManager }
      function IsDown    (const AAction: string): Boolean;
      function IsPressed (const AAction: string): Boolean;
      function IsReleased(const AAction: string): Boolean;
      function AxisValue (const AAction: string): Single;
      { Nome do mapa no InputManager }
      property MapName : string           read FMapName write FMapName;
      { Acesso direto ao mapa (pode ser nil se não encontrado) }
      property Map     : TInputActionMap  read GetMap;
   end;

implementation

uses
   P2D.Core.ComponentRegistry;

constructor TInputMapComponent.Create;
begin
   inherited Create;

   FMapName := '';
end;

function TInputMapComponent.GetMap: TInputActionMap;
begin
   Result := InputManager.GetMap(FMapName);
end;

function TInputMapComponent.IsDown(const AAction: string): Boolean;
begin
   Result := InputManager.IsDown(FMapName, AAction);
end;

function TInputMapComponent.IsPressed(const AAction: string): Boolean;
begin
   Result := False;
   Result := InputManager.IsPressed(FMapName, AAction);
end;

function TInputMapComponent.IsReleased(const AAction: string): Boolean;
begin
   Result := InputManager.IsReleased(FMapName, AAction);
end;

function TInputMapComponent.AxisValue(const AAction: string): Single;
begin
   Result := InputManager.AxisValue(FMapName, AAction);
end;

initialization
   ComponentRegistry.Register(TInputMapComponent);

end.
