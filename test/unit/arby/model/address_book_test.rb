require 'my_test_helper'
require 'arby_models/address_book'
require 'arby/helpers/test/dsl_helpers'
require 'arby/initializer.rb'
require 'arby/bridge/compiler'


class AddressBookTest < Test::Unit::TestCase
  include Arby::Helpers::Test::DslHelpers
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions

  include ArbyModels::AddressBook

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(ArbyModels::AddressBook)

    @@als_model = Arby.meta.to_als
    @@compiler  = ArbyModels::AddressBook.compile
  end

  def test
    # ans = ArbyModels::AddressBook.delUndoesAdd
    # puts "#{ans}"
    # puts "-----------"
    # ans = ArbyModels::AddressBook.delUndoesAdd_alloy
    # puts "#{ans}"
    ans = Arby.meta.to_als
    # assert_equal_ignore_whitespace ArbyModels::AddressBook::Expected_alloy, ans
  end

  def test_check_addIdempotent
    sol = @@compiler.execute_command(:addIdempotent)
    assert !sol.satisfiable?
  end

  def test_check_delUndoesAdd
    sol = @@compiler.execute_command(:delUndoesAdd)
    assert !sol.satisfiable?
  end

  def test_find_model
    inst = ArbyModels::AddressBook.find_instance
  end
end
