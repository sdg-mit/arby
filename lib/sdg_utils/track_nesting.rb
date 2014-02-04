module SDGUtils

  # Include this module in your class to get stack-based tracking of
  # nested calls.
  #
  # USES the folling INSTANCE VARIABLES
  #   @attr stack [Array]
  module TrackNesting

    def push_ctx(ctx) __stack.push ctx end
    def pop_ctx()     __stack.pop end
    def top_ctx()     __stack.last end
    def find_ctx(&b)  __stack.reverse_each.find(&b) end

    private

    def __stack() @stack ||= [] end
  end

end
