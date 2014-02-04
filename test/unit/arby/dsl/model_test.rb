require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'

include Arby::Dsl

module X
  alloy_model "Y" do
    sig D
  end
end

class TestAlloyUserModel < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::Assertions

  def test1() create_module "MyModel1" end
  def test2() create_module :MyModel2 end

  def test_create_in_a_module
    assert_module_helper X::Y, "X::Y"
  end

  def test_invalid_name
    assert_raise(NameError) do
      create_module "My Model"
    end
  end

  def test_already_defined
    blder = Arby::Dsl::alloy_model("MyModel1")
    assert_seq_equal [MyModel1], blder.return_result(:array)
  end

end
