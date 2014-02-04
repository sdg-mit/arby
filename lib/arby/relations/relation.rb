require 'set'

module Arby
  module Relations

    class ArityError < StandardError
    end

    #------------------------------------------
    # == Module MRelation
    #------------------------------------------
    module MRelation
      include Enumerable

      # @return [Integer]
      def arity() fail "must override" end

      # @return [Array(Tuple)]
      def tuples() fail "must override" end

      def tuple_at(idx)
        tuples[idx]
      end

      def length() tuples.length end
      alias_method :size, :length

      def no?(&b)    len = b ? select(&b).size : length; len == 0 end
      def one?(&b)   len = b ? select(&b).size : length; len == 1 end
      def some?(&b)  len = b ? select(&b).size : length; len > 0 end
      def lone?(&b)  no?(&b) || one?(&b) end
      def select(&b) tuples.select(&b) end
      alias_method :empty?, :no?

      def each
        tuples.each { |t| yield t }
      end

      def as_rel() self end
      def wrap(other) other.as_rel end

      def join(other)
        other = self.wrap(other)
        raise ArityError unless arity > 0
        raise ArityError unless other.arity > 0

        newArity = arity + other.arity - 2
        raise ArityError unless newArity > 0

        tuple_set = Set.new(tuples.product(other.tuples).map{|t1, t2|
                              if t1.atom(-1) == t2.atom(0)
                                tt1 = t1.length > 1 ? t1.atoms[0..-2] : []
                                tt2 = t2.length > 1 ? t2.atoms[1..-1] : []
                                Tuple.new(newArity, tt1 + tt2)
                              end
                            }.compact)

        # tuple_set = Set.new
        # tuples.each do |t1|
        #   other.tuples.each do |t2|
        #     if t1.atom(-1) == t2.atom(0)
        #       tt1 = t1.length > 1 ? t1.atoms[0..-2] : []
        #       tt2 = t2.length > 1 ? t2.atoms[1..-1] : []
        #       tuple_set.add(Tuple.new(newArity, tt1 + tt2))
        #     end
        #   end
        # end

        Relation.new(newArity, tuple_set.to_a)
      end

      def product(other)
        other = self.wrap(other)
        raise ArityError, "0-arity not allowed" if arity == 0 || other.arity == 0
        newArity = arity + other.arity
        newTuples = []
        tuples.each do |t1|
          other.tuples.each do |t2|
            newTuples += [Tuple.new(newArity, t1.arr + t2.arr)]
          end
        end
        Relation.new(newArity, newTuples)
      end

      def union(other)
        other = self.wrap(other)
        raise ArityError, "arity mismatch: self.arity = #{arity} != other.arity = #{other.arity}" if arity != other.arity
        tuple_set = Set.new.merge(tuples).merge(other.tuples)
        Relation.new(arity, tuple_set.to_a)
      end

      def intersect(other)
        other = self.wrap(other)
        raise ArityError, "arity mismatch: self.arity = #{arity} != other.arity = #{other.arity}" if arity != other.arity
        ts1 = Set.new.merge(tuples)
        ts2 = Set.new.merge(other.tuples)
        Relation.new(arity, (ts1 & ts2).to_a)
      end
    end

    #------------------------------------------
    # == Module MAtom
    #------------------------------------------
    module MAtom
      include MRelation

      def arity() 1 end
      def as_tuple() Tuple.new(1, [self]) end
      def tuples() (self.nil?) ? [] : [as_tuple] end
    end

    #------------------------------------------
    # == Module +MTuple+
    #
    # @immutable
    #------------------------------------------
    module MTuple
      include MRelation

      # @return [Array]
      def atoms()    fail "Must override" end
      def atom(idx)  atoms[idx] end

      def length()   arity end
      def arity()    atoms.length end
      def tuples()   [self] end
      def as_tuple() self end

      def each()     atoms.each { |t| yield t } end

      def tuple_product(rhs_tuple)
        self.product(rhs_tuple).tuples[0]
      end

      def ==(other)
        return false if other == nil
        return false if other.class != Tuple
        atoms == other.atoms
      end

      def eql?(other) self == other end
      def hash()      atoms.hash end
      def to_s()      atoms.to_s end
    end

    #------------------------------------------
    # == Class Tuple
    #
    # @immutable
    #------------------------------------------
    class Tuple
      include MTuple

      attr_reader :arr #TODO: rename to values

      def self.empty_tuple(arity)
        Tuple.new(arity, [])
      end

      # @param arity [Integer]
      # @param arr [Array, #collect]
      def initialize(arity, arr)
        raise ArityError, "nil tuple not allowed" if arr.nil?
        raise ArityError, "nil values not allowed in a tuple" if arr.include? nil
        raise ArityError, "arity mismatch: arity = #{arity}, arr.length = #{arr.length}" if arity != arr.length
        @arity = arity
        @arr = arr.collect {|e| e}
        @arr.freeze
        freeze
      end

      def atoms(); @arr end
    end

    #------------------------------------------
    # == Class Rel
    #
    # @immutable
    #------------------------------------------
    class Relation
      include MRelation

      def self.empty_rel(arity)
        Relation.new(arity, [])
      end

      # @param tuple_set [Enumerable(Tuple)]
      def initialize(arity, tuple_set)
        @arity = arity
        tset = Set.new
        tuple_set.each do |e|
          if e.arity != arity
            raise ArityError, "Arity mismatch: #{arity} != #{e.arity}"
          end
          tset.add(e)
        end
        @tuple_set = tset.to_a
        @tuple_set.freeze
        freeze
      end

      def arity()  @arity end
      def tuples() @tuple_set end
      def to_s()   @tuple_set.to_s end

      def == (other)
        return false if other == nil
        return false if other.class != Rel
        @tuple_set == other.tuple_set
      end

      def eql? (other)
        self == other
      end

      def hash
        @tuple_set.hash
      end
    end

  end
end
