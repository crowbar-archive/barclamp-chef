
#####
# allow us to replace the authenticator that the chef API uses


class Chef::REST

  def self.replace_authenticator(client_name,raw_key)
    @@replacement_auth_credentials = ReplacementAuth.new(client_name,raw_key)
  end

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

  @@replacement_auth_credentials = nil

  alias :orig_initialize :initialize
  def initialize(url, client_name=Chef::Config[:node_name], signing_key_filename=nil, options={})
    # ignore signning key    
    unless  @@replacement_auth_credentials.nil?
      orig_initialize(url,client_name,nil)
      @auth_credentials=@@replacement_auth_credentials 
    else ## handle the case were chef is accessed before we get to it.
      orig_initialize(url,client_name,signing_key_filename,options)
    end
  end

end
