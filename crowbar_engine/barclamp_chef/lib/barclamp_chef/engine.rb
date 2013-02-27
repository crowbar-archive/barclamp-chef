require 'rails'

module BarclampChef
  class Engine < ::Rails::Engine
    isolate_namespace BarclampChef

    rake_tasks do
      load 'barclamp_chef/inject_connection.rake'
    end
  end
end

