defmodule Demo.Core.Mailer do
  use Swoosh.Mailer, otp_app: :demo
  import Demo.Helpers
  require Logger

  @type mailbox :: String.t() | Swoosh.Email.mailbox()

  @spec send(mailbox | [mailbox], String.t(), String.t()) :: :ok | :error
  def send(to, subject, body) do
    %Swoosh.Email{
      from: {"Demo App", "noreply@demo.app"},
      subject: subject,
      to: to |> List.wrap() |> Enum.map(&to_swoosh_mailbox/1),
      text_body: body
    }
    |> deliver(config())
    |> case do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.error("error delivering email: #{inspect(reason)}")
        :error
    end
  end

  defp to_swoosh_mailbox({_, _} = mailbox), do: mailbox
  defp to_swoosh_mailbox(address) when is_binary(address), do: {nil, address}

  defp config do
    [
      adapter: if(mix_env() == :test, do: Swoosh.Adapters.Test, else: Swoosh.Adapters.Local)
    ]
  end
end
