# Copyright 2011, Dell 
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
#

# Cmdb_service is a service facade that provides the API to the CMDB layer. It serves as 
# a template class, which delegates appropriate operations to specialized subclasses for 
# the different CMDB (e.g. chef, puppet)


class ChefService < ServiceObject

  def commit_proposal(proposal)
    config = proposal.current_config.config_hash["chef"]
    @logger.info "config is: #{config.inspect}"
    CmdbChef.transaction {      
      config["servers"].each { | srv_name, srv |  
        c = CmdbChef.find_by_name(srv_name)
        if c.nil? 
          CmdbChef.create( :name=>srv_name, :type=>CmdbChef.name,
            :description => srv["description"], :order => srv["order"])        
        end
        cc = c.cmdb_chef_conn_info 
        if cc.nil?
          cc = CmdbChefConnInfo.create
          cc.cmdb = c
        end

        #set or update connection info
        cc.url = srv["url"]
        cc.client_name=srv["client_name"]
        cc.key = srv["client_key"]
        @logger.info "saving #{c.inspect}"
        cc.save!
        c.save!
      }    
    }
  end
end
