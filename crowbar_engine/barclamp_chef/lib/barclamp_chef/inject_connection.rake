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
require 'json'

namespace :crowbar do
  namespace :chef do 

    def print_args(args)
      args.each { |k,v|  puts "#{k}: #{v}"}
    end

    desc "install a chef server info record"
    task :inject_conn, [:url, :name, :key_file, :description ] => :environment do |t, args| 
      #print_args(args)
      print_args(ENV)
      file = ENV['key_file'] || "/home/crowbar/.chef/crowbar.pem"
      raise "you must supply valid file! Cannot find: #{file}" unless File.exist? file
      key = IO.read(File.expand_path(file))
      # find or create the jig that we are going to use
      j = BarclampChef::Jig.find_or_create_by_name :name =>'admin_chef', :order => 100, :description => (ENV['description'] || 'installed by rake crowbar:chef:inject_conn')
      j.server = ENV['url'] || "http://127.0.0.1:4000"
      j.client_name =ENV['name']  || "crowbar"
      j.key = key
      j.save!
      puts "installed chef #{j.name} server at #{j.server}"
    end

    desc "list current servers from the DB"
    task :list_conn => :environment do 
      BarclampChef::Jig.all.each { |jc| 
        puts "name: #{jc.name}, url: #{jc.server}, client: #{jc.client_name}"
      }
    end

    desc "remove all current servers from the DB"
    task :clear_conn => :environment do 
      x = BarclampChef::Jig.delete_all
      puts "deleted #{x} records"
    end

    desc "find the running chef server info (local machine), and extract the requested path"
    task :running_chef_info, [:file, :path ] do
      f = ENV['file'] || '/etc/chef-server/chef-server-running.json'
      p = ENV['path'] || 'chef_server.nginx'  # seems a reasonable default...
      f =File.read(f)
      j = JSON.parse(f)
      p.split('.').each { |k| 
        j = j[k]
      }
      j = JSON.pretty_generate(j) if j.kind_of?(Hash)
      puts j
    end

  end
end





