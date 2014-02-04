require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/toys/trivial'

class TrivialTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  Trivial = ArbyModels::AlloySample::Toys::Trivial
  include Trivial

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(Trivial)
  end

  def test_als
    # puts Trivial.meta.to_als
    assert Trivial.compile
  end

  def test_run
    sol = Trivial.exe_cmd 0
    assert !sol.satisfiable?
  end
end
