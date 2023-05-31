defmodule Webathn.Repo do
  use Ecto.Repo,
    otp_app: :webathn,
    adapter: Ecto.Adapters.Postgres
end
