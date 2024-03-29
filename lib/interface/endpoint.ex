defmodule Demo.Interface.Endpoint do
  use Phoenix.Endpoint, otp_app: :demo

  # ------------------------------------------------------------------------
  # Childspec
  # ------------------------------------------------------------------------

  # overriding child spec to provide the hardcoded endpoint options
  defoverridable child_spec: 1

  @spec child_spec(any) :: Supervisor.child_spec()
  def child_spec(_arg) do
    [
      http: [port: 4000],
      url: Demo.Config.public_url() |> URI.parse() |> Map.take(~w/scheme host port path/),
      secret_key_base: Demo.Config.secret_key_base(),
      render_errors: [formats: [html: Demo.Interface.Error.Html], layout: false],
      pubsub_server: Demo.PubSub,
      live_view: [signing_salt: "lM/3bilV"]
    ]
    |> deep_merge(endpoint_opts(Demo.Helpers.mix_env()))
    |> super()
  end

  defp endpoint_opts(:dev) do
    [
      # Binding to loopback ipv4 address prevents access from other machines.
      # We also use smaller acceptor pools in dev for endpoints and repo. We shouldn't issue a huge
      # load in dev mode anyway, and less processes makes the supervision tree view in observer
      # nicer.
      http: [ip: {127, 0, 0, 1}, transport_options: [num_acceptors: 10]],
      check_origin: false,
      watchers: [
        esbuild: {Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]}
      ],
      live_reload: [
        patterns: [
          ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
          ~r"lib/interface/.*/html.ex$",
          ~r"lib/interface/.*/html/.*(heex)$",
          ~r"priv/gettext/.*(po)$"
        ]
      ]
    ]
  end

  defp endpoint_opts(:test) do
    [
      # Binding to loopback ipv4 address prevents access from other machines.
      http: [ip: {127, 0, 0, 1}],
      server: false
    ]
  end

  defp endpoint_opts(:prod) do
    [
      http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
      cache_static_manifest: "priv/static/cache_manifest.json",
      server: true
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
    only: Demo.Interface.Base.Routes.static_paths()

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
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint], log: :debug

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug Demo.Interface.Router
end
