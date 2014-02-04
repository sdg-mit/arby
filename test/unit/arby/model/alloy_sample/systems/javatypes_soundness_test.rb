require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

require 'arby_models/alloy_sample/systems/javatypes_soundness'

class JavatypesSoundnessTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  JavatypesSoundness = ArbyModels::AlloySample::Systems::JavatypesSoundness
  include JavatypesSoundness

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(JavatypesSoundness)
  end

  def test_als
    # puts JavatypesSoundness.meta.to_als
    assert JavatypesSoundness.compile
  end

  def test_check_type_soundness
    sol = JavatypesSoundness.exe_cmd 0
    assert !sol.satisfiable?
  end

  def test_check_type_soundness_2
    sol = JavatypesSoundness.exe_cmd 1
    assert !sol.satisfiable?
  end

end
