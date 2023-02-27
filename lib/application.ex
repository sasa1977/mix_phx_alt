defmodule Demo.Application do
  use Boundary, deps: [Demo.{Core, Config, Helpers, Interface}]
  use Application

  @impl Application
  def start(_type, _args) do
    validate_config()

    Supervisor.start_link(
      [
        {Demo.Core, public_url: Demo.Interface.PublicUrl},
        Demo.Interface
      ],
      strategy: :one_for_one,
      name: __MODULE__
    )
  end

  @impl Application
  def config_change(changed, _new, removed) do
    Demo.Interface.Endpoint.config_change(changed, removed)
    :ok
  end

  defp validate_config do
    # In prod mix env we'll prime the unset OS env vars from the local config script. This is used
    # to simplify running the prod-compiled version on a local dev machine.
    # See `Mix.Tasks.Demo.Gen.DefaultProdConfig` for details.
    for true <- [Demo.Helpers.mix_env() == :prod],
        config_file = "#{Application.app_dir(:demo, "priv")}/local_prod_config.exs",
        {:ok, config} <- [File.read(config_file)],
        {config, _bindings} = Code.eval_string(config),
        {key, value} <- config,
        key = String.upcase(to_string(key)),
        is_nil(System.get_env(key)),
        do: System.put_env(key, to_string(value))

    Demo.Config.validate!()
  end
end
