module SDGUtils

  module MDelegator
    # #TODO def respond_to?

    def respond_to?(*a)
      super(*a) || (@target && @target.respond_to?(*a))
    end

    def method_missing(name, *args, &block)
      # return super unless @target
      begin
        # let the super method_missing run first (if defined)
        super
      rescue ::NameError
        handler = ::Proc.new do |*a, &b|
          obj = @target
          obj = @target.call() if ::Proc === @target && @target.arity == 0
          obj.send(name, *a, &b)
        end
        cls = class << self; self end
        cls.send :define_method, name, handler unless cls.frozen?
        handler.call(*args, &block)
      end
    end
  end

  module MNested
    include MDelegator

    def self.included(base)
      parent = begin
                 parent_name = base.name.split('::')[0...-1].join('::')
                 (parent_name.empty?) ? "Object" : parent_name
               rescue
                 "Object"
               end
      base.class_eval <<-RUBY, __FILE__, __LINE__+1
        class << self
          def __parent() #{parent} end

          private
          def new(*a, &b) super end
        end
        private
        def __parent=(parent) @target = parent end
        def __parent()        @target end
      RUBY
    end
  end

  module MNestedParent
    def new(nested_cls, *args, &block)
      obj = nested_cls.send :new, *args, &block
      obj.send :__parent=, self
      obj
    end

    def allocate(nested_cls)
      obj = nested_cls.send :allocate
      obj.send :__parent=, self
      obj
    end
  end

  class Delegator
    include MDelegator

    def initialize(obj)
      @target = obj
    end
  end

end
