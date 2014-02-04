require_relative 'relation.rb'

class Object
  def as_tuple
    Arby::Relations::Tuple.new(1, [self])
  end

  def as_rel
    Arby::Relations::Relation.new(1, [self.as_tuple])
  end
end

class NilClass
  def as_tuple
    Arby::Relations::Tuple.empty_tuple(1)
  end

  def as_rel
    Arby::Relations::Relation::empty_rel(1)
  end
end

class Array
  def as_rel_with_index
    return nil.as_rel if empty?

    each_with_index.map do |e, idx|
      idx.as_tuple.tuple_product(e.as_tuple)
    end.tuple_set_to_rel
  end

  def tuple_set_to_rel
    return nil.as_rel if empty?
    arity = first.arity
    Arby::Relations::Relation.new(arity, self)
  end
end

module Enumerable
  def empty_as_tuple
    nil.as_tuple
  end

  def empty_as_rel
    nil.as_rel
  end

  def as_tuple
    return empty_as_tuple if empty?

    inject(nil) do |acc, e|
      if acc == nil
        e.as_tuple
      else
        acc.tuple_product(e.as_tuple)
      end
    end
  end

  def as_rel
    return empty_as_rel if empty?
    map {|e| e.as_tuple}.tuple_set_to_rel
  end
end

class Hash
  def empty_as_tuple() Arby::Relations::Tuple.empty_tuple(2) end
  def empty_as_rel() Arby::Relations::Relation.empty_rel(2) end

  def as_tuple
    msg = "Hash with more than 1 entry cannot be converted to tuple"
    raise Arby::Relations::ArityError, msg if size > 1
    super
  end
end
