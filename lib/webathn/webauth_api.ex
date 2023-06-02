defmodule Webathn.WebauthApi do
  defp config() do
    Application.fetch_env!(:webathn, __MODULE__)
  end

  def relay_name do
    Keyword.fetch!(config(), :relay_name)
  end

  @doc """
  An RP ID is a domain and a website can specify either its domain or a registrable suffix.

  For example, if an RP's origin is https://login.example.com:4000,
  the RP ID can be either login.example.com or example.com.
  If the RP ID is specified as example.com,
  the user can authenticate on login.example.com or on any subdomains on example.com
  """
  def relay_id do
    Keyword.fetch!(config(), :relay_id)
  end

  def generate_random(length \\ 8) do
    :crypto.strong_rand_bytes(length)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Allowed_creds params allows you to specifiy a specific credential


  ## Examples

    iex> generate_authentication_options([%{
          "id" => "some_db_saved_credential_id",
          "type" => "public-key"
        }])

    View Documentation https://w3c.github.io/webauthn/#dom-publickeycredentialrequestoptions-allowcredentials
  """
  def generate_authentication_options(allowed_creds \\ []) do
    %{
      "rpId" => relay_id(),
      "challenge" => generate_random(12),
      "allowCredentials" => allowed_creds
    }
  end

  @doc """

  ## The User map
    Expects a name and a displayName

    A display name is purely for display purposes and should be memorable

    https://w3c.github.io/webauthn/#dictionary-user-credential-params


  ## authenticatorType
    Expects either cross-platform or platform

    https://w3c.github.io/webauthn/#enum-attachment
  """
  def generate_registration_options(
        %{
          "name" => name,
          "displayName" => displayName
        },
        authenticatorType \\ "cross-platform",
        timeout \\ 60000
      ) do
    %{
      "challenge" => generate_random(12),
      "rp" => %{
        "name" => relay_name(),
        "id" => relay_id()
      },
      "user" => %{
        "id" => generate_random(),
        "name" => name,
        "displayName" => displayName
      },
      "pubKeyCredParams" => [
        %{"alg" => -7, "type" => "public-key"},
        %{"alg" => -257, "type" => "public-key"}
      ],
      "authenticatorSelection" => %{
        "authenticatorAttachment" => authenticatorType,
        "requireResidentKey" => true
      },
      "timeout" => timeout
    }
  end

  def process_authentication_response(registration_challenge, client_json) do
    with {:ok, client_json} <- Jason.decode(client_json),
         challenge_used_to_initiate_registration <-
           Map.get(registration_challenge, "challenge"),
         challenge_from_client_response <-
           Map.get(client_json, "challenge"),
         {:ok, decoded_challenge_from_client} <-
           Base.url_decode64(challenge_from_client_response, padding: false),
         true <-
           decoded_challenge_from_client ==
             challenge_used_to_initiate_registration do
      :ok
    else
      _ ->
        {:error, "jkkjnj"}
    end
  end

  def process_registration_response(registration_challenge, attestationObject, client_json) do
    with {:ok, client_json} <- Jason.decode(client_json),
         challenge_used_to_initiate_registration <-
           Map.get(registration_challenge, "challenge"),
         challenge_from_client_response <-
           Map.get(client_json, "challenge"),
         {:ok, decoded_challenge_from_client} <-
           Base.url_decode64(challenge_from_client_response, padding: false),
         true <-
           decoded_challenge_from_client ==
             challenge_used_to_initiate_registration,
         {:ok, result_cbor_map, ""} <-
           :binary.list_to_bin(attestationObject) |> CBOR.decode(),
         {:ok,
          %Webauthn.AuthenticatorData{
            acd_included: acd_included,
            attested_credential_data: %{
              aaguid: aaguid,
              credential_id: credential_id,
              credential_public_key:
                %{
                  -3 => %CBOR.Tag{
                    tag: :bytes,
                    value: credential_public_key_y_coordinate
                  },
                  -2 => %CBOR.Tag{
                    tag: :bytes,
                    value: credential_public_key_x_coordinate
                  },
                  -1 => credential_public_key_curve_type,
                  1 => credential_public_key_type,
                  3 => credential_public_key_type_algorithm
                } = credential_public_key
            },
            extension_included: extension_included,
            extensions: extensions,
            raw_data: raw_data,
            rp_id_hash: rp_id_hash,
            sign_count: sign_count,
            user_present: user_present,
            user_verified: user_verified
          } = authData} <-
           Webauthn.AuthenticatorData.parse(result_cbor_map) do
      {:ok, authData}
    else
      error ->
        {:error, error}
    end
  end
end
