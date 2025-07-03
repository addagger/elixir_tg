defmodule Tg.Api do
  require Logger

  defmacro __using__(opts) do
    quote(location: :keep) do
      defmodule Api do
        @api_path "/bot#{unquote(opts[:token])}/"
        @api_file_path "/file/bot#{unquote(opts[:token])}/"

        require Logger

        def client do
          Tesla.client([
            {Tesla.Middleware.BaseUrl, unquote(opts[:base_url])},
            {Tesla.Middleware.Retry, max_retries: unquote(opts[:max_retries]),
               should_retry: fn
                 {:ok, %{status: status}}, _env, _context when status in [400, 500] -> true
                 {:ok, %{status: status}}, _env, _context when status in [429] ->
                   Logger.warning("Telegram Bot API throttling, HTTP 429 'Too Many Requests'")
                   true
                 {:ok, _reason}, _env, _context -> false
                 # {:error, _reason}, %Tesla.Env{method: :post}, _context -> false
                 # {:error, _reason}, %Tesla.Env{method: :put}, %{retries: 2} -> false
                 {:error, _reason}, _env, _context -> true
               end},

            Tesla.Middleware.JSON
          ], {Tesla.Adapter.Finch, name: unquote(opts[:finch_name])})
        end

        # Коды ответов HTTP
        #
        # 200 — успешная операция
        # 400 — недействительный запрос
        # 401 — ошибка аутентификации
        # 404 — ресурс не найден
        # 405 — метод не допускается
        # 429 — превышено количество запросов
        # 503 — сервис недоступен

        def fetch(method, api_method, body, query) when is_list(query), do: fetch(method: method, url: @api_path <> api_method, body: body, query: query)
        def fetch(method, api_method, query) when is_list(query), do: fetch(method: method, url: @api_path <> api_method, query: query)
        def fetch(method, api_method, body), do: fetch(method: method, url: @api_path <> api_method, body: body)
        def fetch(method, api_method), do: fetch(method: method, url: @api_path <> api_method)
        def fetch(args) do
          args =
            cond do
              sending_file?(args[:body]) -> Keyword.put(args, :body, multipart_body(args[:body]))
              sending_file?(args[:query]) -> Keyword.put(args, :body, multipart_body(args[:query])) |> Keyword.delete(:query)
              true -> args
            end

          with {:ok, %Tesla.Env{status: status, body: body}} <- Tesla.request(client(), args) do
            if status in (200..299) do
              with %{"ok" => true, "result" => result} <- body do
                # If 'ok' equals True, the request was successful and the result of the query can be found in the 'result' field. In case of an unsuccessful request, 'ok' equals false and the error is explained in the 'description'. An Integer 'error_code' field is also returned
                {:ok, result}
              else
                _ -> body
              end
            else
              comment = case status do
                400 -> "Invalid request"
                401 -> "Authentication error"
                404 -> "Resource not found"
                405 -> "Method not allowed"
                # 429 -> "Request limit exceeded"
                503 -> "Service unavailable"
                _ -> "Unknown error"
              end
              Logger.warning("Telegram Bot API error requesting #{fetch_args_info(args)} responded HTTP #{status}: '#{comment}'\nResponse body: #{inspect(body)}")
              {:error, body}
            end
          else
            {:error, :timeout} -> {:error, :timeout}
            {:error, error} ->
              Logger.warning("Telegram Bot API connection error #{fetch_args_info(args)}: #{inspect(error)}")
              {:error, error}
          end
        end

        def fetch_args_info(args) do
          "#{args[:method] |> to_string |> String.upcase} #{args[:url] |> String.replace(unquote(opts[:token]), "<token>")}"
        end

        defp sending_file?([]), do: false
        defp sending_file?(nil), do: false
        defp sending_file?(body_or_query) when body_or_query == %{}, do: false
        defp sending_file?(body_or_query) do
          Enum.any?(body_or_query, &(match?({_name, {:file, _}}, &1) or match?({_name, {:file_content, _, _}}, &1)))
        end

        defp multipart_body(body_or_query) do
          Enum.reduce(body_or_query, Tesla.Multipart.new(), fn
            {name, {:file, file}}, multipart ->
              %{size: size} = File.stat!(file)
              Tesla.Multipart.add_file(multipart, file, name: to_string(name), headers: [{"content-length", to_string(size)}])

            {name, {:file_content, file_content, filename}}, multipart ->
              size = byte_size(file_content)
              Tesla.Multipart.add_file_content(multipart, file_content, filename, name: to_string(name), headers: [{"content-length", to_string(size)}])

            {name, value}, multipart ->
              Tesla.Multipart.add_field(multipart, to_string(name), to_string(value))
          end)
          |> Tesla.Multipart.add_content_type_param("multipart/form-data")
        end

        def file_path(file_path), do: @api_file_path <> file_path
        def fetch_file(file_path), do: fetch(method: :get, url: file_path(file_path))

      end

    end
  end

end