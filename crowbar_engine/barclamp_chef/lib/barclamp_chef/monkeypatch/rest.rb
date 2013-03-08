# Copyright 2013, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: aabes

# allow us to replace the authenticator that the chef API uses
# with information from the db
module ReplacementAuthMod
  @@client_name = nil
  @@raw_key = nil
  @@url = nil

  def self.replace_authenticator(url, client_name,raw_key)
    @@client_name = client_name
    @@raw_key = raw_key
    @@url = url
  end

  class Chef::REST
    class << self 
      alias_method :orig_new, :new
      def new(url, client_name=Chef::Config[:node_name], signing_key_filename=nil, options={})
        if @@client_name
          url, client_name, options[:raw_key]=@@url, @@client_name, @@raw_key
          signing_key_filename=nil
        end
        r = Chef::REST.orig_new(url,client_name,signing_key_filename,options)
      end
    end
  end
end

Chef::REST.__send__(:include, ReplacementAuthMod)


  
