unit P2D.Core.ComponentRegistry;

{===============================================================================
  Pascal2D Engine - Component Registry

  Sistema de registro global de componentes que atribui IDs únicos (0-63)
  para cada tipo de componente, permitindo uso de bitsets para queries O(1).

  OBJETIVO:
  • Cada TComponent2DClass recebe um ID único ao ser registrado
  • Entidades mantém signature (bitset) indicando componentes presentes
  • Sistemas comparam signatures em O(1) ao invés de O(n·log m)

  COMPATIBILIDADE:
  • 100% compatível com código existente
  • Registro automático na inicialização
  • Thread-safe (registro acontece antes de uso)

  Autor: Pascal2D Engine Team
  Baseado no código original do repositório
  Licença: MIT
===============================================================================}

{$mode objfpc}{$H+}

interface

uses
   StrUtils,
   SysUtils,
   fgl,
   P2D.Common,
   P2D.Core.Types,
   P2D.Core.Component;

type
  {---------------------------------------------------------------------------
   TComponentID - ID único de um tipo de componente (0-63)
   ---------------------------------------------------------------------------}
   TComponentID = 0..MAX_COMPONENT_TYPES - 1;

  {---------------------------------------------------------------------------
   TComponentSignature - Bitset indicando quais componentes uma entidade possui
   Definido em P2D.Core.System mas repetido aqui por clareza
   ---------------------------------------------------------------------------}
   TComponentSignature = set of TComponentID;

  {---------------------------------------------------------------------------
   TComponentInfo - Informações sobre um tipo de componente registrado
   ---------------------------------------------------------------------------}
   TComponentInfo = record
      ComponentClass: TComponent2DClass;
      ComponentID: TComponentID;
      ComponentName: String;
      RegisteredAt: TDateTime;
   end;

  {---------------------------------------------------------------------------
   TComponentRegistry - Singleton global de registro de componentes
   ---------------------------------------------------------------------------}
   TComponentRegistry = class
   private
      FComponentMap: specialize TFPGMap<Pointer, TComponentID>;
      FComponentInfo: array[TComponentID] of TComponentInfo;
      FNextID: TComponentID;
      FLocked: boolean;

      constructor CreatePrivate;
   public
      destructor Destroy; override;

    {-----------------------------------------------------------------------
     Register - Registra um tipo de componente e retorna seu ID único

     @param AClass Classe do componente a registrar
     @return ID único atribuído (0-63)
     @raises Exception se já foram registrados 64 tipos

     NOTA: Idempotente - registrar mesma classe múltiplas vezes retorna
           o mesmo ID sem erro
    -----------------------------------------------------------------------}
      function Register(AClass: TComponent2DClass): TComponentID;

    {-----------------------------------------------------------------------
     GetComponentID - Obtém ID de um componente já registrado

     @param AClass Classe do componente
     @return ID do componente ou -1 se não registrado
    -----------------------------------------------------------------------}
      function GetComponentID(AClass: TComponent2DClass): Integer;

    {-----------------------------------------------------------------------
     IsRegistered - Verifica se um componente está registrado
    -----------------------------------------------------------------------}
      function IsRegistered(AClass: TComponent2DClass): boolean;

    {-----------------------------------------------------------------------
     GetComponentClass - Obtém classe a partir do ID
    -----------------------------------------------------------------------}
      function GetComponentClass(AID: TComponentID): TComponent2DClass;

    {-----------------------------------------------------------------------
     GetComponentName - Obtém nome do componente
    -----------------------------------------------------------------------}
      function GetComponentName(AID: TComponentID): String;

    {-----------------------------------------------------------------------
     Lock - Bloqueia registro de novos componentes
     Chamado pelo World após inicialização para garantir IDs estáveis
    -----------------------------------------------------------------------}
      procedure Lock;

    {-----------------------------------------------------------------------
     GetRegisteredCount - Retorna quantos componentes foram registrados
    -----------------------------------------------------------------------}
      function GetRegisteredCount: Integer;

    {-----------------------------------------------------------------------
     PrintRegistry - Debug: lista todos componentes registrados
    -----------------------------------------------------------------------}
      {$IFDEF DEBUG}
      procedure PrintRegistry;
      {$ENDIF}

    {-----------------------------------------------------------------------
     CreateSignature - Cria signature a partir de lista de classes
    -----------------------------------------------------------------------}
      class function CreateSignature(const AClasses: array of TComponent2DClass): TComponentSignature;

    {-----------------------------------------------------------------------
     SignatureMatches - Verifica se signature de entidade satisfaz requisitos

     @param EntitySig Signature da entidade
     @param RequiredSig Signature requerida pelo sistema
     @return True se entidade tem TODOS os componentes requeridos
    -----------------------------------------------------------------------}
      class function SignatureMatches(const EntitySig, RequiredSig: TComponentSignature): boolean; inline;
   end;

{===============================================================================
  Singleton Global - Acesso via função
===============================================================================}
function ComponentRegistry: TComponentRegistry;

implementation

uses
   P2D.Utils.Logger,
   DateUtils;

var
   GComponentRegistry: TComponentRegistry = nil;

{===============================================================================
  Singleton Access
===============================================================================}
function ComponentRegistry: TComponentRegistry;
begin
   if not Assigned(GComponentRegistry) then
   begin
      GComponentRegistry := TComponentRegistry.CreatePrivate;
   end;
   Result := GComponentRegistry;
end;

{===============================================================================
  TComponentRegistry - Implementation
===============================================================================}

constructor TComponentRegistry.CreatePrivate;
var
   I: TComponentID;
begin
   inherited Create;

   FComponentMap := specialize TFPGMap<Pointer, TComponentID>.Create;
   FComponentMap.Sorted := True;
   FNextID := 0;
   FLocked := False;

   // Inicializar array de info
   for I := Low(TComponentID) to High(TComponentID) do
   begin
      FComponentInfo[I].ComponentClass := nil;
      FComponentInfo[I].ComponentID := I;
      FComponentInfo[I].ComponentName := '';
      FComponentInfo[I].RegisteredAt := 0;
   end;

   {$IFDEF DEBUG}
   Logger.Info('[ComponentRegistry] Created - Max types: 64');
   {$ENDIF}
end;

destructor TComponentRegistry.Destroy;
begin
   {$IFDEF DEBUG}
   Logger.Info(Format('[ComponentRegistry] Destroying - %d types registered', [FNextID]));
   PrintRegistry;
   {$ENDIF}

   FComponentMap.Free;
   inherited;
end;

function TComponentRegistry.Register(AClass: TComponent2DClass): TComponentID;
var
   Idx: Integer;
   ClassPtr: Pointer;
begin
   if not Assigned(AClass) then
   begin
      raise EArgumentNilException.Create('TComponentRegistry.Register: AClass cannot be nil');
   end;

   if FLocked then
   begin
      raise Exception.Create('TComponentRegistry.Register: Registry is locked. All components must be registered before World.Init');
   end;

   ClassPtr := Pointer(AClass);

   // Verificar se já está registrado (idempotente)
   Idx := FComponentMap.IndexOf(ClassPtr);
   if Idx >= 0 then
   begin
      Result := FComponentMap.Data[Idx];
      {$IFDEF DEBUG}
      Logger.Debug(Format('[ComponentRegistry] Component already registered: %s (ID: %d)', [AClass.ClassName, Result]));
      {$ENDIF}
      Exit;
   end;

   // Verificar se atingiu limite
   if FNextID >= MAX_COMPONENT_TYPES then
   begin
      raise Exception.CreateFmt('TComponentRegistry.Register: Maximum component types (%d) reached', [MAX_COMPONENT_TYPES]);
   end;

   // Registrar novo componente
   Result := FNextID;
   FComponentMap[ClassPtr] := Result;

   FComponentInfo[Result].ComponentClass := AClass;
   FComponentInfo[Result].ComponentID := Result;
   FComponentInfo[Result].ComponentName := AClass.ClassName;
   FComponentInfo[Result].RegisteredAt := Now;

   Inc(FNextID);

   {$IFDEF DEBUG}
   Logger.Info(Format('[ComponentRegistry] Registered: %s → ID %d', [AClass.ClassName, Result]));
   {$ENDIF}
end;

function TComponentRegistry.GetComponentID(AClass: TComponent2DClass): Integer;
var
   Idx: Integer;
begin
   Result := -1;

   if not Assigned(AClass) then
   begin
      Exit;
   end;

   Idx := FComponentMap.IndexOf(Pointer(AClass));
   if Idx >= 0 then
   begin
      Result := FComponentMap.Data[Idx];
   end;
end;

function TComponentRegistry.IsRegistered(AClass: TComponent2DClass): boolean;
begin
   Result := GetComponentID(AClass) >= 0;
end;

function TComponentRegistry.GetComponentClass(AID: TComponentID): TComponent2DClass;
begin
   Result := FComponentInfo[AID].ComponentClass;
end;

function TComponentRegistry.GetComponentName(AID: TComponentID): String;
begin
   Result := FComponentInfo[AID].ComponentName;
end;

procedure TComponentRegistry.Lock;
begin
   if FLocked then
   begin
      Exit;
   end;

   FLocked := True;

   {$IFDEF DEBUG}
   Logger.Info(Format('[ComponentRegistry] Locked with %d registered components', [FNextID]));
   {$ENDIF}
end;

function TComponentRegistry.GetRegisteredCount: Integer;
begin
   Result := FNextID;
end;

{$IFDEF DEBUG}
procedure TComponentRegistry.PrintRegistry;
var
   I: TComponentID;
begin
   if FNextID = 0 then
   begin
      Logger.Info('[ComponentRegistry] No components registered');
      Exit;
   end;

   Logger.Info('=== Component Registry ===');
   Logger.Info(Format('Total Registered: %d / %d', [FNextID, MAX_COMPONENT_TYPES]));
   Logger.Info(Format('Status: %s', [IfThen(FLocked, 'LOCKED', 'OPEN')]));
   Logger.Info('');
   Logger.Info('ID  | Component Class');
   Logger.Info('----+' + StringOfChar('-', 40));

   for I := 0 to FNextID - 1 do
   begin
      Logger.Info(Format('%2d  | %s', [
         I,
         FComponentInfo[I].ComponentName
         ]));
   end;

   Logger.Info('==========================');
end;
{$ENDIF}

class function TComponentRegistry.CreateSignature(const AClasses: array of TComponent2DClass): TComponentSignature;
var
   ComponentClass: TComponent2DClass;
   ID: Integer;
begin
   Result := [];

   for ComponentClass in AClasses do
   begin
      ID := ComponentRegistry.GetComponentID(ComponentClass);
      if ID >= 0 then
      begin
         Include(Result, ID);
      end
      else
      begin
         // Componente não registrado - registrar automaticamente
         ID := ComponentRegistry.Register(ComponentClass);
         Include(Result, ID);
      end;
   end;
end;

class function TComponentRegistry.SignatureMatches(const EntitySig, RequiredSig: TComponentSignature): boolean;
begin
   // Entidade satisfaz requisitos se tem TODOS os bits da signature requerida
   // Equivalente a: (EntitySig >= RequiredSig)
   Result := (RequiredSig <= EntitySig);
end;

{ Finalization }
finalization
   FreeAndNil(GComponentRegistry);

end.
