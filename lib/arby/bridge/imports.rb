require 'rjb'
require 'sdg_utils/errors'

module Arby
  module Bridge
    module Imports

      Rjb::load('vendor/alloy.jar', ['-Xmx1024m', '-Xms256m'])

      A4Reporter_RJB             = Rjb::import('edu.mit.csail.sdg.alloy4.A4Reporter')
      CompUtil_RJB               = Rjb::import('edu.mit.csail.sdg.alloy4compiler.parser.CompUtil')
      ConstList_RJB              = Rjb::import('edu.mit.csail.sdg.alloy4.ConstList')
      Err_RJB                    = Rjb::import('edu.mit.csail.sdg.alloy4.Err')
      ErrorAPI_RJB               = Rjb::import('edu.mit.csail.sdg.alloy4.ErrorAPI')
      SafeList_RJB               = Rjb::import('edu.mit.csail.sdg.alloy4.SafeList')
      Command_RJB                = Rjb::import('edu.mit.csail.sdg.alloy4compiler.ast.Command')
      SigField_RJB               = Rjb::import('edu.mit.csail.sdg.alloy4compiler.ast.Sig$Field')
      Parser_CompModule_RJB      = Rjb::import('edu.mit.csail.sdg.alloy4compiler.parser.CompModule')
      A4Options_RJB              = Rjb::import('edu.mit.csail.sdg.alloy4compiler.translator.A4Options')
      A4Solution_RJB             = Rjb::import('edu.mit.csail.sdg.alloy4compiler.translator.A4Solution')
      A4Tuple_RJB                = Rjb::import('edu.mit.csail.sdg.alloy4compiler.translator.A4Tuple')
      A4TupleSet_RJB             = Rjb::import('edu.mit.csail.sdg.alloy4compiler.translator.A4TupleSet')
      TranslateAlloyToKodkod_RJB = Rjb::import('edu.mit.csail.sdg.alloy4compiler.translator.TranslateAlloyToKodkod')

      str = Rjb::import('java.lang.String')
      out = Rjb::import('java.lang.System').out
      itr = Rjb::import('java.lang.Iterable')

      class AlloyError < SDGUtils::Errors::ErrorWithCause
        attr_reader :java_type, :java_message, :java_stack_trace
        def initialize(cause, java_type, java_message, java_stack_trace)
          super(cause)
          @java_type        = java_type
          @java_message     = java_message
          @java_stack_trace = java_stack_trace
        end

        def backtrace()
          cause_backtrace +
            ["", "Java exception:", "  #{@java_type}: #{@java_message}"] +
            @java_stack_trace.map{|s| "#{@@tab}#{@@tab}#{s}"}
        end
      end

      def java_stack_trace(a4ex)
        ans = a4ex.getStackTrace.map(&:toString)
        if a4ex.getCause
          ans << ""
          ans += java_stack_trace(a4ex.getCause)
        end
        ans
      end

      def catch_alloy_errors
        begin
          yield
        rescue Exception => ex
          raise AlloyError.new(ex, ex._classname, ex.getMessage, java_stack_trace(ex)),
            "An error occured while running Alloy"
        end
      end
    end
  end
end
