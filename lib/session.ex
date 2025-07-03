defmodule Tg.Session do
  require Logger

  defmodule State do
    @moduledoc "GenServer's state struct"
    @enforce_keys [:bot_module, :session_key, :timeout, :bot_state]
    defstruct [:bot_module, :session_key, :timeout, :bot_state]
  end

  use GenServer, restart: :transient

  # Client

  def start_link({bot_module, session_key, timeout}) do
    GenServer.start_link(__MODULE__, {bot_module, session_key, timeout}, name: Module.concat(bot_module, Registry).via_tuple(session_key))
  end

  def handle_update(bot_module, update, timeout) do
    with {:ok, pid} <- get_session_server(bot_module, update, timeout) do
      GenServer.cast(pid, {:handle_update, update})
    end
  end

  defp get_session_server(bot_module, update, timeout) do
    session_key = update |> bot_module.session_key

    with {:ok, pid} <- Module.concat(bot_module, Registry).lookup(session_key) do
      {:ok, pid}
    else
      _ -> start_session_server({bot_module, session_key, timeout})
    end
  end

  defp start_session_server({bot_module, session_key, timeout}) do
    child_spec = {__MODULE__, {bot_module, session_key, timeout}}
    supervisor = Module.concat(bot_module, SessionSupervisor)
    with {:ok, pid} <- supervisor.start_child(child_spec) do
      {:ok, pid}
    else
      {:error, :max_children} -> Logger.info("Dropped update: reached max children.", bot_module: bot_module)
    end
  end

  # Server (callbacks)

  @impl true
  def init({bot_module, session_key, timeout}) do
    initial_state = %State{bot_module: bot_module, session_key: session_key, timeout: timeout, bot_state: session_key}
    {:ok, initial_state, session_timeout(initial_state, timeout)}
  end

  # @impl true
  # def handle_call(:pop, _from, state) do
  #   [to_caller | new_state] = state
  #   {:reply, to_caller, new_state}
  # end

  @impl true
  def handle_cast({:handle_update, update}, %State{} = state) do
    try do
      state.bot_module.handle_update(update, state.bot_state)
      |> handle_callback_result(state)
    rescue
      error ->
        stacktrace = Exception.format(:error, error, __STACKTRACE__)
        Logger.error(stacktrace)
        state.bot_module.handle_error(error, stacktrace, state.session_key, update, state.bot_state)
        |> handle_callback_result(state)
    end
  end

  @impl true
  def handle_info(:timeout, %State{} = state) do
    Logger.debug("Session for #{inspect(state.session_key)} reached timeout.")
    state.bot_module.handle_timeout(state.session_key, state.bot_state)
    |> handle_callback_result(state)
  end

  @impl true
  def handle_info(msg, %State{} = state) do
    state.bot_module.handle_info(msg, state.session_key, state.bot_state)
    |> handle_callback_result(state)
  end

  defp handle_callback_result({:ok, bot_state}, %State{} = state) do
    {:noreply, %State{state | bot_state: bot_state}, session_timeout_msec(state, :default)}
  end

  defp handle_callback_result({:ok, bot_state, :default}, %State{} = state) do
    {:noreply, %State{state | bot_state: bot_state}, session_timeout_msec(state, :default)}
  end

  defp handle_callback_result({:ok, bot_state, {timeout, next_timeout}}, %State{} = state) do
    {:noreply, %State{state | bot_state: bot_state, timeout: session_timeout(state, next_timeout)}, session_timeout_msec(state, timeout)}
  end

  defp handle_callback_result({:ok, bot_state, timeout}, %State{} = state) do
    {:noreply, %State{state | bot_state: bot_state, timeout: session_timeout(state, timeout)}, session_timeout_msec(state, timeout)}
  end

  defp handle_callback_result({:stop, bot_state}, %State{} = state) do
    Module.concat(state.bot_module, Registry).unregister(state.session_key)
    {:stop, :normal, %State{state | bot_state: bot_state}}
  end

  defp session_timeout(_state, :infinity), do: :infinity
  defp session_timeout(state, :default), do: session_timeout(state, state.timeout)
  defp session_timeout(_state, timeout), do: timeout

  defp session_timeout_msec(state, timeout) do
    timeout_sec = session_timeout(state, timeout)
    if timeout_sec == :infinity, do: timeout_sec, else: timeout_sec * 1000
  end

end