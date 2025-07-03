defmodule Tg.Registry do

  defmacro __using__(_opts) do
    quote(location: :keep) do
      defmodule Registry do

        def start_link do
          Elixir.Registry.start_link(keys: :unique, name: __MODULE__)
        end

        def via_tuple(key) do
          {:via, Elixir.Registry, {__MODULE__, key}}
        end

        def child_spec(_) do
          Supervisor.child_spec(
            Elixir.Registry,
            id: __MODULE__,
            start: {__MODULE__, :start_link, []}
          )
        end

        def lookup(key) do
          with [{pid, _}] <- Elixir.Registry.lookup(__MODULE__, key) do
            {:ok, pid}
          else
            _ -> {:error, :not_found}
          end
        end

        def unregister(key) do
          Elixir.Registry.unregister(__MODULE__, key)
        end

      end
    end
  end

end