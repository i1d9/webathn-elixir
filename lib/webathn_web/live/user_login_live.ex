defmodule WebathnWeb.UserLoginLive do
  use WebathnWeb, :live_view

  alias Webathn.WebauthApi
  alias Webathn.Accounts
  alias Webathn.Accounts.User
  alias Webathn.Accounts.AuthSession

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm" phx-hook="authn" id="auth-login">
      <.header class="text-center">
        Sign in to account
        <:subtitle>
          Don't have an account?
          <.link navigate={~p"/users/register"} class="font-semibold text-brand hover:underline">
            Sign up
          </.link>
          for an account now.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="login_form"
        phx-submit="save"
        phx-change="credentials"
        phx-trigger-action={@trigger_submit}
        action={~p"/users/log_in"}
        method="post"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input
          field={@form[:identifier]}
          type="text"
          label="Email or Username"
          required
          autocomplete="username email webauthn"
        />

        <.input field={@form[:secret]} type="hidden" />

        <.button
          phx-click="creds"
          disabled={!@changeset.valid?}
          type="button"
          id="signbutton"
          class="w-full"
        >
          Login
        </.button>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = login_changeset(%{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false, changeset: changeset)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("creds", _params, socket) do
    changeset = socket.assigns.changeset

    socket =
      with {:ok, data} <- changeset |> Ecto.Changeset.apply_action(:validate),
           {:ok, %User{} = user} <- Accounts.find_by_username_or_email(data),
           challenge <-
             WebauthApi.generate_authentication_options(),
           {:ok, challenge_json} <- Jason.encode(challenge) do
        socket
        |> assign(challenge: challenge, user: user, form_data: data)
        |> push_event("public_key_get", %{challenge: challenge_json})
      else
        {:error, :multiple_users} ->
          changeset = changeset |> Ecto.Changeset.add_error(:identifier, "Invalid")

          socket
          |> assign(changeset: changeset)

        {:error, %Ecto.Changeset{} = changeset} ->
          socket
          |> assign(changeset: changeset)

        _ ->
          socket
          |> put_flash(:error, "Invalid")
      end

    {:noreply, socket}
  end

  def handle_event("client_response", params, socket) do
    clientDataJSON = params["response"]["clientDataJSON"]
    credentialID = params["response"]["id"]

    user = socket.assigns.user

    socket =
      with :ok <-
             WebauthApi.process_authentication_response(socket.assigns.challenge, clientDataJSON),
           true <- user.credential_id == credentialID,
           {:ok, %AuthSession{} = auth_session} <-
             AuthSession.create(%{user_id: user.id, activated_at: NaiveDateTime.utc_now()}),
           %Phoenix.HTML.Form{} = form <-
             create_login_params(Map.put(socket.assigns.form_data, :secret, auth_session.secret)) do
        socket
        |> assign(form: form, trigger_submit: true)
      else
        _ ->
          socket
          |> put_flash(:error, "We could not log you in")
      end

    {:noreply, socket}
  end

  def handle_event("credentials", %{"identifier" => identifier}, socket) do
    changeset = login_changeset(identifier)

    {:noreply,
     socket
     |> assign(changeset: changeset)
     |> assign_form(Map.put(changeset, :action, :validate))
     |> then(&if changeset.valid?, do: &1 |> push_event("valid", %{}), else: &1)}
  end

  defp login_changeset(params) do
    {%{identifier: nil, secret: nil}, %{identifier: :string, secret: nil}}
    |> Ecto.Changeset.cast(params, [:identifier])
    |> Ecto.Changeset.validate_required([:identifier])
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "identifier")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  defp create_login_params(identifier) do
    login_changeset(identifier)
    |> case do
      %Ecto.Changeset{
        valid?: true
      } = changeset ->
        to_form(changeset, as: "user")

      _ ->
        :error
    end
  end
end
