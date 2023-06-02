defmodule Webathn.Otp do
  alias Webathn.Accounts.User

  def generate_qr(%User{
        email: email,
        authenticator_secret: authenticator_secret
      }) do
    NimbleTOTP.otpauth_uri("Acme:#{email}", authenticator_secret, issuer: "Acme")
  end

  def validate?(
        %User{
          authenticator_secret: authenticator_secret
        },
        otp
      ),
      do: NimbleTOTP.valid?(authenticator_secret, otp)
end
