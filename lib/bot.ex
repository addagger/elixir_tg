defmodule Tg.Bot do

  defmacro __using__(_opts) do
    bot_module = __CALLER__.module

    config = Application.get_env(:elixir_tg, bot_module)

    token = config |> get_in([:token])

    base_url = config |> get_in([:base_url]) || "https://api.telegram.org"

    max_retries = config |> get_in([:max_retries]) || 5

    finch_specs = (config |> get_in([:finch_specs]) || [
      name: Module.concat(bot_module, Finch),
      pools: %{
        :default => [size: 500, count: 1],
        base_url => [size: 500, count: 1, start_pool_metrics?: true]
      }
    ]) |> Macro.escape

    finch_name = config |> get_in([:finch_name]) || finch_specs[:name]

    max_sessions = config |> get_in([:max_sessions]) || :infinity

    session_timeout = config |> get_in([:session_timeout]) || 60

    poller_tmp_file = config |> get_in([:poller, :tmp_file]) || Tg.Helper.tmp_file(bot_module, token, "poller_offset")

    poller_limit = config |> get_in([:poller, :limit]) || nil

    poller_timeout = config |> get_in([:poller, :timeout]) || 30

    poller_allowed_updates = config |> get_in([:poller, :allowed_updates]) || nil

    poller_inspect_updates = config |> get_in([:poller, :inspect_updates]) || false

    webhook_path = config |> get_in([:webhook, :path]) || Tg.Helper.webhook_path(bot_module, token)

    quote(location: :keep) do
      alias Tg.Types

      require Logger

      use Tg.Registry

      use Tg.Api, [
        token: unquote(token),
        base_url: unquote(base_url),
        max_retries: unquote(max_retries),
        finch_name: unquote(finch_name)
      ]

      use Tg.SessionSupervisor, max_sessions: unquote(max_sessions)

      use Tg.Poller, [
        unquote(bot_module),
        tmp_file: unquote(poller_tmp_file),
        limit: unquote(poller_limit),
        timeout: unquote(poller_timeout),
        allowed_updates: unquote(poller_allowed_updates),
        inspect_updates: unquote(poller_inspect_updates),
        session_timeout: unquote(session_timeout)
      ]

      use Tg.Router, [
        unquote(bot_module),
        session_timeout: unquote(session_timeout),
        webhook_path: unquote(webhook_path)
      ]

      use Supervisor

      def start_link(_opts) do
        Supervisor.start_link(__MODULE__, _opts, name: __MODULE__)
      end

      @impl true
      def init(_opts) do
        Logger.info("Starting #{inspect(__MODULE__)} (Telegram Messenger Bot)")
        children = [
          unquote(bot_module).Registry,
          unquote(bot_module).SessionSupervisor,
          unquote(bot_module).Poller
        ]

        children =
          if unquote(finch_name) == unquote(finch_specs[:name]) do
            children |> List.insert_at(1, {Finch, unquote(finch_specs)})
          else
            children
          end

        Supervisor.init(children, strategy: :one_for_one)
      end

      alias __MODULE__.Api, as: Api
      alias __MODULE__.Uploader, as: Uploader

      ## Front UI ##

      @spec get(String.t()) :: {:ok, any()} | {:error, any()}
      def get(url), do: Api.fetch(:get, url)

      @spec get(String.t(), keyword()) :: {:ok, any()} | {:error, any()}
      def get(url, query), do: Api.fetch(:get, url, query)

      @spec post(String.t(), map() | binary()) :: {:ok, any()} | {:error, any()}
      def post(url, body), do: Api.fetch(:post, url, body)

      @spec post(String.t(), map() | binary(), keyword()) :: {:ok, any()} | {:error, any()}
      def post(url, body, query), do: Api.fetch(:post, url, body, query)

      # DISABLED: Telegram Bot APU supports only GET and POST methods
      #
      # @spec put(String.t(), map() | binary()) :: {:ok, any()} | {:error, any()}
      # def put(url, body), do: Api.fetch(:put, url, body)
      #
      # @spec post(String.t(), map() | binary(), keyword()) :: {:ok, any()} | {:error, any()}
      # def put(url, body, query), do: Api.fetch(:put, url, body, query)
      #
      # @spec patch(String.t(), map() | binary()) :: {:ok, any()} | {:error, any()}
      # def patch(url, body), do: Api.fetch(:patch, url, body)
      #
      # @spec patch(String.t(), map() | binary(), keyword()) :: {:ok, any()} | {:error, any()}
      # def patch(url, body, query), do: Api.fetch(:patch, url, body, query)
      #
      # @spec delete(String.t()) :: {:ok, any()} | {:error, any()}
      # def delete(url), do: Api.fetch(:delete, url)
      #
      # @spec delete(String.t(), keyword()) :: {:ok, any()} | {:error, any()}
      # def delete(url, query), do: Api.fetch(:delete, url, query)

      @spec get_file_path(String.t()) :: String.t()
      def get_file_path(file_id) do
        with {:ok, %{"file_path" => file_path}} <- get("getFile", %{file_id: file_id}) do
          file_path
        end
      end

      @spec download_file_id(String.t()) :: binary()
      def download_file_id(file_id), do: get_file_path(file_id) |> Api.fetch_file

      @spec download_file_path(String.t()) :: binary()
      def download_file_path(file_path), do: file_path |> Api.fetch_file

      ## Behaviour callbacks ##

      @spec handle_update(Types.update(), Types.bot_state()) :: Types.callback_result()
      def handle_update(update, bot_state) do
        inspect(update) |> Logger.info(bot_module: __MODULE__)
        text = "Define function <code>handle_update/2</code> in module <code>#{inspect(__MODULE__)}</code> and create the best chat bot ever for a great good!"
        text |> IO.puts
        chat_id = Tg.Helper.extract_chat_id(update)
        post("sendMessage", text: "Hello world!\n" <> text, parse_mode: "HTML", chat_id: chat_id)
        {:ok, bot_state}
      end

      @spec handle_timeout(Types.session_key(), Types.bot_state()) :: Types.callback_result()
      def handle_timeout(_session_key, bot_state) do
        {:stop, bot_state}
      end

      @spec handle_info(String.t(), Types.session_key(), Types.bot_state()) :: Types.callback_result()
      def handle_info(msg, _session_key, bot_state) do
        Logger.info(msg)
        {:ok, bot_state}
      end

      @spec handle_error(struct(), Exception.Types.stacktrace(), Types.session_key(), Types.update(), Types.bot_state()) :: Types.callback_result()
      def handle_error(_error, _stacktrace, _session_key, _update, bot_state) do
        {:stop, bot_state}
      end

      # Default session_key is {:chat_id, chat_id} or {:user_id, user_id} if chat in unavailable
      @spec session_key(Types.update()) :: Types.session_key()
      def session_key(update) do
        cond do
          chat_id = Tg.Helper.extract_chat_id(update) -> {:chat_id, chat_id}
          user_id = Tg.Helper.extract_user_id(update) -> {:user_id, user_id}
          true -> :default
        end
      end

      defoverridable handle_update: 2, handle_timeout: 2, handle_info: 3, handle_error: 5, session_key: 1

    end
  end

end