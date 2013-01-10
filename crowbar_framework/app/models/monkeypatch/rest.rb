
#####
# allow us to replace the authenticator that the chef API uses

class Chef::REST
  #####
  # a replacement to the AuthCredentials chef class, which is
  # provided with the signing key.
  class ReplacementAuth < AuthCredentials
    def initialize(client_name=nil, raw_key=nil)
      @client_name = client_name
      @key = OpenSSL::PKey::RSA.new(raw_key)
    end

    def sign_requests?
      true
    end

  end

  def replace_authenticator(auth)
    @@replacement_auth_credentials = auth
  end

  alias :orig_initialize :initialize
  def initialize(url, client_name=Chef::Config[:node_name], signing_key_filename=nil, options={},raw_key = nil)
    orig_initialize
    replace_authenticator(ReplacementAuth.new(client_name,raw_key))
  end

end
