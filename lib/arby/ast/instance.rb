require 'arby/ast/tuple_set'
require 'sdg_utils/config'

module Arby
  module Ast

    # @typeparam Atom     - anything that responds to :label
    # @typeparam TupleSet - any array-like class
    #
    # @attr label2atom [Hash(String, Atom)]        - atom labels to atoms
    # @attr fld2tuples [Hash(String, TupleSet)]    - field names to tuples
    # @attr skolem2tuples [Hash(String, TupleSet)] - skolem names to tuples
    class Instance

      def self.from_atoms(*atoms)
        all_atoms = ASig.all_reachable_atoms(atoms)
        fld_map = {}
        all_atoms.each do |a|
          if ASig === a
            sig = a.class
            sig.meta.fields(false).each do |fld|
              ts = fld_map[fld] ||= TupleSet.wrap([], fld.full_type)
              ts.union!([a] ** a.read_field(fld))
            end
          end
        end
        Instance.new :atoms => all_atoms, :fld_map => fld_map, :dup => false
      end

      @@default_params = SDGUtils::Config.new do |c|
        c.model = nil
        c.atoms = []
        c.fld_map = {}
        c.skolem_map = {}
        c.dup = true
        c.univ = nil
      end

      # @param params [Hash]
      #  :atoms      => [Array(Atom)]
      #  :fld_map    => [Hash(String, TupleSet)]
      #  :skolem_map => [Hash(String, TupleSet)]
      #  :dup        => Bool
      #  :model      => Arby::Ast::Model
      #  :univ       => Arby::Ast::Universe
      def initialize(params={})
        params = @@default_params.extend(params)
        dup            = params[:dup]
        @model         = params[:model]
        @univ          = params[:univ]
        @atoms         = dup ? params[:atoms].dup : params[:atoms]
        lab = proc{|a| @univ ? (@univ.label(a) || a.__label) : a.__label}
        @label2atom    = Hash[@atoms.map{|a| [lab[a], a]}]
        @type2atoms    = @atoms.group_by(&:class)
        @fld2tuples    = dup ? params[:fld_map].dup : params[:fld_map]
        @skolem2tuples = dup ? params[:skolem_map].dup : params[:skolem_map]

        ([@label2atom, @type2atoms, @fld2tuples, @skolem2, self] +
          @fld2tuples.values + @skolem2tuples.values).each(&:freeze)
      end

      def model()      @model end
      def atoms()      @atoms end
      def fields()     @fld2tuples.keys end
      def skolems()    @skolem2tuples.keys end

      def atom(label)
        case label
        when Integer then label
        when String, Symbol
          label = label.to_s
          @label2atom[label] || (Integer(label) rescue nil)
        else
          fail "label must be either Integer, String or Symbol but is #{label.class}"
        end
      end
      def field(fld)   @fld2tuples[fld] end
      def skolem(name) @skolem2tuples[name] end

      def atom!(label)  atom(label)  or fail("atom `#{label}' not found") end
      def field!(fld)   field(fld)   or fail("field `#{fld}' not found") end
      def skolem!(name) skolem(name) or fail("skolem `#{name}' not found") end

      def [](key)
        case key
        when Class           then @type2atoms[key] || []
        when Field           then field(key)
        when Expr::FieldExpr then field(key.__field)
        else
          atom(key) || skolem(key) || field(key)
        end
      end

      def to_bounds
        require 'arby/ast/bounds'
        bounds = Bounds.new
        atoms.group_by(&:class).each do |cls, atoms|
          bounds.bound_exactly(cls, atoms) if cls < Arby::Ast::ASig
        end
        @fld2tuples.each{|fld, ts| bounds.bound_exactly(fld, ts)}
        bounds
      end

      def to_s
        atoms_str = atoms.map(&:label).join(', ')
        "atoms:\n  #{atoms_str}\n" +
          "fields:\n  #{@fld2tuples}\n" +
          "skolems:\n  #{@skolem2tuples}"
      end
    end

  end
end

