require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/toys/javatypes'

class JavatypesTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  Javatypes = ArbyModels::AlloySample::Toys::Javatypes
  include Javatypes

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(Javatypes)
  end

  def test_als
    # puts Javatypes.meta.to_als
    assert Javatypes.compile
  end

  def test_run_show
    sol = Javatypes.run_show
    assert sol.satisfiable?
  end
end
