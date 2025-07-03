defmodule Tg.Poller do

  defmacro __using__([bot_module | opts]) do
    quote(location: :keep) do
      defmodule Poller do
        alias __MODULE__.PollerTask, as: PollerTask

        use Supervisor, restart: :transient

        def start_link(_) do
          with {:ok, %{"url" => url}} <- unquote(bot_module).get("getWebhookInfo"),
               true <- (url != "") do
            Logger.info("Running #{unquote(bot_module)} in webhook mode for url: #{url}")
            :ignore
          else
            _ -> Supervisor.start_link(__MODULE__, nil, name: __MODULE__)
          end
        end

        @impl true
        def init(_) do
          children = [
            Supervisor.child_spec({PollerTask, unquote(bot_module)}, id: __MODULE__)
          ]
          Supervisor.init(children, strategy: :one_for_one)
        end
        
        def stop do
          Supervisor.stop(__MODULE__, :shutdown)
          Logger.info("#{inspect(__MODULE__)} stopped.")
        end

        defmodule PollerTask do
          require Logger

          use Task, restart: :permanent

          def start_link(bot_module) do
            Task.start_link(__MODULE__, :run, [bot_module])
          end

          def run(bot_module) do
            Logger.metadata(bot: bot_module)
            Logger.info("Running #{inspect(bot_module)} in polling mode")

            query = [timeout: unquote(opts[:timeout])]
            query = if offset = read_offset_tmp(), do: Keyword.put(query, :offset, offset), else: query
            query = if unquote(opts[:limit]), do: Keyword.put(query, :limit, unquote(opts[:limit])), else: query
            query = if unquote(opts[:allowed_updates]), do: Keyword.put(query, :allowed_updates, unquote(opts[:allowed_updates])), else: query

            loop(bot_module, query)
          end

          defp loop(bot_module, query \\ []) do
            with {:ok, updates} <- bot_module.get("getUpdates", query) do
              offset = if updates == [], do: query[:offset], else: (List.last(updates) |> Map.get("update_id"))+1
              write_offset_tmp(offset)

              if unquote(opts[:inspect_updates]) do
                Logger.info("#{inspect(bot_module)} updates received (next offset: #{offset})")
                IO.inspect(updates)
              end

              Enum.each(updates, fn %{"update_id" => update_id} = update ->
                Tg.Session.handle_update(bot_module, update, unquote(opts[:session_timeout]))
              end)
              loop(bot_module, Keyword.put(query, :offset, offset))
            else
              {:error, :timeout} ->
                loop(bot_module, query)
              _ ->
                Process.sleep(1000)
                loop(bot_module, query)
            end
          end

          defp write_offset_tmp(marker) do
            File.write(unquote(opts[:tmp_file]), :erlang.term_to_binary(marker))
          end

          defp read_offset_tmp do
            with {:ok, binary} <- File.read(unquote(opts[:tmp_file])) do
              binary |> :erlang.binary_to_term
            else
              _ -> nil
            end
          end

        end
      end

    end

  end
end
