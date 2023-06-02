defmodule Webathn.Repo.Migrations.AddTableAuthSessions do
  use Ecto.Migration

  def change do
    create table(:auth_sessions) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :secret, :string, null: false
      add :activated_at, :naive_datetime
      add :deactivated_at, :naive_datetime

      timestamps(updated_at: false)
    end

    create unique_index(:auth_sessions, [:secret])
  end
end
