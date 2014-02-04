require 'arby/ast/bounds'
require 'arby/ast/instance'
require 'arby/bridge/imports'
require 'arby/bridge/helpers'
require 'arby/bridge/translator'
require 'sdg_utils/proxy'

module Arby
  module Bridge

    # ------------------------------------------------------------------
    # Simple wrapper for an Alloy type.
    #
    # @attr a4type [Rjb::Proxy ~> edu.mit.csail.sdg.alloy4compiler.ast.Type]
    # @attr prim_sigs [Array(Rjb::Proxy ~> edu.mit.csail.sdg.alloy4compiler.ast.PrimSig)]
    # ------------------------------------------------------------------
    class Type
      include Helpers

      # @param a4type[Rjb::Proxy ~> edu.mit.csail.sdg.alloy4compiler.ast.Type,
      #               Array(Rjb::Proxy ~> edu.mit.csail.sdg.alloy4compiler.ast.PrimSig)]
      def initialize(a4type)
        if Array === a4type
          @prim_sigs = a4type
        else
          @a4type = a4type
          union_types = a4type.fold
          fail "Union types not supported: #{a4type.toString}" unless union_types.size==1
          @prim_sigs = java_to_ruby_array(union_types.get(0))
        end
        @signature = @prim_sigs.map(&:toString).join(" -> ")
      end

      def prim_sigs() @prim_sigs end
      def signature() @signature end
      def arity()     @prim_sigs.size end
      def to_s()      @signature end
    end

    # ------------------------------------------------------------------
    # Simple wrapper for an Alloy atom.
    #
    # @attr a4atom [Rjb::Proxy ~> edu.mit.csail.sdg.alloy4compiler.ast.ExprVar]
    # @attr label [String]
    # @attr type [Arby::Bridge::Type]
    # ------------------------------------------------------------------
    class Atom
      attr_reader :a4atom, :label, :type

      # Takes either an a4atom, or name/a4type pair.
      #
      # @param a4atom [Rjb::Proxy ~> edu.mit.csail.sdg.alloy4compiler.ast.ExprVar]
      # @param name [String]
      # @param a4type [Rjb::Proxy ~> edu.mit.csail.sdg.alloy4compiler.ast.Type]
      def initialize(a4atom, label=nil, type=nil)
        @a4atom = a4atom
        @label = a4atom ? a4atom.toString : label
        @type = Type.new(a4atom ? a4atom.type : type)
      end

      alias_method :__label, :label

      def to_s() "#{label}: #{type}" end
    end

    # ------------------------------------------------------------------
    # Simple wrapper for an Alloy TupleSet.
    #
    # @attr type [Arby::Bridge::Type]
    # @tuples [Array(Array(Arby::Bridge::Atom))]
    # ------------------------------------------------------------------
    class TupleSet < SDGUtils::Proxy
      attr_reader :type, :tuples

      def initialize(type, tuples)
        @type, @tuples = type, tuples
        super(@tuples)
      end
    end

    module SolutionConv
      include Helpers
      extend self

      # Returns an object of type +Arby::Ast::Instance+ with type
      # parameters +Atom+ and +TupleSet+ corrsponding to
      # +Arby::Bridge::Atom+ and +Arby::Bridge::TupleSet+.
      #
      # @param a4world [Rjb::Proxy ~> CompModule]
      # @param a4sol [Rjb::Proxy ~> A4Solution]
      # @return [Arby::Ast::Instance]
      def to_instance(a4world, a4sol)
        atoms = []
        fld_map = {}
        skolem_map = {}

        if a4sol.satisfiable
          atoms = wrap_atoms(a4sol)

          fld_map = AlloyCompiler.all_fields(a4world).map do |field|
            [field.label, eval_expr(a4sol, field)]
          end
          fld_map = Hash[fld_map]

          skolem_map = jmap(a4sol.getAllSkolems) do |expr|
            [expr.toString, eval_expr(a4sol, expr)]
          end
          skolem_map = Hash[skolem_map]
        end

        Arby::Ast::Instance.new :atoms      => atoms,
                                :fld_map    => fld_map,
                                :skolem_map => skolem_map,
                                :dup        => false
      end

      # Takes an Rjb Proxy object pointing to an A4Solution, gets all
      # atoms from it, and wraps them in +Arby::Bridge::Atom+.
      #
      # @param a4atoms [Rjb::Proxy -> A4Solution]
      # @return [Array(Arby::Bridge::Atom)]
      def wrap_atoms(a4sol)
        a4atoms = a4sol.getAllAtoms
        len = a4atoms.size
        (0...len).map{ |idx| Atom.new(a4atoms.get(idx)) }
      end

      # Returns a hash of tuples grouped by field names.
      #
      # @param a4sol [Rjb::Proxy ~> A4Solution]
      # @param a4sol [Rjb::Proxy ~> Expr]
      # @return [Arby::Bridge::TupleSet]
      def eval_expr(a4sol, a4expr)
        expr_type = Type.new(a4expr.type)
        expr_tuples = translate_tuple_set(a4sol.eval(a4expr))
        TupleSet.new(expr_type, expr_tuples)
      end

      # Traverses a given Alloy tupleset, wraps all atom in it, and
      # returns an array of arrays of atoms.
      #
      # @param a4tuple_set [Rjb::Proxy ~> A4TupleSet]
      # @return [Array(Array(Atom))]
      def translate_tuple_set(a4tuple_set)
        jmap_iter(a4tuple_set) do |t|
          (0...t.arity).map{|col| Atom.new(nil, t.atom(col), [t.sig(col)]) }
        end
      end
    end

    # -------------------------------------------------------------------
    # Class +Solution+
    #
    # Wraps Alloy's +A4Solution+.  Represents a solution of a
    # previously executed (model-finding) command.
    # -------------------------------------------------------------------
    class Solution
      def initialize(a4sol, compiler=nil, univ=nil, bounds=nil, solving_time=nil)
        fail "no A4Solution given" unless a4sol
        @a4sol = a4sol
        @compiler = compiler
        @univ = univ
        @bounds = bounds
        @instance = nil
        @solving_time = solving_time
        @solving_params = nil
      end

      def _a4sol()   @a4sol end
      def compiler() @compiler end
      def univ()     @univ end
      def bounds()   @bounds end
      def model()    @compiler.model end

      def set_solving_params(kind, *args)
        @solving_params = [kind, args]
      end

      def satisfiable?() @a4sol.satisfiable end
      def solving_time() @solving_time end
      def next(__locals={})
        if block_given?
          fail "no solving params" unless @solving_params
          fail unless @compiler && m=Arby::Ast::TypeChecker.get_arby_model(@compiler.model)
          __curr_inst = (satisfiable?) ? arby_instance() : nil
          m2 = m.extend do
            self.send :define_method, :inst, &proc{__curr_inst}
            self.send :define_method, :sol, &proc{__curr_inst}
            __locals.each{|k,v| self.send :define_method, k, &proc{__locals[k]}}
            fact "pi_fact_#{SDGUtils::Random.salted_timestamp}", &Proc.new
          end
          bnds = @bounds
          if !bnds && __curr_inst
            #TODO: not the best solution
            bnds = Arby::Ast::Bounds.new
            __curr_inst.atoms.group_by(&:class).each do |cls, atoms|
              bnds.lo[cls] = atoms
            end
          end
          Compiler.new(m2.meta, bnds).send @solving_params.first, *@solving_params.last
        else
          Solution.new(@a4sol.next(), @compiler)
        end
      end

      # Converts the wrapped +A4Solution+ into +Arby::Ast::Instance+
      #
      # @see SolutionConv#to_instance
      # @return [Arby::Ast::Instance]
      def instance()
        @instance ||= SolutionConv.to_instance(@compiler._a4world, @a4sol)
      end

      # Translates the underlying solution from Alloy to aRby:
      #
      #   - the Alloy atoms are converted to instances of
      #     corresponding aRby sig classes (aRby atoms)
      #
      #   - the fields values of the aRby atoms are set to match the
      #     values of the Alloy field relations in this solution.
      #
      # @see SolutionConv.arby_instance
      #
      # @return [Hash(String, Sig)] - a map of atom labels to aRby atoms
      def arby_instance()
        return Arby::Ast::Instance.new unless satisfiable?
        @arby_instance ||= Translator.to_arby_instance(instance(), univ, compiler.model)
      end

      def [](key) arby_instance()[key] end

      private

      def fail_if_unsat
        fail "No instance found (the problem is unsatisfiable)" unless satisfiable?
      end

    end
  end
end
