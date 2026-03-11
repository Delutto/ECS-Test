unit P2D.Core.Event;

{$mode objfpc}{$H+}

interface

uses
   SysUtils, fgl;

type
 { -------------------------------------------------------------------------
   TEvent2D — classe base para todos os eventos da engine.

   Subclasses definem os dados específicos do evento.
   O EventBus torna-se dono do objeto após Publish: não libere manualmente.

   Handled: quando True, handlers subsequentes na fila não são chamados.
   Útil para "consumir" um evento e evitar processamento duplo.
   ------------------------------------------------------------------------- }
   TEvent2D = class
   public
      Handled: Boolean;
      constructor Create;
   end;

 { Assinatura do callback — método de instância que recebe qualquer TEvent2D.
   O handler deve fazer cast para o tipo esperado antes de acessar os dados. }
   TEventCallback = procedure(AEvent: TEvent2D) of object;

 { Wrapper interno para armazenar um callback em lista gerenciada. }
   TEventSubscriber = class
   public
      Callback: TEventCallback;
      constructor Create(const ACallback: TEventCallback);
   end;

   TSubscriberList = specialize TFPGObjectList<TEventSubscriber>;
   TEventQueue     = specialize TFPGObjectList<TEvent2D>;
   THandlerMap     = specialize TFPGMap<Pointer, TSubscriberList>;

   { -------------------------------------------------------------------------
    TEventBus — barramento central de eventos com dispatch diferido.

    Publish → enfileira o evento (não chama handlers imediatamente).
    Dispatch → processa toda a fila e libera os eventos.
              Chamado por TWorld.Update ao final de cada frame.

    Dispatch diferido garante:
      - Handlers rodam em contexto previsível (após física e lógica do frame)
      - Eventos publicados durante Dispatch vão para o próximo frame
        (previne loops infinitos de re-entrância)
    ------------------------------------------------------------------------- }
   TEventBus = class
   private
      FHandlers    : THandlerMap;
      FReadQueue   : TEventQueue;
      FWriteQueue  : TEventQueue;
      FDispatching : Boolean;
   public
      constructor Create;
      destructor  Destroy; override;

    { Registra ACallback para receber eventos do tipo AEventClass.
      Chamado tipicamente em TSystem2D.Init. }
      procedure Subscribe(AEventClass: TClass; const ACallback: TEventCallback);

    { Remove o registro de ACallback para AEventClass.
      Chamado tipicamente em TSystem2D.Shutdown. }
      procedure Unsubscribe(AEventClass: TClass; const ACallback: TEventCallback);

    { Enfileira AEvent para dispatch no próximo Dispatch().
      O EventBus assume ownership: não libere o evento após Publish. }
      procedure Publish(AEvent: TEvent2D);

    { Processa todos os eventos enfileirados na ordem de publicação.
      Eventos publicados durante o Dispatch vão para o próximo ciclo.
      Chamado por TWorld.Update. }
      procedure Dispatch;

    { Descarta a fila sem processar (usado no Shutdown). }
      procedure Clear;
   end;

implementation

{ TEvent2D }
constructor TEvent2D.Create;
begin
   inherited Create;

   Handled := False;
end;

{ TEventSubscriber }
constructor TEventSubscriber.Create(const ACallback: TEventCallback);
begin
   inherited Create;

   Callback := ACallback;
end;

{ TEventBus }
constructor TEventBus.Create;
begin
   inherited Create;

   FHandlers    := THandlerMap.Create;
   FHandlers.Sorted := True;

   { Instancia as filas uma ÚNICA vez na vida útil da Engine }
   FReadQueue   := TEventQueue.Create(True); { True = owns events → libera ao limpar }
   FWriteQueue  := TEventQueue.Create(True);

   FDispatching := False;
end;

destructor TEventBus.Destroy;
var
   I: Integer;
begin
   Clear;
   { Libera cada TSubscriberList (THandlerMap não é owner das values) }
   for I := 0 to FHandlers.Count - 1 do
      FHandlers.Data[I].Free;
   FHandlers.Free;

   FReadQueue.Free;
   FWriteQueue.Free;

   inherited;
end;

procedure TEventBus.Subscribe(AEventClass: TClass; const ACallback: TEventCallback);
var
   Key : Pointer;
   Idx : Integer;
   List: TSubscriberList;
begin
   Key := Pointer(AEventClass);
   Idx := FHandlers.IndexOf(Key);

   if Idx < 0 then
   begin
      List := TSubscriberList.Create(True); { True = owns subscribers }
      FHandlers[Key] := List;
   end
   else
      List := FHandlers.Data[Idx];

   List.Add(TEventSubscriber.Create(ACallback));
end;

procedure TEventBus.Unsubscribe(AEventClass: TClass; const ACallback: TEventCallback);
var
   Key : Pointer;
   Idx , I: Integer;
   List: TSubscriberList;
begin
   Key := Pointer(AEventClass);
   Idx := FHandlers.IndexOf(Key);
   if Idx < 0 then
      Exit;

   List := FHandlers.Data[Idx];

   { Compara as duas partes do method pointer: Code (endereço do método) e Data (ponteiro para a instância — o Self do subscriber). }
   for I := List.Count - 1 downto 0 do
   begin
      if (TMethod(List[I].Callback).Code = TMethod(ACallback).Code) and (TMethod(List[I].Callback).Data = TMethod(ACallback).Data) then
      begin
         List.Delete(I);
         Break;
      end;
   end;
end;

procedure TEventBus.Publish(AEvent: TEvent2D);
begin
   { Eventos chegam sempre na fila de escrita, mas só serão processados no próximo ciclo de Dispatch. }
   FWriteQueue.Add(AEvent);
end;

procedure TEventBus.Dispatch;
var
   I, J      : Integer;
   Event     : TEvent2D;
   TempQueue : TEventQueue;
   Key       : Pointer;
   Idx       : Integer;
   List      : TSubscriberList;
begin
   if FDispatching or (FWriteQueue.Count = 0) then
      Exit;
   FDispatching := True;

   { DOUBLE BUFFERING SWAP:
     A fila que estava recebendo eventos vira a fila de leitura.
     A fila de leitura (que está vazia) vira a nova fila de escrita.
     Isso custa 0 alocações na memória (apenas troca de referências)! }
   TempQueue   := FReadQueue;
   FReadQueue  := FWriteQueue;
   FWriteQueue := TempQueue;

   try
      for I := 0 to FReadQueue.Count - 1 do
      begin
         Event := FReadQueue[I];
         Key   := Pointer(Event.ClassType);
         Idx   := FHandlers.IndexOf(Key);

         if Idx < 0 then
            Continue;

         List := FHandlers.Data[Idx];
         for J := 0 to List.Count - 1 do
         begin
            if Event.Handled then Break;
            List[J].Callback(Event);
         end;
      end;
   finally
      { O .Clear esvazia a fila e (graças ao OwnsObjects=True) chama o .Free automaticamente em todos os TEvent2D iterados. }
      FReadQueue.Clear;
      FDispatching := False;
   end;
end;

procedure TEventBus.Clear;
begin
   { Limpa os eventos pendentes sem destruir o objeto da Fila (OwnsObjects=True) }
   FReadQueue.Clear;
   FWriteQueue.Clear;
end;

end.
