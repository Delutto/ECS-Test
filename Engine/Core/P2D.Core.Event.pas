unit P2D.Core.Event;

{$mode objfpc}{$H+}

interface

uses
   SysUtils,
   fgl;

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
      Handled: boolean;
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
   TEventQueue = specialize TFPGObjectList<TEvent2D>;
   THandlerMap = specialize TFPGMap<Pointer, TSubscriberList>;

   {══════════════════════════════════════════════════════════════════════
    TEventBus
    Central deferred-dispatch event bus with double-buffered queues and
    inheritance-based handler lookup.

    Publish / Dispatch contract
    ───────────────────────────
    Publish  — enqueues the event in FWriteQueue (non-blocking).
    Dispatch — swaps queues and processes FReadQueue. Events published
               during Dispatch land in FWriteQueue and are processed in
               the next Dispatch call, preventing re-entrancy loops.

    Inheritance-based dispatch
    ──────────────────────────
    When an event is dispatched, the bus walks the class hierarchy of the
    event's runtime type upward toward TObject, calling all handlers
    subscribed to each class in the chain. This means:

      - A handler subscribed to TEvent2D (the base) receives every event.
      - A handler subscribed to TPlayerDamagedEvent receives only that
        exact event type and any subclass of it.
      - Exact-class handlers fire before parent-class handlers because
        the walk starts at the concrete type.

    Handled propagation
    ───────────────────
    If any handler sets AEvent.Handled := True, the remaining handlers
    in the current class level are skipped AND the class hierarchy walk
    is also stopped. This preserves the original behavior for exact-class
    dispatch while extending it consistently to the inheritance walk.

    Handler map key
    ───────────────
    Keys are Pointer(AClass) — the class VMT pointer — stored in a sorted
    TFPGMap. The walk therefore performs one IndexOf per level in the
    class hierarchy, typically 2–4 levels deep for game events.
   ══════════════════════════════════════════════════════════════════════ }

   { TEventBus }
   TEventBus = class
   private
      FHandlers: THandlerMap;
      FReadQueue: TEventQueue;
      FWriteQueue: TEventQueue;
      FDispatching: boolean;
      { Exchanges FReadQueue and FWriteQueue by swapping their reference variables. }
      procedure SwapQueues;
   public
      constructor Create;
      destructor Destroy; override;

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

procedure TEventBus.SwapQueues;
var
   Tmp: TEventQueue;
begin
   Tmp := FReadQueue;
   FReadQueue := FWriteQueue;
   FWriteQueue := Tmp;
end;

{ TEventBus }
constructor TEventBus.Create;
begin
   inherited Create;

   FHandlers := THandlerMap.Create;
   FHandlers.Sorted := True;

   { Instancia as filas uma ÚNICA vez na vida útil da Engine }
   FReadQueue := TEventQueue.Create(True); { True = owns events → libera ao limpar }
   FWriteQueue := TEventQueue.Create(True);

   FDispatching := False;
end;

destructor TEventBus.Destroy;
var
   I: Integer;
begin
   Clear;
   { Libera cada TSubscriberList (THandlerMap não é owner das values) }
   for I := 0 to FHandlers.Count - 1 do
   begin
      FHandlers.Data[I].Free;
   end;
   FHandlers.Free;

   FReadQueue.Free;
   FWriteQueue.Free;

   inherited;
end;

procedure TEventBus.Subscribe(AEventClass: TClass; const ACallback: TEventCallback);
var
   Key: Pointer;
   Idx: Integer;
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
   begin
      List := FHandlers.Data[Idx];
   end;

   List.Add(TEventSubscriber.Create(ACallback));
end;

procedure TEventBus.Unsubscribe(AEventClass: TClass; const ACallback: TEventCallback);
var
   Key: Pointer;
   Idx, I: Integer;
   List: TSubscriberList;
begin
   Key := Pointer(AEventClass);
   Idx := FHandlers.IndexOf(Key);
   if Idx < 0 then
   begin
      Exit;
   end;

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
   Event: TEvent2D;
   Cls: TClass;
   Idx: Integer;
   List: TSubscriberList;
   Sub: TEventSubscriber;
   I: Integer;
begin
   if FDispatching or (FWriteQueue.Count = 0) then
   begin
      Exit;
   end;

   { Step 1: swap queues so newly published events are isolated }
   SwapQueues;

   FDispatching := True;
   try
      for I := 0 to FReadQueue.Count - 1 do
      begin
         Event := FReadQueue[I];

         { Step 2: walk the class hierarchy from the concrete type upward }
         Cls := Event.ClassType;
         while Assigned(Cls) and (Cls <> TObject) do
         begin
            Idx := FHandlers.IndexOf(Pointer(Cls));
            if Idx >= 0 then
            begin
               List := FHandlers.Data[Idx];
               for Sub in List do
               begin
                  if Event.Handled then
                  begin
                     Break;
                  end;  { stop subscriber loop }
                  Sub.Callback(Event);
               end;
            end;

            { Stop the hierarchy walk if any handler marked the event handled }
            if Event.Handled then
            begin
               Break;
            end;

            Cls := Cls.ClassParent;
         end;
      end;
   finally
      { Clear FReadQueue: OwnsObjects=True frees all event objects }
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
