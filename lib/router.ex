defmodule Tg.Router do

  defmacro __using__([bot_module | opts]) do
    quote(location: :keep) do
      defmodule Router do
        @moduledoc false

        require Logger

        use Plug.Router

        plug :match
        plug Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason
        plug :dispatch

        def webhook_path, do: unquote(opts[:webhook_path])

        post unquote(opts[:webhook_path]) do
          update = var!(conn).body_params

          Logger.debug("Tg update: #{inspect(update)}", bot: unquote(bot_module))

          Tg.Session.handle_update(unquote(bot_module), update, unquote(opts[:session_timeout]))
          send_resp(var!(conn), :ok, "")
        end

        match _ do
          send_resp(var!(conn), :not_found, "")
        end
      end

    end

  end
end
