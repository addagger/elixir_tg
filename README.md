


# Elixir Tg (Telegram Bot API adapter)

Lightweight:
* Thin! No extra sugar! Just raw official [vendor's API](https://core.telegram.org/bots/api).
* Easy and flexible: one-line deployment with various settings.
* Scalable with [Mint](https://github.com/elixir-mint/mint) & [Finch](https://github.com/sneako/finch)
* [Pluggable](https://hexdocs.pm/plug/readme.html) WebHooks routes for web server.
* Duplicable: means that you can harmoniously use multiple bots in one project, including using one or more different Finch pools or one or more web servers.

## Installation
Add `elixir_tg` to your list of dependencies in `mix.exs`:
```elixir
def deps do
  [
    {:elixir_tg, github: "addagger/elixir_tg"}
  ]
end
```

## Built-in example (Tg.ExampleBot)
Сonfigure Telegram Bot token (config/config.exs):
```elixir
config :elixir_tg, Tg.ExampleBot, token: "9848322304:BBFlkeo4Testrt42lVTYe65RfL8W15SpJkw"
```
Start `Tg.ExampleBot`:

```elixir
children = [Tg.ExampleBot]
opts = [strategy: :one_for_one]
Supervisor.start_link(children, opts)
```
Try in console:
```
% iex -S mix
```
```
iex(1)> Tg.ExampleBot.get("getMe")
```
```
{:ok,
 %{
   "can_connect_to_business" => false,
   "can_join_groups" => true,
   "can_read_all_group_messages" => false,
   "first_name" => "lsbprodlog",
   "has_main_web_app" => false,
   "id" => 30385855858,
   "is_bot" => true,
   "supports_inline_queries" => false,
   "username" => "mybotbotbot"
 }}
```
Then try something to message the bot...

## Setup
### Define your own bot module:
```elixir
defmodule MyBot do
  use Tg.Bot
end
```
This means creating stack of four modules - everything you basically need to create chat bot:
1. `MyBot.Api` - just pre-configured and pre-compiled HTTP client for Telegram Bot API server, which using [Tesla](https://github.com/elixir-tesla/tesla) with [Finch](https://github.com/sneako/finch) adapter, based on [Mint](https://github.com/elixir-mint/mint). Finch is a great tool for managing multiple connections to an API server via a pool. The best alternative to [Hackney](https://github.com/benoitc/hackney) except it much less blackboxed.
2. `MyBot.Poller` - just pre-compiled looping Task process to [getUpdates](https://core.telegram.org/bots/api#getupdates) from the API server. Poller gets updates from an API server and send it to the behaviour module.
3. `MyBot.Router` - [Plug.Router](https://hexdocs.pm/plug/Plug.Router.html) defines routes for Bandit (or Cowboy) webserver, which responsible to handling updates data from API and sending it to the behaviour module.
4. The `MyBot` itself is a behaviour module which defines the main logic of your bot. Each runtime session lives as a GenServer process and cast API updates to a `MyBot.handle_updates/2`. Life-cycle callbacks are also being sended to a behaviour module:
* `MyBot.handle_timeout/2`
* `MyBot.handle_info/3`
* `MyBot.handle_error/5`

All functions are overrideable.

### Configure
All settings are set in the configuration file (config/config.exs).
For example, **necessary and sufficient** would be just Telegram Bot token:

```elixir
config :elixir_tg, MyBot, token: "9848322304:BBFlkeo4Testrt42lVTYe65RfL8W15SpJkw"
```
Full config-defaults for `MyBot` look like this:
```elixir
config :elixir_tg, MyBot,
  token: "9848322304:BBFlkeo4Testrt42lVTYe65RfL8W15SpJkw",
  base_url: "https://api.telegram.org",
  max_retries: 5, # Option for https://hexdocs.pm/tesla/Tesla.Middleware.Retry.html
  finch_specs: [
    name: MyBot.Finch,
    pools: %{
      :default => [size: 500, count: 1],
      "https://api.telegram.org" => [size: 500, count: 1, start_pool_metrics?: true]
    }
  ], # Read https://hexdocs.pm/finch/Finch.html
  finch_name: MyBot.Finch, # You can define your own Finch pool outside
  max_sessions: 500, # How many runtime processes can your bot handle
  session_timeout: 60, # Seconds does a process live when idle.
  poller: [
    tmp_file: "/tmp/MyBot_abcdefg_poller_offset.tmp", # Specify path to the file that contains the latest offset for Poller (update_id+1)
    limit: nil, # getUpdates request parameter, not used if `nil`.
    timeout: 30, # getUpdates request parameter
    allowed_updates: nil, # getUpdates parameter, not used if `nil`
    inspect_updates: true # Inspect updates in console
  ],
  webhook: [
    path: "/tg/randomtoken" # Endpoint for Plug.Router to accept WebHook incomes from API server.
  ]

```

### Starting your Bot (in poller mode by default)
Your `MyBot` is now the supervisor Application itself. Starting `MyBot` you're starting linked `MyBot.Poller` sub-application as well (unless WebHooks parameters is set up to the API server, Poller is cheking it while initializing).
Poller is just pre-compiled looping Task process to [getUpdates](https://core.telegram.org/bots/api#getupdates) from the API server.

Anyway, start your `MyBot` linked as usual (no options provided):

```elixir
children = [MyBot]
opts = [strategy: :one_for_one]
Supervisor.start_link(children, opts)
```

```
22:17:58.627 [info] Running MyBot in polling mode
```
Now your `MyBot.Poller` is looping task to get updates from Telegram.

### Starting in WebHook mode
As mentioned before, you have `MyBot.Router` - [Plug.Router](https://hexdocs.pm/plug/Plug.Router.html) ready to use module.

Then you have to load pluggable webserver if you didn't, [Bandit](https://hexdocs.pm/bandit/Bandit.html) for example. You have to do it on your own, because in many cases one web server can handle multiple task according to your application logic and loading another instance may be redundant. You can create your custom router module and use it sharing between multiple different tasks, who knows.

So if you ready, just plug your `MyBot.Router` after the `MyBot` into the loading chain:
```elixir
children = [MyBot, {Bandit, plug: MyBot.Router, scheme: :http, port: 4000}]
opts = [strategy: :one_for_one]
Supervisor.start_link(children, opts)
```
I use simple example when my web server Bandit accepts everything to port 4000, staying on my local machine. I'm going to accept Telegram WebHook requests through a dedicated Nginx web server which is handling external requests on a world-looking machine, so I need to:
1. Come up with a URL path to which Telegram should send webhook requests. You can create whatever URL path behind your web interface and put it to bot's config parameter like `webhook: [path: "/mybotwebhook"]`.
But *by default* your `MyBot.Router` uses a generated path based on the token and the module name:
```elixir
iex(1)> MyBot.Router.webhook_path
"/tg/PFUm5RFERxrdMFtTfTTvtl9qDrI"
```
Keep in mind that endpoint is used just by your local Bandit instance.
In my case the real world-looking web interface managed by Nginx, thus it is reasonable for me to configure Nginx to `proxy_pass` WebHook request to a local machine. And I couldn't think of anything better than to use almost the same path in the Nginx interface: `/telegram/PFUm5RFERxrdMFtTfTTvtl9qDrI` to accept WebHook request.

2. Next, let's tell Telegram API about URL (or direct IP) for WebHook requests we've just chosen. In my case I use direct IP address instead of domain name:
```elixir
iex(1)> MyBot.Poller.stop
:ok
iex(1)> MyBot.post("setWebhook", %{ip_address: "X.X.X.X", url: "https://X.X.X.X/telegram/PFUm5RFERxrdMFtTfTTvtl9qDrI", certificate: {:file, "/path/to/cert.pem"}})
```
Read [Marvin's Marvellous Guide to All Things Webhook](https://core.telegram.org/bots/webhooks)
Also about [Using self-signed certificates](https://core.telegram.org/bots/self-signed).

3. Now configure Nginx how to `proxy_pass` to my local Bandit web server.
/etc/nginx/nginx.conf:
```nginx
http {
  upstream mybot {
    server X.X.X.X:4000; # Bandit's IP and port
  }
  server {
    listen 443 ssl; # HTTPS
    server_name  X.X.X.X; # ext IP address
    ssl_certificate  /path/to/cert.pem; # Certificate we loaded to Telegram API
    ssl_certificate_key  /path/to/cert.key;
    location /telegram/PFUm5RFERxrdMFtTfTTvtl9qDrI { # Nginx's endpoint
       proxy_pass http://mybot/tg/PFUm5RFERxrdMFtTfTTvtl9qDrI; # Bandit's endpoint
       proxy_set_header Host $host;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Scheme $scheme;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_redirect off;
    }
  }
}
```
That's it. Restart Nginx. Restart `MyBot` Application and everything should work.

## Create your Telegram Bot
All examples are ready to try in `Tg.ExampleBot`.
### handle_update/2:
Each update is sent for processing by callback function `handle_update/2` within your bot module:
Function accepts only 2 arguments: current `update` to process and `bot_state` entity.
* `update` is just a Map respond from API server.
* `bot_state` is an entity to store the current state of the chat. Technically, it is related to the state of the GenServer process and is most often needed to inherit states between user activities according to the application logic.

Bot state lives with a runtime session. Runtime session is linked to the `chat_id` (or `user_id` if no chat id provided) and starts when the first update comes from particular chat (or user). When chat (user) starts runtime session, `bot_state` is passed to `handle_update/2` and it is a copy of the `session_key` at start.
___
**Session key** used in the registry identifier of the [GenServer](https://hexdocs.pm/elixir/GenServer.html) process that represents the runtime session. By default, `session_key` is a tuple `{:chat_id, chat_id}` or `{:user_id, user_id}` which means that session processes are initiated from the uniqueness of the current chat **or** user, simply speaking: each chat has its own process by default. Depending on the logic of your application, the key can be changed by overriding `session_key/1` function:
```elixir
defmodule MyBot do
  use Tg.Bot

  def session_key(update) do
    chat_id = Tg.Helper.extract_chat_id(update)
    user_id = Tg.Helper.extract_user_id(update)
    {chat_id, user_id} # With this key, every user in a group will have his own process.
  end
end
```
Session key could be of any data type of Elixir/Erlang.
___
If your app logic presumes to share any data between user activities, you can use that data as a `bot_state` returning `{:ok, bot_state}` from `handle_update/2`. That the way `bot_state` passes between user actions.
* `bot_state` is an any of Elixir data type.
```elixir
defmodule MyBot do
  use Tg.Bot

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
end
```
This callback function must return one of three possible matches of respond which determine the fate of the current session:
* `{:ok, bot_state}` - bot state is saved and transmitted to the next update processing (next `handle_update/2` call).
* `{:ok, bot_state, timeout}` - same as before, and the idle timeout for session is updated to `timeout` (see next chapter).
 * `{:stop, bot_state}` - stop session gracefully.

### What timeout is?
If the user is inactive, his session is idle. After some time of inactivity, the session is destroyed. This time is determined by the `timeout` (read the GenServer [docs](https://hexdocs.pm/elixir/GenServer.html#module-timeouts) for advance). If the user logs in again, a new session is created.
Sometimes it is very often necessary to adjust the timeout so that the bot waits for the user when it is necessary and does not wait when it is not necessary.
Thus some of responds of the bot has to return `{:ok, bot_state, timeout}` instead of `{:ok, bot_state}`.

`timeout` may be defined as the next data types:
* `pos_integer()`, positive integer, determines **seconds**;
* `:infinity` atom represents infinity timeout when session never expired;
* `:default` atom represents default timeout setting;
* tuple `{timeout_now, timeout_next}` where the first element is to return now, and the second timeout for the next call. Each of them in turn can be `pos_integer()`, `:infinity` or  `:default`. 
```elixir
def handle_update(%{"message" => %{"text" => "wait", "chat" => %{"id" => chat_id}}}, bot_state) do
  post("sendMessage", %{text: "Im waiting 2 minutes", chat_id: chat_id})
  {:ok, bot_state, 120}
end
  ```
### Other callbacks
#### handle_timeout/2
Runs when user session is timed out (when GenServer process received callback to `handle_info(:timeout, state)`, read [here](https://hexdocs.pm/elixir/GenServer.html#module-timeouts)). 
Our `handle_timeout` accepts two args: `session_key` and `bot_state`.
```elixir
def handle_timeout({_, chat_or_user_id}, bot_state) do
  post("sendMessage", %{text: "Bye"}, chat_id: chat_or_user_id)
  {:stop, bot_state}
end
```
 The function is expected to return a value:
 * `{:ok, bot_state}`
 * `{:ok, bot_state, timeout}`
 * `{:stop, bot_state}`
 
#### handle_error/5
Very usefull feature in my own experience.
The function is catching error throws during runtume and responds.
```elixir
def handle_update(%{"message" => %{"text" => "raise", "chat" => %{"id" => _chat_id}}}, _bot_state) do
  raise("Runtime error catched and rescued.")
end
  
def handle_error(error, stacktrace, session_key, update, bot_state) do
  case error do
    %RuntimeError{} ->
      chat_id = Tg.Helper.extract_chat_id(update)
      post("sendMessage", %{chat_id: chat_id, text: error.message})
      {:ok, bot_state}
    _ -> 
      MyBot.Admins.notify_admin(error, stacktrace, update, session_key, bot_state)
      {:ok, bot_state}
  end
end
```
 The function is expected to return a value:
 * `{:ok, bot_state}`
 * `{:ok, bot_state, timeout}`
 * `{:stop, bot_state}`
 
#### handle_info/3
Continuation of the eponymous GenServer [callback](https://hexdocs.pm/elixir/GenServer.html#c:handle_info/2) for customize behaviour.
Callback is not often used, except of catching timeouts, so it's blank by default and just logging incoming messages:
```elixir
 def handle_info(msg, _session_key, bot_state) do
   Logger.info(msg)
   {:ok, bot_state}
 end
 ```
 The function is expected to return a value:
 * `{:ok, bot_state}`
 * `{:ok, bot_state, timeout}`
 * `{:stop, bot_state}`
 
 You are free to override it for your own custom experience.