require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/toys/grandpa'

class GrandpaTest < Test::Unit::TestCase
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  Grandpa = ArbyModels::AlloySample::Toys::Grandpa
  include Grandpa


  def setup_class
    Arby.reset
    Arby.meta.restrict_to(Grandpa)
  end

  def test_als
    # puts Grandpa.to_als
    assert Grandpa.compile
  end

  def test_instance
    sol = Grandpa.run_ownGrandpa
    assert sol.satisfiable?
    inst = sol.arby_instance
    m = inst["$ownGrandpa_m"]
    assert m, "own grandpa skolem not found"
    assert m.in? parents(parents(m))
  end

end
