defmodule WebathnWeb.UserRegistrationLive do
  use WebathnWeb, :live_view

  alias Webathn.Accounts
  alias Webathn.Accounts.User
  alias Webathn.WebauthApi

  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-sm" phx-hook="authn" id="authn-registration">
      <.header class="text-center">
        Register for an account
        <:subtitle>
          Already registered?
          <.link navigate={~p"/users/log_in"} class="font-semibold text-brand hover:underline">
            Sign in
          </.link>
          to your account now.
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="registration_form"
        phx-submit="save"
        phx-change="validate"
        phx-trigger-action={@trigger_submit}
        action={~p"/users/log_in?_action=registered"}
        method="post"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <.input field={@form[:username]} type="text" label="Username" required />
        <.input field={@form[:email]} type="email" label="Email" required />

        <.button
          type="button"
          disabled={!@changeset.valid?}
          phx-click="creds"
          id="signup-butto"
          class="w-full"
        >
          Create an account
        </.button>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    changeset = registration_changeset(%{})

    socket =
      socket
      |> assign(trigger_submit: false, check_errors: false, changeset: changeset)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  def handle_event("creds", _params, socket) do
    socket =
      with {:ok, changeset_data} <-
             socket.assigns.changeset
             |> Ecto.Changeset.apply_action(:validate),
           challenge <-
             WebauthApi.generate_registration_options(%{
               "name" => changeset_data.email,
               "displayName" => changeset_data.username
             }),
           {:ok, challenge_json} <- Jason.encode(challenge) do
        socket
        |> assign(challenge: challenge)
        |> push_event("public_key_gen", %{challenge: challenge_json})
      else
        {:error, changeset} ->
          socket
          |> assign(changeset: changeset)

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("client_response", params, socket) do
    attestationObject = params["response"]["attestationObject"]

    clientDataJSON = params["response"]["clientDataJSON"]

    with {:ok, auth_data} <-
           WebauthApi.process_registration_response(
             socket.assigns.challenge,
             attestationObject,
             clientDataJSON
           ),
         true <- socket.assigns.changeset.valid?,
         {:ok, %User{} = user} <-
           socket.assigns.changeset
           |> Ecto.Changeset.apply_changes()
           |> Map.merge(%{
             credential_id: params["response"]["id"],
             public_key:
               auth_data.attested_credential_data.credential_public_key
               |> CBOR.encode()
           })
           |> User.webauthn_create() do
      {:noreply,
       socket
       |> put_flash(:success, "Credentials saved successfully")
       |> push_redirect(to: ~p(/users/log_in))}
    else
      error ->
        {:noreply,
         socket |> put_flash(:error, "Something went wrong while saving your credential")}
    end
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Accounts.deliver_user_confirmation_instructions(
            user,
            &url(~p"/users/confirm/#{&1}")
          )

        changeset = Accounts.change_user_registration(user)
        {:noreply, socket |> assign(trigger_submit: true) |> assign_form(changeset)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign(check_errors: true) |> assign_form(changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = registration_changeset(user_params)

    {:noreply,
     socket |> assign(changeset: changeset) |> assign_form(Map.put(changeset, :action, :validate))}
  end

  defp registration_changeset(params) do
    {%{email: nil, username: nil}, %{email: :string, username: :string}}
    |> Ecto.Changeset.cast(params, [:username, :email])
    |> Ecto.Changeset.validate_required([:username, :email])
    |> Ecto.Changeset.validate_format(
      :email,
      ~r/^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$/,
      message: "must have the @ sign and no spaces"
    )
    |> Ecto.Changeset.validate_length(:email, max: 160)
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
