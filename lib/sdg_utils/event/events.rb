module SDGUtils
  module Events

    module EventHandler
      def call(event, params)
        sym = "handle_#{event.to_s}".to_sym
        if self.respond_to? sym
          self.send sym, params
        elsif self.respond_to? :handler_missing
          self.send :handler_missing, event, params
        end
      end
    end

    module EventProvider
      def clear_listeners
        @event_listeners = {}
      end

      def event_listeners
        @event_listeners || []
      end

      # @param listener [Object#call]
      # @param block [Proc]
      def register_listener(events, listener=nil, &block)
        fail "No callback provided" if listener.nil? && block.nil?
        fail "Can't provide both listener and block" if listener && block
        l = listener || block
        fail "Listener #{l} does not respond to #call" unless l.respond_to?(:call)
        case events
        when Array
          events.each {|event|
            _reg(event, l)
          }
        else
          _reg(events, l)
        end
      end

      # @param event [Object#to_sym]
      # @param listener [Object]
      # @return [Boolean]
      def unregister_listener(events, listener)
        case events
        when Array
          events.reduce(true) {|acc, event| acc && _unreg(event, listener)}
        else
          !!_unreg(events, listener)
        end
      end

      # @param event [Object#to_sym]
      # @param args [Hash]
      def fire(event, args)
        _get_listeners_for(event).each { |l| l.call(event, args) }
      end

      protected

      # @param event [Object#to_sym]
      # @param listener [Object#call]
      def _reg(event, listener)
        _get_listeners_for(event) << listener
      end

      def _unreg(event, listener)
        _get_listeners_for(event).delete(listener)
      end

      # @param event [Object#to_sym]
      def _get_listeners_for(event)
        _get_listeners[event.to_sym] ||= []
      end

      def _get_listeners
        @event_listeners ||= {}
      end

    end

  end
end
