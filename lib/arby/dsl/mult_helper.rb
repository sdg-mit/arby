require 'arby/dsl/mod_builder'

module Arby
  module Dsl

    # ================================================================
    # == Module +Mult+
    #
    # Methods for constructing expressions.
    # ================================================================
    module MultHelper
      extend self
      # def lone(*sig, &blk) ModBuilder.mult(:lone, *sig, &blk) end
      # def one(*sig, &blk)  ModBuilder.mult(:one, *sig, &blk) end
      # def set(*sig, &blk)  ModBuilder.mult(:set, *sig, &blk) end
      # def seq(*sig, &blk)  ModBuilder.mult(:seq, *sig, &blk) end

      [:lone, :one, :set, :seq].each do |mod_rhs|
        class_eval <<-RUBY, __FILE__, __LINE__+1
          def #{mod_rhs}(*a, &b)
            ModBuilder.mult(#{mod_rhs.inspect}, *a, &b)
          end
        RUBY
        [:lone, :one, :set, :seq].each do |mod_lhs|
          class_eval <<-RUBY, __FILE__, __LINE__+1
            def #{mod_lhs}_#{mod_rhs}(*a, &b)
              lhs = ModBuilder.mult(#{mod_rhs.inspect})
              rhs = ModBuilder.mult(#{mod_rhs.inspect}, *a, &b)
              lhs ** rhs
            end
          RUBY
        end
      end
    end

  end
end
