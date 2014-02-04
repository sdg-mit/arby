require 'sdg_utils/dsl/missing_builder'

module Arby
  module Dsl

    module AbstractHelper

      def abstract(blder, &block)
        blder.apply_modifier("abstract", nil, &block)
      end

      def extends(super_thing, &block)
        mb = SDGUtils::DSL::MissingBuilder.new(nil, &block)
        mb.add_modifier(:extends, super_thing)
        mb
      end

    end

  end
end
