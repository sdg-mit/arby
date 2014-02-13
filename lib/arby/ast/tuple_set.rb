require 'arby/ast/sig'
require 'arby/ast/types'
require 'arby/ast/type_checker'
require 'arby/relations/relation'
require 'sdg_utils/delegator'

module Arby
  module Ast

    module TypeMethodsHelper
      def add_methods_for_type()
        return if @type.nil? || @type.none?
        cls = (class << self; self end)
        range_cls = @type.range.klass
        fields = []
        if (Arby::Ast::ASig > range_cls rescue false)
          fields = range_cls.meta.fields_including_sub_and_super
        elsif @type.range.univ?
          fields = Arby.meta.reachable_fields
        end
        # field += range_cls.meta.inv_fields_including_sub_and_super
        mod = Module.new
        fields.each do |fld|
          fname = fld.getter_sym
          unless self.respond_to?(fname, true)
            #TODO: OPT
            mod.send(:define_method, fname) do
              self.send :_join_fld, fld
            end
          end
        end
        cls.send :include, mod
      end
    end

    module ArbyRelCommon
      def _target() @target end
      def _type()   @type end
      def _type_op_t(op, other_type)
        (self._type && other_type) ? _type.send(op, other_type) : nil
      end
      def _type_op(op, other_ts)
        other_ts && _type_op_t(op, other_ts._type)
      end
      alias_method :__type, :_type

      def wrap(*a)  self.class.wrap(*a) end
      def unwrap()  TupleSet.unwrap(self) end

      def call(other)
        if Symbol === other
          _read_fld_full(other)
        else
          self.join(other)
        end
      end

      def hash()    TupleSet.unwrap(self).hash end
      def ==(other) TupleSet.unwrap(self) == TupleSet.unwrap(other) end
      alias_method  :eql?, :==

      def to_expr() Arby::Ast::Expr.resolve_expr(self) end
    end

    class Tuple
      # include Arby::Relations::MTuple
      include ArbyRelCommon
      include SDGUtils::MDelegator
      include TypeMethodsHelper
      include Enumerable

      private

      def initialize(type, atoms)
        atoms = Array(atoms) #TODO: fail if there are nils .reject(&:nil?)
        type ||= AType.get!(atoms.map(&:class))
        TypeChecker.typecheck(type, atoms)
        # type.arity == 1 ? super(atoms.first) : super(atoms)
        @type = type
        @atoms = atoms
        @target = @atoms # for MDelegator
        add_methods_for_type
      end

      public

      def self.wrap(t, type=nil)
        type = AType.get!(type) if type
        case t
        when Tuple then t
        else
          Tuple.new(type, t)
        end
      end

      def clone()  wrap(@atoms.dup, @type) end
      alias_method :dup, :clone

      def each() atoms.each {|a| yield a } end

      def atoms()   @atoms.dup() end
      def atoms!()  @atoms end
      def atom(idx) @atoms[idx] end
      def size()    @atoms.size end
      def empty?()  @atoms.empty? end
      def arity()   @type ? @type.arity : @atoms.size end

      def join(other)
        other = wrap(other)
        if atom(-1) == other.atom(0)
          lhs_atoms = length > 1 ? atoms[0..-2] : []
          rhs_atoms = other.length > 1 ? other.atoms[1..-1] : []
          ans_atoms = lhs_atoms + rhs_atoms
          ans_type  = _type_op(:join, other)
          wrap(ans_atoms, ans_type)
        else
          nil
        end
      end

      def product(other)
        other = wrap(other)
        ans_atoms = atoms + other.atoms
        ans_type  = _type_op(:product, other)
        wrap(ans_atoms, ans_type)
      end

      def project(*indexes)
        indexes = indexes.map{|i| Array(i)}.flatten
        ans_atoms = indexes.map{|i| atom(i)}
        ans_type  = _type && _type.project(*indexes)
        wrap(ans_atoms, ans_type)
      end

      def _join_fld(fld)
        fname, ftype = case fld
                       when Field          then [fld.getter_sym, fld.full_type]
                       when String, Symbol then [fld, nil]
                       else fail("can't join #{fld.class}")
                       end
        ans_type = _type_op_t(:join, ftype)
        rhs = self.atoms.last
        if rhs.nil?
          TupleSet.wrap(nil, ans_type)
        else
          rhs_tset = rhs.send(fname)
          num_atoms = atoms.size
          if num_atoms == 1
            rhs_tset
          else
            t = @type && @type.project(0...num_atoms-1)
            lhs_tset = TupleSet.wrap([atoms[0...-1]] * rhs_tset.size, t)
            lhs_tset.zip(rhs_tset)
          end
        end
      end

      def _read_fld_full(fld)
        TupleSet.wrap([self], @type) ** _join_fld(fld)
      end

      def to_s()    "<" + @atoms.map(&:to_s).join(", ") + ">" end
      def inspect() to_s end
    end

    ###############################################

    class TupleSet
      # include Arby::Relations::MRelation
      include ArbyRelCommon
      include TypeMethodsHelper
      include SDGUtils::MDelegator
      include Enumerable

      private

      def initialize(type, tuples)
        tuples = Array(tuples)
        @tuples = Set.new(tuples.map{|t| Tuple.wrap(t, type)}.reject(&:empty?))
        @type = type || AType.interpolate(@tuples.map(&:_type))
        TypeChecker.assert_type(@type) if @type && !@type.none?
        @target = @tuples # for MDelegator
        # (type.scalar?) ? super(@tuples.first) : super(@tuples)
        add_methods_for_type
      end

      public

      def self.wrap(t, type=nil)
        type = AType.get!(type) if type
        case t
        when TupleSet then t #TODO: check and set type if unset
        when AType
          TupleSet.new(type, [t.columns])
        else
          TupleSet.new(type, t)
        end
      end

      def self.unwrap(t)
        case t
        when TupleSet then self.unwrap(t.tuples)
        when Tuple    then self.unwrap(t.atoms)
        when Array, Set
          if t.empty?       then nil
          elsif t.size == 1 then self.unwrap(t.first)
          else
            t.map{|e| self.unwrap(e)}
          end
        else
          t
        end
      end

      def clone()      wrap(tuples, @type) end
      alias_method     :dup, :clone

      def each()       tuples.each {|t| yield t} end

      def arity()      @type.arity end
      def tuples()     @tuples.to_a end
      def tuples!()    @tuples end
      def size()       @tuples.size end
      def empty?()     @tuples.empty? end
      def clear!()     @tuples.clear end
      def delete_at(i) t = tuples(); t.delete_at(i); wrap(t, @type) end
      def delete_at!(i)
        new_tuples = @tuples.to_a
        ans = new_tuples.delete_at(i)
        @tuples = Set.new(new_tuples)
        ans
      end

      def contains?(a) a.all?{|e| tuples.member?(e)} end
      def in?(a)       Arby.symbolic_mode?() ? to_expr().in?(a) : wrap(a).contains?(self) end
      def ljoin(ts)    wrap(ts).join(self) end

      def <(other)     int_cmp(:<, other) end
      def >(other)     int_cmp(:>, other) end
      def <=(other)    int_cmp(:<=, other) end
      def >=(other)    int_cmp(:>=, other) end

      def sum
        assert_int_set!("sum")
        @tuples.reduce(0){|sum, t| sum + t[0]}
      end

      def join(other)
        other = wrap(other)
        fail("arity must not be 0") unless arity > 0 && other.arity > 0

        newArity = arity + other.arity - 2
        fail("sum of the two arities must be greater than 0") unless newArity > 0

        ans_tuples = tuples.product(other.tuples).map{|l, r| l.join(r)}.compact
        ans_type   = _type_op(:join, other)
        wrap(ans_tuples, ans_type)
      end

      def zip(other)
        other = wrap(other)
        len = [size(), other.size()].min
        this_tuples = tuples()
        other_tuples = other.tuples()
        ans_tuples = (0...len).map{|i| this_tuples[i].product(other_tuples[i])}
        ans_type   = _type_op(:product, other)
        wrap(ans_tuples, ans_type)
      end

      def product(other)
        other = wrap(other)
        ans_tuples = tuples.product(other.tuples).map{|l, r| l.product(r)}
        ans_type   = _type_op(:product, other)
        wrap(ans_tuples, ans_type)
      end

      def union!(other)
        other = wrap(other)
        check_same_arity(other)
        @tuples += other.tuples
        self
      end

      def union(other)
        other = wrap(other)
        check_same_arity(other)
        ans_type = _type_op(:union, other) || _type || other._type
        wrap(self.tuples + other.tuples, ans_type)
      end

      def difference!(other)
        other = wrap(other)
        check_same_arity(other)
        @tuples -= other.tuples
        self
      end

      def difference(other)
        other = wrap(other)
        check_same_arity(other)
        ans_type = _type_op(:difference, other) || _type || other._type
        wrap(self.tuples - other.tuples, ans_type)
      end

      def project(*args)
        ans_type = _type && _type.project(*args)
        wrap(@tuples.map{|t| t.project(*args)}, ans_type)
      end

      def domain(other)
        ans_tuples = wrap(other).tuples.select{|t| self.contains?(t.project(0))}
        wrap(ans_tuples, other.__type)
      end
      def range(other)
        ans_tuples = tuples.select{|t| t.project(arity-1).in?(other)}
        wrap(ans_tuples, __type)
      end

      def [](other) ljoin(other) end
      alias_method :*,    :zip
      alias_method :**,   :product
      alias_method :-,    :difference
      alias_method :"-=", :difference!
      alias_method :+,    :union
      alias_method :"+=", :union!
      alias_method :plus,   :union
      alias_method :plus!,  :union!
      alias_method :minus,  :difference
      alias_method :minus!, :difference!

      def inspect(sep=",\n") "{" + @tuples.map(&:to_s).join(sep) + "}" end
      def to_s()             TupleSet.unwrap(self).to_s end

      def assert_int_set!(op)
        unless @type && @type.isInt?
          raise TypeError, "#{self} must be an integer value to be able to apply #{op};"+
            "instead, its type is #{@type}"
        end
      end

      private

      def check_same_arity(other)
        fail("arity mismatch: #{arity}, #{other.arity}") unless arity == other.arity
      end

      def int_cmp(op, other)
        self.sum.send(op, wrap(other).sum)
      end

      def _join_fld(fld)
        fname, ftype = case fld
                       when Field          then [fld.getter_sym, fld.full_type]
                       when String, Symbol then [fld, nil]
                       else fail("can't join #{fld.class}")
                       end
        ans = TupleSet.new(_type_op_t(:join, ftype), [])
        self.tuples.map(&fname).reduce(ans){|acc, ts| acc.union!(ts)}
      end

      def _read_fld_full(fld)
        tuples.reduce(nil){|acc, t|
          aux = t._read_fld_full(fld)
          if acc == nil
            aux
          else
            acc.union!(aux)
          end
        }
      end
    end

  end
end
