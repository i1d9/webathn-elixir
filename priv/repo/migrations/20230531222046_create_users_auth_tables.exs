defmodule Webathn.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      add :username, :string, null: false
      add :email, :citext, null: false
      add :public_key, :binary, null: false
      add :authenticator_otp, :boolean, default: false
      add :authenticator_secret, :binary
      add :credential_id, :string, null: false
      add :confirmed_at, :naive_datetime
      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:authenticator_secret])
    create unique_index(:users, [:username])
    create unique_index(:users, [:username, :credential_id])
    create unique_index(:users, [:username, :public_key])
    create unique_index(:users, [:username, :public_key, :credential_id])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
