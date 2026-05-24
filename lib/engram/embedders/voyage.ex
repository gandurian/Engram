defmodule Engram.Embedders.Voyage do
  @moduledoc """
  Voyage AI embedder adapter. Calls the Voyage AI REST API via Req.
  Reads config: VOYAGE_API_KEY, EMBED_MODEL (default voyage-4-large).
  """

  @behaviour Engram.Embedder

  @default_url "https://api.voyageai.com"
  @default_model "voyage-4-large"

  @impl true
  def model_info do
    %{
      model: Application.get_env(:engram, :embed_model, @default_model),
      dimensions: Application.get_env(:engram, :embed_dims, 1024)
    }
  end

  @impl true
  def embed_texts(texts) when is_list(texts), do: embed_texts(texts, [])

  @impl true
  def embed_texts(texts, opts) when is_list(texts) do
    with :ok <- throttle_check() do
      do_embed_texts(texts, opts)
    end
  end

  defp do_embed_texts(texts, opts) do
    url = Application.get_env(:engram, :voyage_url, @default_url)
    model = Keyword.get(opts, :model, Application.get_env(:engram, :embed_model, @default_model))

    api_key =
      Application.get_env(:engram, :voyage_api_key) ||
        raise "VOYAGE_API_KEY not configured (set VOYAGE_API_KEY env var)"

    {req_opts, _} = Keyword.split(opts, [:retry, :max_retries, :receive_timeout])

    result =
      Req.post(
        "#{url}/v1/embeddings",
        [
          json: %{input: texts, model: model},
          headers: [{"authorization", "Bearer #{api_key}"}],
          receive_timeout: 30_000,
          retry: :transient,
          max_retries: 3
        ] ++ req_opts
      )

    case result do
      {:ok, %{status: 200, body: %{"data" => data}}} ->
        vectors = Enum.map(data, & &1["embedding"])
        {:ok, vectors}

      {:ok, %{status: status, body: body}} ->
        {:error, {status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Client-side rate limit. Enabled when `:voyage_rpm` is set (env: VOYAGE_RPM).
  # When the bucket is empty we synthesize the same `{:error, {429, body}}`
  # shape Voyage returns on a real rate-limit response, so callers (notably
  # `Engram.Workers.EmbedNote`) handle both paths identically — the
  # snooze-on-429 logic fires for either case.
  #
  # Bucket key is `:voyage_throttle_key` (default "voyage_embed") so tests can
  # use per-test keys to avoid collisions on the shared ETS limiter table.
  defp throttle_check do
    case Application.get_env(:engram, :voyage_rpm) do
      nil ->
        :ok

      rpm when is_integer(rpm) and rpm > 0 ->
        key = Application.get_env(:engram, :voyage_throttle_key, "voyage_embed")

        case EngramWeb.RateLimiter.hit(key, 60_000, rpm) do
          {:allow, _count} ->
            :ok

          {:deny, retry_after_ms} ->
            :telemetry.execute(
              [:engram, :embed, :client_rate_limited],
              %{count: 1, retry_after_ms: retry_after_ms},
              %{rpm: rpm}
            )

            {:error,
             {429, %{"detail" => "client_rate_limited", "retry_after_ms" => retry_after_ms}}}
        end
    end
  end
end
