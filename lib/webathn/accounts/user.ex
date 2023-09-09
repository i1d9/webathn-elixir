defmodule Webathn.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  alias Webathn.Repo

  schema "users" do
    field :username, :string
    field :email, :string
    field :public_key, :binary
    field :authenticator_otp, :boolean, default: false
    field :authenticator_secret, :string
    field :credential_id, :string
    field :confirmed_at, :naive_datetime

    timestamps()
  end

  def changeset(struct, params) do

    struct
    |> cast(params, [:username, :email, :public_key, :authenticator_otp, :authenticator_secret, :credential_id])

  end

  def basic_info_changeset(attrs, opts \\ []) do
    %__MODULE__{}
    |> cast(attrs, [:email, :username])
    |> validate_required([:email, :username])
    |> validate_email()
    |> maybe_validate_unique_fields(opts)
  end

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :username, :public_key, :authenticator_secret, :credential_id])
    |> validate_required([:username, :public_key, :credential_id])
    |> validate_email()
    |> maybe_validate_unique_fields(opts)
    |> generate_authenticator_secret_if_blank()
  end

  def webauthn_create(params) do
    registration_changeset(%__MODULE__{}, params)
    |> Repo.insert()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
  end

  defp maybe_validate_unique_fields(changeset, opts) do
    if Keyword.get(opts, :validate_unique_fields, true) do
      changeset
      |> unsafe_validate_unique(:email, Webathn.Repo)
      |> unique_constraint(:email)
      |> unsafe_validate_unique(:authenticator_secret, Webathn.Repo)
      |> unique_constraint(:authenticator_secret)
      |> unsafe_validate_unique(:credential_id, Webathn.Repo)
      |> unique_constraint(:credential_id)
      |> unsafe_validate_unique(:public_key, Webathn.Repo)
      |> unique_constraint(:public_key)
    else
      changeset
    end
  end

  defp generate_authenticator_secret_if_blank(changeset) do
    if get_field(changeset, :authenticator_secret) do
      changeset
    else
      secret = :crypto.strong_rand_bytes(32)
      put_change(changeset, :authenticator_secret, secret)
    end
  end

  @doc """
  A user changeset for changing the email.

  It requires the email to change otherwise an error is added.
  """
  def email_changeset(user, attrs) do
    user
    |> cast(attrs, [:email])
    |> validate_email()
    |> case do
      %{changes: %{email: _}} = changeset -> changeset
      %{} = changeset -> add_error(changeset, :email, "did not change")
    end
  end

  @doc """
  Confirms the account by setting `confirmed_at`.
  """
  def confirm_changeset(user) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    change(user, confirmed_at: now)
  end

  def update(user, params) do
    changeset(user, params)
    |> Repo.update()
  end
end
