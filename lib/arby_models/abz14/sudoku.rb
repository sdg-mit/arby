require 'arby/arby_dsl'
require 'arby/ast/bounds'
require 'arby/ast/type_consts'

Int = Arby::Ast::TypeConsts::Int

module ArbyModels
module ABZ14
  extend Arby::Dsl

  alloy :SudokuModel do
    SudokuModel::N = 9

    sig Sudoku [grid: Int ** Int ** (lone Int)]

    pred solved[s: Sudoku] {
      m = Integer(Math.sqrt(N))
      rng = lambda{|i| m*i...m*(i+1)}

      all(r: 0...N)    {
        s.grid[r][Int] == (1..N) and
        s.grid[Int][r] == (1..N)
      } and
      all(c, r: 0...m) {
        s.grid[rng[c]][rng[r]] == (1..N)
      }
    }
  end

  class SudokuModel::Sudoku
    def self.parse1(str)
      rows = str.split("\n").map(&:strip).reject(&:empty?)
      fail "expected exactly #{N} lines, got #{rows.size}" unless rows.size == N
      fail "expected exactly #{N} chars in each line" unless rows.all?{|r| r.size == N}
      self.new :grid => rows.each_with_index.map{ |row, row_idx|
        row.chars.each_with_index.map{ |ch, col_idx|
          (ch>="1" && ch<=String(N)) ? [row_idx, col_idx, Integer(ch)] : nil
        }.compact
      }.flatten(1)
    end

    def self.parse(str) Sudoku.new grid: 
        str.split(/\s*;\s*/).map{|x| x.split(/\s*,\s*/).map(&:to_i)}
    end

    def partial_instance
      bounds = Arby::Ast::Bounds.new
      indexes = (0...N) ** (0...N) - self.grid.project(0..1)
      bounds.bound(Sudoku.grid, self ** self.grid, self ** indexes ** (1..N))
      bounds.bound(Sudoku, self)
      bounds.bound_int(0..N)
      bounds
    end

    def solve
      SudokuModel.solve(:solved, self.partial_instance)
    end

    def print
      m = Integer(Math.sqrt(N))
      dshs = "-"*(m*2+1)
      dsha = m.times.map{dshs}
      dshjp = dsha.join('+')
      "+#{dshjp}+\n" +
        (0...N).map{|i|
          row = (0...N).map{|j|
            s = self.grid[i][j]
            cell = s.empty?() ? "." : s.to_s
            j % m == 0 ? "| #{cell}" : cell
          }.join(" ") + " |"
        i > 0 && i % m == 0 ? "|#{dshjp}|\n#{row}" : row
        }.join("\n") + "\n" +
        "+#{dshjp}+"
    end
  end


end
end


