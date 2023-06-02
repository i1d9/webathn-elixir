defmodule Webathn.Accounts.AuthSession do
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Webathn.Repo

  schema "auth_sessions" do
    field :secret, :string
    field :activated_at, :naive_datetime
    field :deactivated_at, :naive_datetime
    belongs_to :user, Webathn.Accounts.User

    timestamps(updated_at: false)
  end

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, [:secret, :activated_at, :deactivated_at, :user_id])
    |> generate_seceret_if_blank()
  end

  def create(params) do
    changeset(%__MODULE__{}, params)
    |> Repo.insert()
  end

  def get_user_by_secret(secret) do
    case from(c in __MODULE__,
           join: user in assoc(c, :user),
           preload: :user,
           where: c.secret == ^secret
         )
         |> Repo.one() do
      nil ->
        {:error, :not_found}

      %__MODULE__{
        user: user
      } ->
        user
    end
  end

  defp generate_seceret_if_blank(changeset) do
    if get_field(changeset, :secret) do
      changeset
    else
      secret = :crypto.strong_rand_bytes(32) |> Base.encode64()
      put_change(changeset, :secret, secret)
    end
  end
end
