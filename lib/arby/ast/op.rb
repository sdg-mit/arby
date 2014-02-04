module Arby
  module Ast

    class Op
      # both :sym and :name must be unique accross all operators
      attr_reader :sym, :name, :arity, :precedence

      @@op_by_sym  = {}
      @@op_by_name = {}
      @@ops        = []

      def initialize(sym, name, arity=0, precedence=-1)
        @sym        = sym
        @name       = name
        @arity      = arity
        @precedence = precedence

        @@ops << self
        @@op_by_sym.merge!({sym => self})
        @@op_by_name.merge!({name => self})
      end

      def to_s() sym.to_s end

      def self.by_sym(sym)     @@op_by_sym[sym] end
      def self.by_name(name)   @@op_by_name[name] end
      def self.by_arity(arity) @@ops.select{|o| o.arity == arity} end
      def self.by_class(cls)   @@ops.select{|o| cls === o} end
      def self.all()           @@ops.clone end
    end

    class Uop < Op
      def initialize(sym, name, precedence)
        super(sym, name, 1, precedence)
      end
    end

    class Bop < Op
      def initialize(sym, name, precedence)
        super(sym, name, 2, precedence)
      end
    end

    class Qop < Op
      def initialize(sym, name, precedence=1)
        super(sym, name, -1, precedence)
      end
    end

    class Mop < Op
      def initialize(sym, name, precedence)
        super(sym, name, 1, precedence)
      end
    end

    module Ops
      # multiplicity type modifiers
      SET         = Mop.new(:"set",        "set",         8)
      SEQ         = Mop.new(:"seq",        "seq",         8)

      # unary operators
      NOT         = Uop.new(:"!",          "not",         6)
      NO          = Uop.new(:"no",         "no",          8)
      SOME        = Uop.new(:"some",       "some",        8)
      LONE        = Uop.new(:"lone",       "lone",        8)
      ONE         = Uop.new(:"one",        "one",         8)
      TRANSPOSE   = Uop.new(:"~",          "transpose",   19)
      RCLOSURE    = Uop.new(:"*",          "rclosure",    19)
      CLOSURE     = Uop.new(:"^",          "closure",     19)
      CARDINALITY = Uop.new(:"#",          "cardinality", 11)
      NOOP        = Uop.new(:"NOOP",       "noop",        100)

      # binary operators
      JOIN       = Bop.new(:".",   "join",       18)
      SELECT     = Bop.new(:"[]",  "select",     17)
      PRODUCT    = Bop.new(:"->",  "product",    14)
      DOMAIN     = Bop.new(:"<:",  "domain",     15)
      RANGE      = Bop.new(:":>",  "range",      16)
      INTERSECT  = Bop.new(:"&",   "intersect",  13)
      PLUSPLUS   = Bop.new(:"++",  "plusplus",   12)
      PLUS       = Bop.new(:"+",   "plus",       10)
      IPLUS      = Bop.new(:"@+",  "iplus",      10)
      MINUS      = Bop.new(:"-",   "minus",      10)
      IMINUS     = Bop.new(:"@-",  "iminus",     10)
      MUL        = Bop.new(:"*",   "mul",        19)
      DIV        = Bop.new(:"/",   "div",        19)
      REM        = Bop.new(:"%",   "rem",        19)
      IMPLIES    = Bop.new(:"=>",  "implies",    4)
      ASSIGN     = Bop.new(:":=",  "assign",     7)
      EQUALS     = Bop.new(:"=",   "equals",     7)
      NOT_EQUALS = Bop.new(:"!=",  "not_equals", 7)
      LT         = Bop.new(:"<",   "lt",         7)
      LTE        = Bop.new(:"<=",  "lte",        7)
      GT         = Bop.new(:">",   "gt",         7)
      GTE        = Bop.new(:">=",  "gte",        7)
      NOT_LT     = Bop.new(:"!<",  "not_lt",     7)
      NOT_LTE    = Bop.new(:"!<=", "not_lte",    7)
      NOT_GT     = Bop.new(:"!>",  "not_gt",     7)
      NOT_GTE    = Bop.new(:"!>=", "not_gte",    7)
      IN         = Bop.new(:"in",  "in",         7)
      NOT_IN     = Bop.new(:"!in", "not_in",     7)
      SHL        = Bop.new(:"<<",  "shl",        9)
      SHA        = Bop.new(:">>",  "sha",        9)
      SHR        = Bop.new(:">>>", "shr",        9)
      AND        = Bop.new(:"&&",  "and",        5)
      OR         = Bop.new(:"||",  "or",         2)
      IFF        = Bop.new(:"<=>", "iff",        3)


      # quantifier operators
      LET       = Qop.new(:"let",    "let")
      SUM       = Qop.new(:"sum",    "sum")
      SETCPH    = Qop.new(:"{}",     "comprehension")
      ALLOF     = Qop.new(:"all",    "all")
      SOMEOF    = Qop.new(:"some",   "exist")
      NONEOF    = Qop.new(:"no",     "noneof")
      ONEOF     = Qop.new(:"one",    "oneof")
      LONEOF    = Qop.new(:"lone",   "loneof")

      # other
      IF_ELSE   = Op.new(:"=>else", "if_else", 3, 4)
      UNKNOWN   = Op.new(:"_",      "unknown", 0, 0)

      def self.all()        constants.map{|sym| const_get(sym)} end
      def self.each(&block) all.each(&block) end
    end

  end
end
