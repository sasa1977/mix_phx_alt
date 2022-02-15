defmodule Demo.Interface.Endpoint do
  use Phoenix.Endpoint, otp_app: :demo

  # ------------------------------------------------------------------------
  # Initialization
  # ------------------------------------------------------------------------

  @impl Phoenix.Endpoint
  def init(_context, config) do
    opts =
      config
      |> deep_merge(
        url: [host: "localhost"],
        render_errors: [view: Demo.Interface.Error.View, accepts: ~w(html json), layout: false],
        pubsub_server: Demo.PubSub,
        live_view: [signing_salt: "lM/3bilV"]
      )
      |> deep_merge(endpoint_opts(Demo.Config.mix_env()))

    {:ok, opts}
  end

  defp endpoint_opts(:dev) do
    [
      # Binding to loopback ipv4 address prevents access from other machines.
      http: [ip: {127, 0, 0, 1}, port: 4000],
      check_origin: false,
      secret_key_base: "6SQyoN0wWViSTd5UaarW/wZsqTX0sFgYqYfGZpehG2s6kCwJOSiVVaiLBUO5oUdB",
      watchers: [
        esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
      ],
      live_reload: [
        patterns: [
          ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
          ~r"lib/interface/(live|views)/.*(ex)$",
          ~r"lib/interface/templates/.*(eex)$"
        ]
      ]
    ]
  end

  defp endpoint_opts(:test) do
    [
      # Binding to loopback ipv4 address prevents access from other machines.
      http: [ip: {127, 0, 0, 1}, port: 4002],
      secret_key_base: "K0Qh5bXJnroiweVp9bE07TKC1BeaLYxmJ61HRU9D6u6K0+UqCfCUSyyF9UMyODvz",
      server: false
    ]
  end

  defp endpoint_opts(:prod) do
    secret_key_base =
      System.get_env("SECRET_KEY_BASE") ||
        raise """
        environment variable SECRET_KEY_BASE is missing.
        You can generate one by calling: mix phx.gen.secret
        """

    host = System.get_env("PHX_HOST") || "example.com"
    port = String.to_integer(System.get_env("PORT") || "4000")

    server_opt =
      if System.get_env("PHX_SERVER") && System.get_env("RELEASE_NAME"),
        do: [server: true],
        else: []

    server_opt ++
      [
        url: [host: host, port: 443],
        http: [
          ip: {0, 0, 0, 0, 0, 0, 0, 0},
          port: port
        ],
        secret_key_base: secret_key_base,
        cache_static_manifest: "priv/static/cache_manifest.json"
      ]
  end

  defp deep_merge(list1, list2) do
    # Config.Reader.merge requires a top-level format of `key: kw-list`, so we're using the `:opts` key
    [opts: list1]
    |> Config.Reader.merge(opts: list2)
    |> Keyword.fetch!(:opts)
  end

  # ------------------------------------------------------------------------
  # Plugs and sockets
  # ------------------------------------------------------------------------

  @session_options [
    store: :cookie,
    key: "_demo_key",
    signing_salt: "HWgf0hhS"
  ]

  socket "/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :demo,
    gzip: false,
    only: ~w(assets fonts images favicon.ico robots.txt)

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :demo
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug Demo.Interface.Router
end
