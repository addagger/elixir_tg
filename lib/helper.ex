defmodule Tg.Helper do

  def extract_chat_id(update) do
    Enum.find_value(update, fn
      {_update_type, %{"chat" => %{"id" => chat_id}}} -> chat_id
      {_update_type, %{"message" => %{"chat" => %{"id" => chat_id}}}} -> chat_id
      {_update_type, %{"user_chat_id" => chat_id}} -> chat_id
      _ -> nil
    end)
  end

  def extract_user_id(update) do
    Enum.find_value(update, fn
      {_update_type, %{"from" => %{"id" => user_id}}} -> user_id
      {_update_type, %{"sender_business_bot" => %{"id" => user_id}}} -> user_id
      {_update_type, %{"via_bot" =>  %{"id" => user_id}}} -> user_id
      {_update_type, %{"user" => %{"id" => user_id}}} -> user_id
      _ -> nil
    end)
  end

  def extract_chat_user(update) do
    Enum.find_value(update, fn
      # update_type with entity: Message, ChatMemberUpdated, ChatJoinRequest
      {update_type, %{"from" => %{"id" => _} = user, "chat" => %{"id" => _} = chat}} ->
        {update_type, %{chat: chat, user: user}}

      # update_type with entity: Message sent on behalf of the business account
      {update_type, %{"sender_business_bot" => %{"id" => _} = user, "chat" => %{"id" => _} = chat}} ->
        {update_type, %{chat: chat, user: user}}

      # update_type with entity: Message sent by bot
      {update_type, %{"via_bot" => %{"id" => _} = user, "chat" => %{"id" => _} = chat}} ->
        {update_type, %{chat: chat, user: user}}

      # update_type with entity: Message sent to channels, ChatBoostUpdated, ChatBoostRemoved, BusinessMessageDeleted
      {update_type, %{"chat" => %{"id" => _} = chat}} ->
        {update_type, %{chat: chat}}

      # update_type with entity: BusinessConnection
      {update_type, %{"user" => %{"id" => _} = user, "user_chat_id" => chat_id}} ->
        {update_type, %{chat: %{"id" => chat_id}, user: user}}

      # update_type with entity: MessageReactionUpdated
      {update_type, %{"user" => %{"id" => _} = user, "chat" => %{"id" => _} = chat}} ->
        {update_type, %{chat: chat, user: user}}

      # update_type with entity: CallbackQuery
      {update_type, %{"from" => %{"id" => _} = user, "message" => %{"chat" => %{"id" => _} = chat}}} ->
        {update_type, %{user: user, chat: chat}}

      # update_type with entity: InlineQuery, ChosenInlineResult, ShippingQuery, PreCheckoutQuery, PaidMediaPurchased,
      {update_type, %{"from" => %{"id" => _} = user}} ->
        {update_type, %{user: user}}

      # update_type with unknown entity
      {update_type, _} ->
        {update_type, %{}}

      _ -> {}
    end)
  end

  def tmp_file(bot_module, token, option \\ nil) do
    System.tmp_dir() <> "#{bot_module}_#{encode_bot_id(bot_module, token)}_#{option}.tmp"
  end

  def webhook_path(bot_module, token) do
    "/tg/#{encode_bot_id(bot_module, token)}"
  end

  def encode_bot_id(bot_module, token) do
    :crypto.hash(:sha, :erlang.term_to_binary([bot_module, token])) |> Base.url_encode64(padding: false)
  end

end