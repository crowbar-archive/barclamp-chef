#!/usr/bin/env ruby
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
namespace :crowbar do
  namespace :chef do 

    desc "install a chef connection info record"
    task :inject_conn, [:url, :name, :key_file ] => :environment do |t, args|    
      key = IO.read(File.expand_path(args[:key_file]))
      c = BarclampChef::JigChefConnInfo.create(
        :url=>args[:url],:client_name=>args[:name],:key=>key)
      c.save!
    end

    desc "list current connections from the DB"
    task :list_conn => :environment do 
      BarclampChef::JigChefConnInfo.all.each { |jc| 
        puts "url: #{jc.url}, client: #{jc.client_name}"
      }
    end

    desc "remove all current connections from the DB"
    task :clear_conn => :environment do 
      x = BarclampChef::JigChefConnInfo.delete_all
      puts "deleted #{x} records"
    end
  end
end





