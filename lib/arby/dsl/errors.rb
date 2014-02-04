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
      def class
        Arby::Dsl::SyntaxError
      end
    end
  end
end
