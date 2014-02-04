require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/puzzles/handshake'

class FarmerTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  Handshake = ArbyModels::AlloySample::Puzzles::Handshake
  include Handshake

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(Handshake)
  end

  def test_als
    # puts Handshake.meta.to_als
    assert Handshake.compile
  end

  def test_run_p10
    sol = Handshake.exe_cmd :p10
    assert sol.satisfiable?
  end

end
