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


require File.join(File.dirname(__FILE__),"monkeypatch","rest")

module BarclampChef 

  class Jig < Jig
  
    has_one :jig_chef_conn_info, :dependent => :destroy
=begin
    Prepare the chef objects for use, by injecting the appropriate authentication 
    info from the DB.
=end
    def prepare_chef_api
      conn_info = self.jig_chef_conn_info
      logger.info("No Chef connection info") and return unless conn_info
      Chef::Config.node_name = conn_info.client_name
      Chef::Config.chef_server_url = conn_info.url
      ReplacementAuthMod.replace_authenticator(conn_info.client_name, conn_info.key)
    end
=begin
    Expected to be called as part of commiting a proposal.
    Chef constructs are created in AR.  
=end
  
    def commit_proposal(proposal)
      config = proposal.current_config.config_hash["chef"]
      @logger.info "config is: #{config.inspect}"
      JigChef.transaction {      
        config["servers"].each { | srv_name, srv |  
          c = JigChef.find_by_name(srv_name)
          if c.nil? 
            JigChef.create( :name=>srv_name, :type=>JigChef.name,
              :description => srv["description"], :order => srv["order"])        
          end
          cc = c.jig_chef_conn_info 
          if cc.nil?
            cc = JigChefConnInfo.create
            cc.jig_chef = c
          end
  
          #set or update connection info
          cc.url = srv["server_url"]
          cc.client_name=srv["client_name"]
          cc.key = srv["client_key"]
          @logger.info "saving #{c.inspect}"
          cc.save!
          c.save!
        }    
      }
    end
  
    def create_event(config)
      evt = JigEvent.create(:type=>"JigEvent", :proposal_confing =>config, 
        :jig => self, :status => JigEvent::EVT_PENDING, :name=>"apply_#{config.id}")
      evt
    end
  
    def create_run_for(evt, nr,order)
      run = JigRunChef.create(:type=> "JigRunChef", :jig_event => evt, 
        :node_role => nr, :order=>order, :status => JigRun::RUN_PENDING, 
        :name=>"run_#{evt.id}_#{nr.id}_#{order}")
      run
    end

private

    def node(name)
     begin 
       chef_init
       super.node name
       return Chef::Node.load(name)
     rescue Exception => e
       Rails.logger.warn("Could not recover Node on load #{name}: #{e.inspect}")
       return nil
     end
    end
    def data(bag_item)
     begin 
       chef_init
       super.data bag_item
       return Chef::DataBag.load "crowbar/#{bag_item}"
     rescue Exception => e
       Rails.logger.warn("Could not recover Chef Crowbar Data on load #{bag_item}: #{e.inspect}")
       return nil
     end
    end

    def chef_escape(str)
     str.gsub("-:") { |c| '\\' + c }
    end

    def query_chef
     begin
       chef_init
       return Chef::Search::Query.new
     rescue
       return Chef::Node.new
     end
    end
    
  end # class
end # module