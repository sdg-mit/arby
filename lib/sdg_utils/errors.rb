module SDGUtils
  module Errors

    class ErrorWithCause < StandardError
      def init(msg, backtrace)
        @msg = msg || ""
        @backtrace = backtrace || []
      end

      @@tab = "  "

      def initialize(cause_or_msg=nil)
        case cause_or_msg
        when NilClass
          @cause = nil
          @msg = nil
        when Exception
          @cause = cause_or_msg
          @msg = nil
        else
          @cause = nil
          @msg = cause_or_msg.to_s
        end
      end

      def self.inherited(subclass)
        subclass.instance_eval do
          def initialize(cause_or_msg=nil); super end
        end
      end

      def msg() @msg end
      def message() @msg || (@cause && @cause.message)end

      def exception(*args)
        case args.size
          when 1
            init(args[0], caller)
          when 2
            init(*args)
        end
        self
      end

      def to_s
        full_message
      end

      def full_message
        format_msg ""
      end

      def format_msg(indent)
        new_indent = (@msg.nil? || @msg.empty?) ? indent : indent + @@tab
        cause_msg = case @cause
                    when NilClass
                      ""
                    when ErrorWithCause
                      @cause.format_msg(new_indent)
                    when Exception
                      new_indent + "#{@cause.message} (#{@cause.class})"
                    else
                      new_indent + @cause.to_s
                    end
        "#{indent}#{@msg} (#{self.class})\n#{cause_msg}"
      end

      def backtrace
        full_backtrace
      end

      def cause_backtrace
        if @cause
          ["", "Caused by #{@cause.class}: #{@cause.message}"] +
          @cause.backtrace.map{|e| @@tab + e}
        else
          []
        end
      end

      def full_backtrace
        ret = ["#{self.class}"]
        ret += @backtrace || []
        ret += cause_backtrace
        ret
      end

    end

  end
end
