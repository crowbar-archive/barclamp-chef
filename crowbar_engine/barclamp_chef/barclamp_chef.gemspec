$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "barclamp_chef/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "barclamp_chef"
  s.version     = BarclampChef::VERSION
  s.authors     = ["Dell Crowbar Team"]
  s.email       = ["crowbar@dell.com"]
  s.homepage    = ""
  s.summary     = " Summary of BarclampChef."
  s.description = " Description of BarclampChef."

  s.files = Dir["{app,config,db,lib}/**/*"] + ["Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 3.2.11"
  # s.add_dependency "jquery-rails"

  s.add_development_dependency "sqlite3"
end
