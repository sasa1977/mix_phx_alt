# Demo

## Local development

  - Prerequisites:
    - Elixir and Erlang, as specified in .tool-versions
    - A running PostgreSQL server instance, listening on port 5432, having the user `postgres` with the password `postgres`.
  - (Re)initializing the database: `mix ecto.reset`
  - Running tests: `mix test`
  - Running a local development server: `iex -S mix phx.server`

  - Running a prod-compiled version locally:

        mix demo.gen.default_prod_config
        mix assets.deploy
        MIX_ENV=prod iex -S mix

  - Building the OTP release and running it locally:

        mix demo.gen.default_prod_config
        mix release
        _build/prod/rel/demo/bin/demo start_iex

  - Building the Docker image and running it locally:

        mix demo.gen.default_prod_config
        docker build . -t demo
        docker run --rm -it --net=host demo
