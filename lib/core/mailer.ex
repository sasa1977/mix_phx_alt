defmodule Demo.Core.Mailer do
  use Oban.Worker, queue: :mailer
  use Swoosh.Mailer, otp_app: :demo

  import Demo.Helpers
  require Logger

  @type mailbox :: String.t() | Swoosh.Email.mailbox()

  @spec enqueue(String.t(), String.t(), String.t()) :: :ok
  def enqueue(email, subject, body) do
    %{email: email, subject: subject, body: body}
    |> new()
    |> Oban.insert!()

    :ok
  end

  @impl Oban.Worker
  def perform(oban_job) do
    send(
      Map.fetch!(oban_job.args, "email"),
      Map.fetch!(oban_job.args, "subject"),
      Map.fetch!(oban_job.args, "body")
    )
  end

  defp send(to, subject, body) do
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
