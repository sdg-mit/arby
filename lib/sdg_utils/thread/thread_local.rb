module SDGUtils
  module Thread

    # Include this module in your class to get thread local storage. 
    #
    # USES the folling INSTANCE VARIABLES
    #   @attr thread_locals [Hash(Integer, Hash)]
    module ThreadLocal

      def thread_local()  __thread_locals[::Thread.current.__id__] ||= {} end
      def thr(*args) 
        case 
        when args.size == 0; thread_local()
        when args.size == 1; thread_local()[args[0]]
        when args.size == 2; thread_local()[args[0]] = args[1]
        else raise ArgumentError, "too many arguments (#{args}); allowed num of args: 0..2"
        end
      end

      private

      def __thread_locals() @thread_locals ||= {} end
    end

  end
end
