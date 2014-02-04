module SDGUtils
  module Assertions

    extend self

    class AssertionError < StandardError
    end

    def assert(check, msg="")
      unless check
        raise AssertionError, msg
      end
    end

  end
end
