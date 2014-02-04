require 'arby/ast/field'
require 'arby/ast/sig'
require 'arby/ast/tuple_set'
require 'arby/ast/type_checker'

module Arby
  module Ast

    # ----------------------------------------------------------------
    # Class +Universe+
    #
    # @attr universe [Array] - list all all atoms (including ints)
    # @attr atom2label [Hash<Object, String] - maps atoms from
    #                                          +universe+ to unique
    #                                          labels
    # @attr label2atom [Hash<String, Object] - inverse of +atom2label+
    # ----------------------------------------------------------------
    class Universe

      # Labels all atoms in +universe+ to make sure all of them have
      # unique labels in the format of '<sig_name>$<index>'
      #
      # @param universe [Array] - list of all atoms
      def initialize(universe, sig_namer=nil)
        @universe = universe.dup
        @atom2label = {}
        @sig_namer ||= Arby.conf.alloy_printer.sig_namer
        @universe.group_by(&:class).each do |cls, atoms|
          if cls <= Integer
            atoms.each{|i| @atom2label[i] = "#{i}"}
          else
            atoms.each_with_index{|a, x|
              a.__alloy_atom_id = x
              a.__label = "#{@sig_namer[cls]}$#{x}"
              @atom2label[a] = a.__label
            }
          end
        end
        @label2atom = @atom2label.invert
        [@universe, @atom2label, @label2atom].each(&:freeze)
        freeze
      end

      def atoms()          @universe end
      def find_atom(label) @label2atom[label] end
      def sig_atoms()      @universe.select{|a| a.is_a?(ASig)} end
      def label(what)
        @atom2label[what] ||
          begin
            if what.is_a?(Class) && what < ASig
              @sig_namer[what]
            else
              what.to_s
            end
          end
      end
    end

    # ----------------------------------------------------------------
    # Class +BoundBuilder+
    #
    # ----------------------------------------------------------------
    class BoundBuilder
      def initialize(kind, bounds)
        @kind, @bounds = kind, bounds
      end
      def [](what)             @bounds.send :"get_#{@kind}", what end
      def []=(what, tuple_set) @bounds.send :"set_#{@kind}", what, tuple_set end
    end

    # ----------------------------------------------------------------
    # Class +Bounds+
    #
    # Rel: [Class(Arby::Ast::Sig), Arby::Ast::Field]
    #
    # @attr sig_lowers, sig_uppers [Hash(Rel, Arby::Ast::TupleSet)]
    # @attr fld_lowers, fld_uppers [Hash(Rel, Arby::Ast::TupleSet)]
    # ----------------------------------------------------------------
    class Bounds

      def self.from_atoms(*atoms)
        require 'arby/ast/instance'
        Instance.from_atoms(*atoms).to_bounds
      end

      def initialize
        @lowers = {}
        @uppers = {}
      end

      def bound(what, lower, upper=nil)
        set_bound(@lowers, what, lower)
        set_bound(@uppers, what, lower)
        add_bound(@uppers, what, upper) if upper
        self
      end

      def bound_exactly(what, tuple_set) bound(what, tuple_set, nil) end
      def bound_int(*ints)
        @ints = ints.map{|i| Array(i)}.flatten
        self
      end

      def add_lower(what, tuple_set)
        return unless tuple_set
        add_bound(@lowers, what, tuple_set)
        add_bound(@uppers, what, tuple_set)
      end

      def add_upper(what, tuple_set)
        add_bound(@uppers, what, tuple_set)
      end

      def set_lower(what, tuple_set) set_bound(@lowers, what, tuple_set) end
      def set_upper(what, tuple_set) set_bound(@uppers, what, tuple_set) end

      alias_method :[]=, :bound_exactly

      def hi() BoundBuilder.new(:upper, self) end
      def lo() BoundBuilder.new(:lower, self) end

      def get_lower(what) @lowers[what] end #dup ???
      def get_upper(what) @uppers[what] end #dup ???
      def [](what)        [get_lower(what), get_upper(what)] end

      def get_ints()   @ints ? @ints.dup : nil end
      def each_lower() (block_given?) ? @lowers.each{|*a| yield(*a)} : @lowers.each end
      def each_upper() (block_given?) ? @uppers.each{|*a| yield(*a)} : @uppers.each end

      # @return [Universe] - list of all atoms appearing in all the bounds
      def extract_universe(sig_namer=nil)
        univ = Set.new
        entries do |_, what, ts|
          t = type_for_boundable(what)
          unless t.all?(&:primitive?)
            ts_atoms = ts.tuples!.map(&:atoms!).flatten(1)
            univ += ts_atoms.select{|a|
              a.is_a?(Numeric) || a.is_a?(String) || a.is_a?(ASig)}
          end
        end
        Universe.new univ.to_a, sig_namer
      end

      def serialize(univ=nil, pconf=nil)
        pconf ||= Arby.conf.alloy_printer
        univ ||= extract_universe(pconf.sig_namer)

        t_to_s =  proc{|t|  "<" + t.map{|a| univ.label(a)}.join(', ') + ">"}
        ts_to_s = proc{|ts| "{" + ts.map{|t| t_to_s[t]}.join('') + "}"}

        bounds_to_str = proc{|prefix, var|
          var.map{ |what, ts|
            what_name =
              case what
              when Class then pconf.sig_namer[what]
              when Field
                pname = pconf.sig_namer[what.owner]
                fname = pconf.arg_namer[what]
                if what.ordering?
                  "#{pname}_ord/Ord.#{fname[0].capitalize}#{fname[1..-1]}"
                else
                  "#{pname}.#{fname}"
                end
              else what.to_s
              end
            "#{prefix}[#{what_name}] = #{ts_to_s[ts]}"
          }.compact.join("\n")
        }
        ser = """
universe = #{t_to_s[univ.atoms]}
#{bounds_to_str[:lowers, @lowers]}
#{bounds_to_str[:uppers, @uppers]}
"""
        ser += "ints = <#{@ints.join(', ')}>" if @ints
        ser
      end

      private

      def entries
        @lowers.each{|what, ts| yield(:lowers, what, ts)}
        @uppers.each{|what, ts| yield(:uppers, what, ts)}
      end

      def each_where(where)
        if block_given?
          where.each{|*a| yield(*a)}
        else
          where.each
        end
      end

      def set_bound(where, what, tuple_set)
        type = check_boundable(what)
        tuple_set = TupleSet.wrap(tuple_set, type)
        # check_bound(what, tuple_set)
        ts = get_or_new(where, what, type)
        ts.clear!
        ts.union!(tuple_set)
        self
      end

      def add_bound(where, what, tuple_set)
        type = check_boundable(what)
        tuple_set = TupleSet.wrap(tuple_set, type)
        # check_bound(what, tuple_set)
        ts = get_or_new(where, what, type)
        ts.union!(tuple_set)
        self
      end

      def check_bound(what, tuple_set)
        type = check_boundable(what)
        TypeChecker.check_subtype!(type, tuple_set._type)
        type
      end

      def get_or_new(col, what, type)
        col[what] ||= TupleSet.wrap([], type)
      end

      def type_for_boundable(what)
        case
        when Field === what then (what.ordering?) ? what.type : what.full_type
        when TypeChecker.check_sig_class(what) then what.to_atype
        else
          nil
        end
      end

      def check_boundable(what)
        type_for_boundable(what) or (
          msg = "`#{what}' not boundable (expected Field, Class<Sig>, or AType<Int>)" and
          raise(TypeError, msg))
      end
    end

  end
end
