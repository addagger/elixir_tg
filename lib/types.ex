defmodule Tg.Types do

  @type update() :: map()
  @type bot_state() :: any()
  @type chat_id() :: integer()
  @type user_id() :: integer()
  @type session_key() :: any()
  @type session_timeout() :: timeout() | :default | {timeout() | :default, timeout() | :default}
  @type file_or_content() :: {:file, String.t()} | {:file_content, binary(), String.t()}
  @type callback_result() :: {:ok, Types.bot_state()} | {:ok, Types.bot_state(), Types.session_timeout()} | {:stop, Types.bot_state()}

end