require "fileutils"
require "barclamp_chef/engine"

module BarclampChef

  def self.knife(args)
    pid = fork
    unless pid
      # Get rid of all bundle-related env vars
      [
       "RAILS_ENV",
       "RUBYOPT",
       "GEM_HOME",
       "GEM_PATH",
       "BUNDLE_BIN_PATH",
       "BUNDLE_GEMFILE"
      ].each {|k|ENV.delete(k)}
      # Sigh, knife needs EDITOR
      ENV["EDITOR"] ||= "true"
      # Clean up PATH as well
      ENV["PATH"] = ENV["PATH"].split(":").reject{|part| part =~ /crowbar_framework/}.join(":")
      exit!(system("knife #{args}"))
    end
    Process.waitpid2(pid)[1].exitstatus == 0
  end
end
