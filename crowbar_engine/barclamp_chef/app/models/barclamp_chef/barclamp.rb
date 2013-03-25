# Copyright 2013, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#


module BarclampChef  
  class Barclamp < Barclamp
=begin
    Expected to be called as part of commiting a proposal.
    Chef constructs are created in AR.  
=end
  
    def commit_proposal(proposal)
      raise "this is old approach - not implemented!"
      config = proposal.current_config.config_hash["chef"]
      @logger.info "config is: #{config.inspect}"
      JigChef.transaction {      
        config["servers"].each { | srv_name, srv |  
          c = JigChef.find_by_name(srv_name)
          if c.nil? 
            JigChef.create  :name=>srv_name, 
                            :type=>JigChef.name,
                            :description => srv["description"], 
                            :order => srv["order"], 
                            :connecton => srv["server_url"], 
                            :client_name => srv["client_name"],
                            :key => srv["client_key"]
              
            @logger.info "saving #{c.inspect}"
          end
        }    
      }
    end
  end
end

