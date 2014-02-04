require_relative 'arby_rel_test_helper.rb'

#------------------------------------------
# == Class TestArbyRelationExt
#------------------------------------------
class TestArbyRelationExt < Test::Unit::TestCase
  include ArbyRelationTestHelper

  def testArrayExt
    ary = [1, 3, 4]
    arr = ary.as_rel
    assert_equal 1, arr.arity
    assert_equal 3, arr.tuples.length
    assert_tuple [1], arr.tuples[0]
    assert_tuple [3], arr.tuples[1]
    assert_tuple [4], arr.tuples[2]

    assert_equal 1, [].as_rel.arity
    assert_equal [], [].as_rel.tuples
    assert_empty_rel 1, [].as_rel
  end

  def testArrayWithIndexExt
    ary = [1, 3, 4]
    arr = ary.as_rel_with_index
    assert_equal 2, arr.arity
    assert_equal 3, arr.tuples.length
    assert_tuple [0, 1], arr.tuples[0]
    assert_tuple [1, 3], arr.tuples[1]
    assert_tuple [2, 4], arr.tuples[2]
  end

  def testObjectExt
    src = Object.new
    obj = src.as_rel
    assert_equal 1, obj.arity
    assert_equal 1, obj.tuples.length
    assert_tuple [src], obj.tuples.first

    assert_empty_rel 1, nil.as_rel
  end

  def testHashExt
    h = { "a" => 1, "d" => 2, "f" => 35 }.as_rel
    assert_equal 2, h.arity
    ts = h.tuples
    assert_equal 3, ts.length
    assert_tuple ["a", 1], ts[0]
    assert_tuple ["d", 2], ts[1]
    assert_tuple ["f", 35], ts[2]

    assert_empty_rel 2, {}.as_rel
  end

  def testSetExt
    set = (Set.new << "1" << "d" << "1").as_rel
    assert_equal 1, set.arity
    assert_equal 2, set.tuples.length
    assert_tuple ["1"], set.tuples[0]
    assert_tuple ["d"], set.tuples[1]

    assert_empty_rel 1, Set.new.as_rel
  end
end
