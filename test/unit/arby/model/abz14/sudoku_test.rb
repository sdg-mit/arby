require 'my_test_helper'
require 'arby_models/abz14/sudoku'

class ABZ14SudokuTest < Test::Unit::TestCase
  include SDGUtils::Testing::SmartSetup
  include SDGUtils::Testing::Assertions
  include Arby::Bridge

  SudokuModel = ArbyModels::ABZ14::SudokuModel
  include SudokuModel

  def setup_class
    Arby.reset
    Arby.meta.restrict_to(SudokuModel)
    @@puzle = """
......95.
.8.7..6..
4...68...
3...5.7.2
...9.4...
2.6.1...5
...18...9
..2..3.6.
.35......
"""
    @@num_given = 26
  end

  def test_als
    # puts SudokuModel.meta.to_als
    assert SudokuModel.compile
  end

  def test_simple
    SudokuModel.N = 4
    s = Sudoku.parse "0,0,1; 0,3,4; 3,1,1; 2,2,3"
    s.solve();
    assert_equal 16, s.grid.size
    puts s.print
  end

  def gen(n_filled=SudokuModel.N * SudokuModel.N)
    s = Sudoku.new
    sol = s.solve
    return nil unless sol.satisfiable?
    while s && s.grid.size > n_filled do fail(); s = dec(s); end
    s
  end

  def dec(sudoku, order=Array(0...sudoku.grid.size).shuffle)
    return nil if order.empty?
    s1 = Sudoku.new :grid => sudoku.grid.delete_at(order.first)
    sol = s1.clone.solve()
    (sol.satisfiable? && !sol.next.satisfiable?) ? s1 : dec(sudoku, order[1..-1])
  end

  def min(sudoku)
    puts "minimizing size #{sudoku.grid.size}"
    (s1 = dec(sudoku)) ? min(s1) : sudoku
  end

  def test_min
    old = SudokuModel.N
    SudokuModel.N = 4
    require 'sdg_utils/timing/timer'
    timer = SDGUtils::Timing::Timer.new
    s = timer.time_it {min(gen())}
    assert s
    puts "local minimum found: #{s.grid.size}"
    puts "total time: #{timer.last_time}"
  ensure
    SudokuModel.N = old
  end

  def do_test_n(n)
    old = SudokuModel.N
    SudokuModel.N = n

    puts "solving sudoku for size #{n}"
    s = Sudoku.new
    sol = s.solve()
    assert sol.satisfiable?, "instance not found"
    assert_equal n*n, s.grid.size
  ensure
    SudokuModel.N = old
  end

  def test_size4()  do_test_n(4) end
  def test_size9()  do_test_n(9) end
  # def test_size16() do_test_n(16) end

  def test_abz
    old = SudokuModel.N
    SudokuModel.N = 4

    puts "solving sudoku for size #{4}"
    s = Sudoku.new :grid => [[0, 0, 1], [0, 3, 4], [3, 1, 1], [2, 2, 3]]
    puts s.print
    sol = s.solve()
    assert sol.satisfiable?, "instance not found"
    fail unless s.grid.size == 16
    assert_equal 16, s.grid.size
    puts s.print
  ensure
    SudokuModel.N = old
  end

  def test_instance_pi
    s = Sudoku.parse1 @@puzle
    puts s.print

    old_grid = s.grid.dup

    puts "solving sudoku with partial instance..."
    sol = s.solve()
    puts "solving time: #{sol.solving_time}s"

    assert sol.satisfiable?, "instance not found"
    assert_equal 81, s.grid.size
    assert old_grid.in?(s.grid)

    a4bounds = sol._a4sol.getBoundsSer
    # a4sudoku_bounds = a4bounds.get("this/#{Sudoku.alloy_name}")
    # assert_equal 1, a4sudoku_bounds.a.size()
    # assert_equal 1, a4sudoku_bounds.b.size()

    a4grid_bounds = a4bounds.get("this/#{Sudoku.grid.full_alloy_name}")
    assert_equal 26, a4grid_bounds.a.size()
    assert_equal 521, a4grid_bounds.b.size()

    puts
    puts s.print

    puts "checking for any other solutions..."
    assert !sol.next.satisfiable?
  end


end
