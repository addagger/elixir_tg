defmodule Tg.SessionSupervisor do

  defmacro __using__(opts) do
    quote(location: :keep) do
      defmodule SessionSupervisor do
        use DynamicSupervisor

        def start_link(_) do
          DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
        end

        def start_child(child_spec) do
          DynamicSupervisor.start_child(__MODULE__, child_spec)
        end

        @impl true
        def init(_) do
          DynamicSupervisor.init(strategy: :one_for_one, max_children: unquote(opts[:max_sessions]))
        end
      end

    end
  end

end