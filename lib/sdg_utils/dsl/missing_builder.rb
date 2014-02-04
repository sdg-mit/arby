require 'sdg_utils/dsl/base_builder'
require 'sdg_utils/proxy'

module SDGUtils
  module DSL

    # @attribute name [Symbol]               --- the original missing symbol
    # @attribute args [Array]                --- arguments (first invocation of :[])
    # @attribute ret_type [Object]           --- return type (second invocation of :[])
    # @attribute mods [Array(String, Array)] --- modifier name-value pairs
    # @attribute super [Object]              --- super type (set by the :< method)
    # @attribute body [Proc]                 --- block passed to :initialize
    class MissingBuilder < Proxy
      attr_reader :name, :args, :ret_type, :mods, :super, :body

      def initialize(name, &block)
        super(name)
        # puts "created: #{name}: has block: #{!!block}"
        @name = name
        @args = []
        @ret_type = nil
        @state = :init
        @body = block
        @mods = []
        @super = nil
        if BaseBuilder.in_builder?
          @dsl_builder = BaseBuilder.get
          @dsl_builder.register_missing_builder(self)
        end
      end

      def append(other_builder)
        @args      += other_builder.args
        @ret_type ||= other_builder._ret_type
        @body     ||= other_builder.body
        @super    ||= other_builder.super
        @mods      += other_builder.mods
      end

      def consume()
        if @dsl_builder
          @dsl_builder.unregister_missing_builder(self)
        end
      end

      def _ret_type()    @ret_type end
      def ret_type()     @ret_type || notype end

      def nameless?()    @name.nil? end
      def in_init?()     @state == :init end
      def in_args?()     @state == :args end
      def in_ret_type?() @state == :ret_type end
      def past_init?()   in_args? || in_ret_type? end
      def past_args?()   in_ret_type? end
      def has_body?()    !!@body end
      def remove_body()  b = @body; @body = nil; b end
      def super=(s)      self < s end
      def set_body(&block)
        msg = "Not allowed to change +MissingBuilder+'s body"
        ::Kernel.raise ::SDGUtils::DSL::SyntaxError, msg if has_body?
        @body = block
        self
      end

      # Appends a given name-value pair to the list of modifiers
      def add_modifier(mod_name, *value)
        if mod_name == :extends
          self.<(*value)
        else
          @mods << [mode_name, value]
        end
        self
      end

      # Sets the value of the @super attribute.  If another
      # +MissingBuilder+ is passed as an argument, it merges the
      # values of its attributes with attribute values in +self+.
      def <(super_thing)
        @super = super_thing
        if MissingBuilder === super_thing #&& super_thing.body
          @super = eval super_thing.name.to_s
          @args += super_thing.args
          @body = super_thing.body if super_thing.body
          super_thing.consume
        end
        self
      end

      # The first invocation expects a +Hash+ or an +Array+ and sets
      # the value of @args.  The second invocatin expets a singleton
      # array and sets the value of @ret_tupe.  Any subsequent
      # invocations raise +SDGUtils::DSL::SyntaxError+.
      def [](*args)
        case @state
        when :init
          @args += args
          @state = :args
        when :args
          msg = "can only specify 1 arg for return type"
          ::Kernel.raise ::SDGUtils::DSL::SyntaxError, msg unless args.size == 1
          @ret_type = args[0]
          @state = :ret_type
        else
          ::Kernel.raise ::SDGUtils::DSL::SyntaxError, "only two calls to [] allowed"
        end
        self
      end

      def |(*args)
        if args.size == 1 && args[0].is_a?(Array)
          self[*args[0]]
        else
          ::Kernel.raise ::SDGUtils::DSL::SyntaxError, "the | method takes one array"
        end
        self
      end

      def ==(other)
        if ::SDGUtils::DSL::MissingBuilder === other
          @name == other.name
        else
          @name == other
        end
      end

      def class()  ::SDGUtils::DSL::MissingBuilder end
      def hash()   @name.hash end
      def to_str() name.to_s end

      def to_s
        ans = name.to_s
        ans += "[#{args}]" if past_init?
        ans += "[#{ret_type}]" if past_args?
        ans += " <block>" if body
        ans
      end

      #--------------------------------------------------------
      # Returns the original missing symbol
      #--------------------------------------------------------
      def to_sym() @name end

      private

      # TODO: must not have refs to Arby
      def notype() @notype ||= ::Arby::Ast::NoType.new end
    end

  end
end
