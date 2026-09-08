# frozen_string_literal: true

module Agent
  class Jwt
    class << self
      def encode(payload)
        header = b64({ "alg" => "RS256", "typ" => "JWT", "kid" => kid })
        body = b64(payload)
        data = "#{header}.#{body}"
        signature = Base64.urlsafe_encode64(private_key.sign("SHA256", data), padding: false)
        "#{data}.#{signature}"
      end

      def jwks
        key = private_key.public_key
        {
          "keys" => [
            {
              "kty" => "RSA",
              "use" => "sig",
              "kid" => kid,
              "alg" => "RS256",
              "n" => Base64.urlsafe_encode64(key.n.to_s(2), padding: false),
              "e" => Base64.urlsafe_encode64(key.e.to_s(2), padding: false)
            }
          ]
        }
      end

      def kid
        @kid ||= Digest::SHA256.hexdigest(private_key.public_key.to_der)[0, 16]
      end

      def private_key
        @private_key ||= if ENV["AGENT_OAUTH_RSA_PEM"].present?
          OpenSSL::PKey::RSA.new(ENV["AGENT_OAUTH_RSA_PEM"])
        else
          OpenSSL::PKey::RSA.new(Rails.env.test? ? 512 : 2048)
        end
      end

      private

      def b64(object)
        Base64.urlsafe_encode64(JSON.generate(object), padding: false)
      end
    end
  end
end
