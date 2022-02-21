defmodule Demo.Test.Client do
  import Phoenix.ConnTest
  import Demo.Test.ConnCase
  import Demo.Helpers

  # credo:disable-for-next-line Credo.Check.Readability.AliasAs
  alias Demo.Interface.Router.Helpers, as: Routes

  # The default endpoint for testing
  # using String.to_atom to avoid compile-time dep to the endpoint
  @endpoint String.to_atom("Elixir.Demo.Interface.Endpoint")

  def logged_in?(conn) do
    conn = conn |> recycle() |> get(Routes.user_path(conn, :welcome))
    conn.status == 200 and conn.assigns.current_user != nil
  end

  def register!(params \\ %{}) do
    params = Map.merge(valid_registration_params(), Map.new(params))

    start_registration!(params.email)
    |> finish_registration!(params.password)
  end

  def start_registration!(email) do
    {:ok, token} = start_registration(email)
    false = is_nil(token)
    token
  end

  def start_registration(email) do
    conn = post(build_conn(), "/start_registration", %{user: %{email: email}})
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

  def finish_registration!(token, password) do
    {:ok, conn} = finish_registration(token, password)
    conn
  end

  def finish_registration(token, password) do
    conn = post(build_conn(), "/finish_registration/#{token}", %{user: %{password: password}})

    with :ok <- validate(conn.status == 302, conn) do
      conn = conn |> recycle() |> get(redirected_to(conn))
      200 = conn.status
      {:ok, conn}
    end
  end

  def valid_registration_params, do: %{email: new_email(), password: new_password()}

  def new_email, do: "#{unique("username")}@foo.bar"
  def new_password, do: unique("12345678901")

  def login!(params) do
    {:ok, conn} = login(params)
    conn
  end

  def login(params) do
    params = Map.merge(%{remember: "false"}, Map.new(params))
    conn = post(build_conn(), "/login", %{user: params})

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

  def start_password_reset!(email) do
    {:ok, token} = start_password_reset(email)
    false = is_nil(token)
    token
  end

  def start_password_reset(email) do
    conn = post(build_conn(), "/start_password_reset", %{user: %{email: email}})
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

  def reset_password!(token, password) do
    {:ok, conn} = reset_password(token, password)
    conn
  end

  def reset_password(token, password) do
    conn = post(build_conn(), "/reset_password/#{token}", user: %{password: password})

    with :ok <- validate(conn.status == 302, conn) do
      conn = conn |> recycle() |> get(redirected_to(conn))
      200 = conn.status
      {:ok, conn}
    end
  end
end
