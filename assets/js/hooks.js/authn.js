const authn = {
    mounted() {
        console.log("mounted");


        const context = this;


        context.handleEvent("public_key_get", async ({ challenge }) => {
            
            var publicKeyCredentialRequestOptions = JSON.parse(challenge);
            publicKeyCredentialRequestOptions.challenge = Uint8Array.from(
                publicKeyCredentialRequestOptions.challenge, c => c.charCodeAt(0));

            
                //         publicKeyCredentialRequestOptions.allowCredentials[0].id = Uint8Array.from(
                // publicKeyCredentialRequestOptions.allowCredentials[0].id, c => c.charCodeAt(0));
            
            
            const credential = await navigator.credentials.get({
                publicKey: publicKeyCredentialRequestOptions,
                // signal: abortController.signal,
                // Specify 'conditional' to activate conditional UI  
                // mediation: 'conditional'
            });

            context.pushEvent("client_response", {
                response: {
                    credential: JSON.stringify(credential),
                    id: credential.id,
                    attestationObject: Array.from(new Uint8Array(credential.response.attestationObject)),
                    clientDataJSON: Array.from(new Uint8Array(credential.response.clientDataJSON)),

                }
            });

            console.log(credential);
        });

        context.handleEvent("public_key_gen", async ({ challenge }) => {
            var publicKeyCredentialRequestOptions = JSON.parse(challenge);
            publicKeyCredentialRequestOptions.challenge = Uint8Array.from(
                publicKeyCredentialRequestOptions.challenge, c => c.charCodeAt(0));

            publicKeyCredentialRequestOptions.user.id =
                Uint8Array.from(
                    publicKeyCredentialRequestOptions.user.id, c => c.charCodeAt(0));

            try {
                const credential = await navigator.credentials.create({
                    publicKey: publicKeyCredentialRequestOptions
                });

                context.pushEvent("client_response", {
                    response: {
                        credential: JSON.stringify(credential),
                        id: credential.id,
                        attestationObject: Array.from(new Uint8Array(credential.response.attestationObject)),
                        clientDataJSON: Array.from(new Uint8Array(credential.response.clientDataJSON)),

                    }
                });

            } catch (error) {

            }
        });

        const sign_button = document.getElementById("sign-button");
        
        

        if (sign_button) {

            sign_button.addEventListener("click", async (e) => {



                try {

                    // To abort a WebAuthn call, instantiate an `AbortController`.  
                    const abortController = new AbortController();

                    const publicKeyCredentialRequestOptions = {
                        // Server generated challenge  
                        challenge: Uint8Array.from(
                            "UZSL85T9AFC", c => c.charCodeAt(0)),
                        // The same RP ID as used during registration  
                        rpId: 'localhost',
                    };

                    const credential = await navigator.credentials.get({
                        publicKey: publicKeyCredentialRequestOptions,
                        // signal: abortController.signal,
                        // Specify 'conditional' to activate conditional UI  
                        // mediation: 'conditional'
                    });
                    console.log(credential);


                } catch (error) {
                    console.log(error)
                }

            });
        } else {
            console.log("Hahah")
        }

    },
}

export default authn;