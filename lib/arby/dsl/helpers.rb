require 'arby/dsl/abstract_helper'
require 'arby/dsl/expr_helper'
require 'arby/dsl/fun_helper'
require 'arby/dsl/mult_helper'
require 'arby/dsl/quant_helper'

module Arby
  module Dsl

    module StaticHelpers
      include MultHelper
      extend self
    end

    module InstanceHelpers
      include ExprHelper
      #TODO: doesn't work for ActiveRecord::Relation
      # require 'arby/relations/relation_ext.rb'
      # def no(col)   col.as_rel.no? end
      # def some(col) col.as_rel.some? end
      # def one(col)  col.as_rel.one? end
      # def lone(col) col.as_rel.lone? end
    end

  end
end
