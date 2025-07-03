defmodule Tg.ExampleBot do
  use Tg.Bot

  def handle_update(%{"message" => %{"text" => "wait", "chat" => %{"id" => chat_id}}}, bot_state) do
    post("sendMessage", %{text: "Im waiting 2 minutes", chat_id: chat_id})
    {:ok, bot_state, 120}
  end

  def handle_update(%{"message" => %{"text" => "raise", "chat" => %{"id" => _chat_id}}}, _bot_state) do
    raise("Runtime error catched and rescued.")
  end

  def handle_update(%{"message" => %{"chat" => %{"id" => chat_id}, "from" => user}}, bot_state) do
    bot_state = if not is_integer(bot_state), do: 1, else: bot_state+1
    # this function just count messages during the session
    username = user["first_name"]
    post("sendMessage", %{text: "Hello, #{username}. You messaged #{bot_state} times.", chat_id: chat_id})
    {:ok, bot_state}
  end

  def handle_update(_update, bot_state) do
    {:ok, bot_state} # just return bot_state
  end

  def handle_error(error, _stacktrace, _session_key, update, bot_state) do
    case error do
      %RuntimeError{} ->
        chat_id = Tg.Helper.extract_chat_id(update)
        post("sendMessage", %{chat_id: chat_id, text: error.message})
        {:ok, bot_state}
      _ ->
        # MyBot.Admins.notify_admin(error, stacktrace, update, session_key, bot_state)
        {:ok, bot_state}
    end
  end

  def handle_timeout({_, chat_or_user_id}, bot_state) do
    post("sendMessage", %{text: "Bye"}, chat_id: chat_or_user_id)
    {:stop, bot_state}
  end

end