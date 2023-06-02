defmodule WebathnWeb.UserSettingsLive do
  use WebathnWeb, :live_view

  alias Webathn.Accounts
  alias Webathn.Accounts.User
  alias Webathn.Otp

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>Manage your account email address and password settings</:subtitle>
    </.header>

    <div class="space-y-12 divide-y">
      <div>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input field={@email_form[:email]} type="email" label="Email" required />

          <:actions>
            <.button id="email-update-button" phx-disable-with="Changing...">Change Email</.button>
          </:actions>
        </.simple_form>
      </div>
      <div :if={!@current_user.authenticator_otp}>
        <.button id="setup-otp" phx-click="setup" type="button">Setup OTP</.button>

        <div :if={@otp_qr}>
          <%= raw(@otp_qr_data) %>
          <.simple_form phx-submit="confirm-otp" for={@confirm_otp_form}>
            <.input field={@confirm_otp_form[:otp]} type="text" label="OTP" required />

            <.button id="confirm-otp-button">Confirm</.button>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)

    socket =
      socket
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:otp_qr, false)
      |> assign(:confirm_otp_form, nil)
      |> assign(:otp_qr_data, nil)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  def handle_event("confirm-otp", %{"otp" => otp}, socket) do
    socket =
      with %Ecto.Changeset{
             valid?: true
           } = changeset <- confirm_otp_changeset(otp),
           {:ok, data} <- Ecto.Changeset.apply_action(changeset, :validate),
           true <- Otp.validate?(socket.assigns.current_user, data.otp),
           {:ok, %Accounts.User{}} = user <-
             User.update(socket.assigns.current_user, %{authenticator_otp: true}) do
        socket
        |> put_flash(:success, "Successfully registered")
      else
        false ->
          socket |> put_flash(:error, "Invalid OTP")

        {:error, %Ecto.Changeset{} = changeset} ->
          socket

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("setup", _, socket) do
    otp_qr_data = Otp.generate_qr(socket.assigns.current_user)
    confirm_otp_changeset = confirm_otp_changeset(%{})

    {:noreply,
     assign(socket,
       otp_qr_data: otp_qr_data,
       otp_qr: true,
       confirm_otp_form: confirm_otp_changeset |> to_form(as: :otp)
     )}
  end

  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  defp confirm_otp_changeset(params) do
    {%{otp: nil}, %{otp: :string}}
    |> Ecto.Changeset.cast(params, [:otp])
    |> Ecto.Changeset.validate_required([:otp])
  end
end
