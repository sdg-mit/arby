require 'sdg_utils/errors'
require 'sdg_utils/dsl/syntax_error'

module Arby
  module Dsl

    class SyntaxError < SDGUtils::Errors::ErrorWithCause
    end

  end
end

module SDGUtils
  module DSL
    class SyntaxError
      def self.new(*args)       Arby::Dsl::SyntaxError.new(*args) end
      def self.exception(*args) Arby::Dsl::SyntaxError.exception(*args) end

      def class
        Arby::Dsl::SyntaxError
      end
    end
  end
end
