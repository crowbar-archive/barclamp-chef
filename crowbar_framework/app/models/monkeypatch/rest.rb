
#####
# allow us to replace the authenticator that the chef API uses


module ReplacementAuthMod
  @@replacement_auth_credentials = nil

  def self.replace_authenticator(client_name,raw_key)
    @@replacement_auth_credentials = ReplacementAuth.new(client_name,raw_key)
  end

  #####
  # a replacement to the AuthCredentials chef class, which is
  # provided with the signing key.
  class ReplacementAuth < Chef::REST::AuthCredentials
    def initialize(client_name=nil, raw_key=nil)
      @client_name = client_name
      @key = OpenSSL::PKey::RSA.new(raw_key)
    end

    def sign_requests?
      true
    end
  end
  
  def self.new(url, client_name=Chef::Config[:node_name], signing_key_filename=nil, options={})
    r = Chef::REST.new(url,client_name,signing_key_filename,options)
    ## handle the case were chef is accessed before we get to it.
    unless @@replacement_auth_credentials.nil?
      r.auth_credentials=@@replacement_auth_credentials             
    end
  end


#  def self.included(base)
#    base.__send__(:alias_method, :orig_initialize, :initialize)
#    base.__send__(:alias_method, :initialize, :initialize_replacement )
#  end
end

Chef::REST.__send__(:include, ReplacementAuthMod)


  
