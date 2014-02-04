require_relative 'arby_rel_test_helper.rb'

include Arby::Relations

class AtomCls
  include Arby::Relations::MAtom
end

class TestArbyRelation < Test::Unit::TestCase
  include ArbyRelationTestHelper

  def test1
    a = AtomCls.new
    assert_equal 1, a.arity
    ts = a.tuples
    assert_instance_of Array, ts
    assert_equal 1, ts.length
    assert_tuple [a], ts.first
  end

  def test_each
    arr = [Tuple.new(2, ['1', 'a']),
           Tuple.new(2, ['2', 'b']),
           Tuple.new(2, ['3', 'c'])]
    r = Relation.new(2, arr)
    r.each_with_index do |t, i|
      assert_equal arr[i], t
      assert_equal r.tuples[i], t
    end
  end

  def test_join1
    m1 = {"1" => "a", "2" => "b", "3" => "c"}
    m2 = {"b" => "q", "2" => "b", "c" => "w"}
    assert_rel [["2", "q"], ["3", "w"]], m1.as_rel.join(m2)
  end

  def test_join2
    r1 = Relation.new(2, [Tuple.new(2, ['1', 'a']),
                     Tuple.new(2, ['2', 'b']),
                     Tuple.new(2, ['3', 'c'])])

    r2 = Relation.new(2, [Tuple.new(2, ['a', 'q']),
                     Tuple.new(2, ['b', 'w']),
                     Tuple.new(2, ['b', 'e'])])
    assert_rel [["1", "q"], ["2", "w"], ["2", "e"]], r1.as_rel.join(r2)
  end

  def test_join3
    r1 = Relation.new(2, [Tuple.new(2, ['1', 'a']),
                     Tuple.new(2, ['2', 'b']),
                     Tuple.new(2, ['1', 'b'])])

    r2 = Relation.new(2, [Tuple.new(2, ['a', 'q']),
                     Tuple.new(2, ['b', 'q'])])

    assert_rel [["1", "q"], ["2", "q"]], r1.join(r2)
  end

  def test_product1
    m1 = {"1" => "a", "2" => "b", "3" => "c"}
    m2 = Set.new << 2 << 3
    assert_rel [["1", "a", 2], ["1", "a", 3],
                ["2", "b", 2], ["2", "b", 3],
                ["3", "c", 2], ["3", "c", 3]], m1.as_rel.product(m2)
  end

  def test_product2
    r1 = Relation.new(2, [Tuple.new(2, ['1', 'a']),
                     Tuple.new(2, ['2', 'b']),
                     Tuple.new(2, ['3', 'c'])])

    r2 = Relation.new(2, [Tuple.new(2, ['a', 'q']),
                     Tuple.new(2, ['b', 'q'])])

    assert_rel [["1", "a", "a", "q"], ["1", "a", "b", "q"],
                ["2", "b", "a", "q"], ["2", "b", "b", "q"],
                ["3", "c", "a", "q"], ["3", "c", "b", "q"]], r1.as_rel.product(r2)
  end

  def test_union1
    r1 = Relation.new(2, [Tuple.new(2, ['1', 'a']),
                     Tuple.new(2, ['2', 'b']),
                     Tuple.new(2, ['1', 'b'])])

    r2 = Relation.new(2, [Tuple.new(2, ['a', 'q']),
                     Tuple.new(2, ['2', 'b'])])

    assert_rel [["1", "a"], ["2", "b"], ["1", "b"], ["a", "q"]], r1.as_rel.union(r2)
  end

  def test_union2
    m1 = {"1" => "a", "2" => "b", "3" => "c"}
    m2 = Set.new << 2 << 3
    assert_raise(ArityError) { m1.as_rel.union(m2) }
    assert_raise(ArityError) { m1.as_rel.union([3, 2, 4]) }
    assert_rel [["1", "a"], ["2", "b"], ["3", "c"], ["4", "d"]], m1.as_rel.union(["4", "d"].as_tuple)
  end

  def test_intersection1
    r1 = Relation.new(2, [Tuple.new(2, ['1', 'a']),
                     Tuple.new(2, ['2', 'b']),
                     Tuple.new(2, ['1', 'b'])])

    r2 = Relation.new(2, [Tuple.new(2, ['a', 'q']),
                     Tuple.new(2, ['2', 'b'])])

    assert_rel [["2", "b"]], r1.as_rel.intersect(r2)
  end

  def test_intersection2
    r1 = Relation.new(2, [Tuple.new(2, ['1', 'a']),
                     Tuple.new(2, ['2', 'b']),
                     Tuple.new(2, ['1', 'b'])])

    r2 = Relation.new(2, [Tuple.new(2, ['a', 'q']),
                     Tuple.new(2, ['2', 'q'])])

    assert_empty_rel 2, r1.intersect(r2)
  end

  def test_freeze
    lst = [Tuple.new(2, ['a', 'q']), Tuple.new(2, ['2', 'q'])]
    r = Relation.new(2, lst)
    assert_raise(RuntimeError) { r.tuples[0] = nil }
    assert_raise(RuntimeError) { lst[0].arr[0] = nil }
  end
end

#------------------------------------------
# == Class TestTuple
#------------------------------------------
class TestArbyTuple < Test::Unit::TestCase
  include ArbyRelationTestHelper

  def test_arity_0
    assert_raise(ArityError) { Tuple.new(0, [2, 3]) }
  end

  def test_empty_array
    assert_raise(ArityError) { Tuple.new(3, []) }
    assert_raise(ArityError) { Tuple.new(1, nil) }
  end

  def test_nil_atoms
    assert_raise(ArityError) { Tuple.new(1, [nil]) }
    assert_raise(ArityError) { Tuple.new(1, [4, nil]) }
  end

  def test_arity_mismatch
    assert_raise(ArityError) { Tuple.new(1, [3, 2]) }
    assert_raise(ArityError) { Tuple.new(2, [3]) }
  end

  def test_freeze
    t = Tuple.new(1, [3])
    assert_raise(RuntimeError) { t.arr[0] = 0 }
  end
end
