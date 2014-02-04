require 'my_test_helper'
require 'arby/ast/bounds'
require 'arby/bridge/compiler'
require 'arby/bridge/solution'
require 'arby_models/seq_filtering'

class SeqFilteringTest < Test::Unit::TestCase
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  include ArbyModels::SeqFiltering

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(ArbyModels::SeqFiltering)
  end

  def test1
    als_model = ArbyModels::SeqFiltering.meta.to_als
    # puts als_model
    # puts "compiling..."

    pi = Arby::Ast::Bounds.new
    a_upper = Arby::Ast::TupleSet.wrap (1..4).map{|_| A.new}
    pi.add_upper(A, a_upper)
    pi.add_upper(A.x, a_upper ** (2..3))
    pi.bound_int(0..5)

    # puts "solving..."
    sol = ArbyModels::SeqFiltering.execute_command(0, pi)

    a4bounds = sol._a4sol.getBoundsSer
    boundsA = a4bounds.get("this/#{A.alloy_name}")
    assert_equal 0, boundsA.a.size()
    assert_equal 4, boundsA.b.size()

    boundsAx = a4bounds.get("this/#{A.x.full_alloy_name}")
    assert_equal 0, boundsAx.a.size()
    assert_equal 8, boundsAx.b.size()

    max_iter = 310000000000000
    iter = 0
    puts "checking nexts for seq_filtering"
    while sol.satisfiable? do
      break if iter > max_iter
      iter += 1
      inst = sol.arby_instance()
      s = to_arr inst.skolem("$filter_s")
      ans = to_arr inst.skolem("$filter_ans")
      check_filter(s, ans)
      sol = sol.next()
    end
  end

  def to_arr(ts)
    ts.map{|a| a[1]}
  end

  def check_filter(s, ans)
    # puts "checking #{pr s} -> #{pr ans}"
    # expected = s.select{|a| a.x < 3}
    expected = ArbyModels::SeqFiltering.filter_i(s)
    assert_seq_equal expected, ans
  end

  def pr(ts)
    ts.map{|a| "#{a.__label}(#{a.x.first[0]})"}.inspect
  end

end
