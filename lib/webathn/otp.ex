defmodule Webathn.Otp do
  alias Webathn.Accounts.User

  defp config() do
    Application.fetch_env!(:webathn, __MODULE__)
  end

  def issuer do
    Keyword.fetch!(config(), :issuer)
  end

  def uri(%User{
        email: email,
        authenticator_secret: authenticator_secret
      }) do
    NimbleTOTP.otpauth_uri("#{issuer()}:#{email}", authenticator_secret, issuer: issuer())
  end

  def generate_qr(%User{} = user) do
    uri(user)
    |> QRCodeEx.encode()
    |> QRCodeEx.svg()
  end

  def validate?(
        %User{
          authenticator_secret: authenticator_secret
        },
        otp
      ),
      do: NimbleTOTP.valid?(authenticator_secret, otp)
end
