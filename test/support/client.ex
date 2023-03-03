defmodule Demo.Test.Client do
  use Demo.Interface.Routes

  import Phoenix.ConnTest
  import Demo.Test.ConnCase
  import Demo.Helpers
  import Ecto.Query

  alias Demo.Core.{Model, Repo, User}

  # The default endpoint for testing
  # using String.to_atom to avoid compile-time dep to the endpoint
  @endpoint String.to_atom("Elixir.Demo.Interface.Endpoint")

  @spec logged_in?(Plug.Conn.t()) :: boolean
  def logged_in?(conn) do
    conn = conn |> recycle() |> get(~p"/")
    conn.status == 200 and conn.assigns.current_user != nil
  end

  @spec register!(Keyword.t() | map) :: Plug.Conn.t()
  def register!(params \\ %{}) do
    params = Map.merge(valid_registration_params(), Map.new(params))

    start_registration(params.email)
    |> ok!()
    |> finish_registration(params.password)
    |> ok!()
  end

  @spec start_registration(String.t()) ::
          {:ok, User.confirm_email_token() | nil} | {:error, Plug.Conn.t()}
  def start_registration(email) do
    conn = post(build_conn(), "/start_registration", %{form: %{email: email}})
    200 = conn.status

    if conn.resp_body =~ "The email with further instructions has been sent to #{email}",
      do: {:ok, confirm_email_token(email)},
      else: {:error, conn}
  end

  defp confirm_email_token(email) do
    receive do
      {:email, %{to: [{nil, ^email}], subject: "Registration"} = registration_email} ->
        ~r[http://.*/finish_registration/(?<token>.*)]
        |> Regex.named_captures(registration_email.text_body)
        |> Map.fetch!("token")
    after
      0 -> nil
    end
  end

  @spec finish_registration(User.confirm_email_token(), String.t()) ::
          {:ok | :error, Plug.Conn.t()}
  def finish_registration(token, password) do
    conn = post(build_conn(), "/finish_registration/#{token}", %{form: %{password: password}})

    with :ok <- validate(conn.status == 302, conn) do
      conn = conn |> recycle() |> get(redirected_to(conn))
      200 = conn.status
      {:ok, conn}
    end
  end

  @spec valid_registration_params :: map
  def valid_registration_params, do: %{email: new_email(), password: new_password()}

  @spec new_email :: String.t()
  def new_email, do: "#{unique("username")}@foo.bar"

  @spec new_password :: String.t()
  def new_password, do: unique("12345678901")

  @spec login(Keyword.t() | map) :: {:ok | :error, Plug.Conn.t()}
  def login(params) do
    params = Map.merge(%{remember: "false"}, Map.new(params))
    conn = post(build_conn(), "/login", %{form: params})

    if params.remember == "true" do
      %{"auth_token" => %{max_age: max_age, same_site: "Lax"}} = conn.resp_cookies
      ^max_age = Demo.Core.Model.Token.validity(:auth) * 24 * 60 * 60
    end

    with :ok <- validate(conn.status == 302, conn) do
      conn = conn |> recycle() |> get(redirected_to(conn))
      200 = conn.status
      {:ok, conn}
    end
  end

  @spec start_password_reset(String.t()) ::
          {:ok, User.password_reset_token() | nil} | {:error, Plug.Conn.t()}
  def start_password_reset(email) do
    conn = post(build_conn(), "/start_password_reset", %{form: %{email: email}})
    200 = conn.status

    if conn.resp_body =~ "The email with further instructions has been sent to #{email}",
      do: {:ok, password_reset_token(email)},
      else: {:error, conn}
  end

  defp password_reset_token(email) do
    receive do
      {:email, %{to: [{nil, ^email}], subject: "Password reset"} = mail} ->
        ~r[http://.*/reset_password/(?<token>.*)]
        |> Regex.named_captures(mail.text_body)
        |> Map.fetch!("token")
    after
      0 -> nil
    end
  end

  @spec reset_password(User.password_reset_token(), String.t()) :: {:ok | :error, Plug.Conn.t()}
  def reset_password(token, password) do
    conn = post(build_conn(), "/reset_password/#{token}", form: %{password: password})

    with :ok <- validate(conn.status == 302, conn) do
      conn = conn |> recycle() |> get(redirected_to(conn))
      200 = conn.status
      {:ok, conn}
    end
  end

  defmacro update_last_token(set) do
    quote do
      import Ecto.Query

      {1, _} =
        Repo.update_all(
          from(token in Model.Token,
            where:
              token.id in subquery(
                from last_token in Model.Token,
                  order_by: [desc: :inserted_at],
                  limit: 1,
                  select: last_token.id
              ),
            update: [set: unquote(set)]
          ),
          []
        )

      :ok
    end
  end

  @spec expire_last_token :: :ok
  def expire_last_token do
    last_token = Repo.one!(from Model.Token, limit: 1, order_by: [desc: :inserted_at])
    days = Model.Token.validity(last_token.type)
    inserted_at = DateTime.utc_now() |> DateTime.add(-days * 24 * 60 * 60, :second)
    update_last_token(inserted_at: ^inserted_at)
  end
end
