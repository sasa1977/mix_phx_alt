defmodule Demo.MixProject do
  use Mix.Project

  def project do
    [
      app: :demo,
      version: "0.1.0",
      elixir: "~> 1.12",
      compilers: [:boundary | Mix.compilers()],
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      preferred_cli_env: preferred_cli_env(),
      deps: deps(),
      dialyzer: dialyzer(),
      boundary: boundary()
    ]
  end

  def application do
    [
      mod: {Demo.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:boundary, "~> 0.9"},
      {:credo, "~> 1.6", runtime: false},
      {:dialyxir, "~> 1.1", runtime: false},
      {:ecto_sql, "~> 3.6"},
      {:esbuild, "~> 0.3", runtime: Mix.env() == :dev},
      {:floki, ">= 0.30.0", only: :test},
      {:jason, "~> 1.2"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.0"},
      {:phoenix_live_dashboard, "~> 0.6"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.17.5"},
      {:phoenix, "~> 1.6.6"},
      {:plug_cowboy, "~> 2.5"},
      {:postgrex, ">= 0.0.0"},
      {:provider, github: "verybigthings/provider"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.deploy": ["esbuild default --minify", "phx.digest"],
      release: ["assets.deploy", "release"],
      "demo.run_ci_checks": [
        "format --check-formatted",
        "test",
        "credo",
        "xref graph --label compile-connected --fail-above 0",
        "dialyzer"
      ],
      "boundary.visualize": ["boundary.visualize", &create_boundary_pngs/1]
    ]
  end

  defp preferred_cli_env do
    ["demo.run_ci_checks": :test, release: :prod]
  end

  defp dialyzer do
    [plt_add_apps: [:ex_unit, :mix]]
  end

  defp boundary do
    [
      default: [
        check: [
          aliases: true,
          apps: [
            {:mix, :runtime}
          ]
        ]
      ]
    ]
  end

  defp create_boundary_pngs(_args) do
    if System.find_executable("dot") do
      png_dir = Path.join(~w/boundary png/)
      File.rm_rf(png_dir)
      File.mkdir_p!(png_dir)

      Enum.each(
        Path.wildcard(Path.join("boundary", "*.dot")),
        fn dot_file ->
          png_file = Path.join([png_dir, "#{Path.basename(dot_file, ".dot")}.png"])
          System.cmd("dot", ~w/-Tpng #{dot_file} -o #{png_file}/)
        end
      )

      Mix.shell().info([:green, "Generated png files in #{png_dir}"])
    else
      Mix.shell().info([:yellow, "Install graphviz package to enable generation of png files."])
    end
  end
end
