require 'spec_helper'

describe "crowbar:chef" do 
  include_context "rake"

  describee "clear_conn" do
    its(:prerequisites) { should include("environment") }
  end
end