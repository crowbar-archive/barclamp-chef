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

  class Jig < Jig
  
    has_one :jig_chef_conn_info, :dependent => :destroy
  
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


    
  end # class
end # module