require 'set'

module SDGUtils

  # ====================================================
  # Class +Config+
  # ====================================================
  class Config
    include Enumerable

    def initialize(*args, &block)
      @init_mode = true
      begin
        case
        when args.size == 2; _init(args[0], args[1])
        when args.size == 1;
          if SDGUtils::Config === args[0]
            _init(args[0], {})
          else
            _init(nil, args[0])
          end
        when args.size == 0; _init(nil)
        else
          msg = "Wrong number of arguments. Expected 0, 1 or 2, got #{args.size}"
          raise ArgumentError msg
        end
        block.call(self) if block
      ensure
        @init_mode = false
      end
    end

    def extend(hash={}, &block)
      SDGUtils::Config.new(self, hash, &block)
    end

    def parent_config()
      @parent_config
    end

    def do_with(hash)
      @old_opts = @opts
      @opts = @opts.merge(hash)
      yield
    ensure
      @opts = @old_opts
    end

    def _init(parent_config, defaults={})
      @parent_config = parent_config
      @opts = {}
      defaults.each {|k,v| self[k] = v }

      # generate getter methods for each available option
      keys.each {|k| define_accessor_methods(k)}
    end

    def [](key)
      myk = mykey?(key)
      if myk
        get_my_property(key)
      elsif @parent_config
        @parent_config[key]
      else
        nil
      end
    end

    def []=(key, value)
      set_my_property(key, value)
    end

    def get_my_property(key)
      ret = @opts[key]
      if !key.to_s.end_with?("_proc") && ret.kind_of?(Proc) && ret.arity == 0
        ret = ret.call
      end
      ret
    end

    def set_my_property(key, value)
      @opts[key] = value
    end

    def keys
      s = Set.new
      s += _parent_keys
      s += @opts.keys
      s.to_a
    end

    def mykey?(key) @opts.key?(key) end
    def key?(key)   mykey?(key) || (@parent_config && @parent_config.key?(key)) end
    alias_method :has_key?, :key?
    alias_method :include?, :key?
    alias_method :member?, :key?

    def merge!(hash)
      hash.each {|k,v| self[k] = v }
    end

    def each
      @opts.each {|k,v| yield k, v}
      @parent_config.each {|k,v| yield k, v} if @parent_config
    end

    def freeze
      super
      @opts.freeze
    end

    def dup
      Config.new @parent_config, @opts
    end

    def define_accessor_methods(sym)
      define_singleton_method(sym, lambda{self[sym]}) rescue nil
      syms = "#{sym}=".to_sym
      define_singleton_method(syms, lambda{|val| self[sym] = val}) rescue nil
    end

    def method_missing(name, *args, &block)
      super unless @init_mode
      sym = name.to_s.end_with?("=") ? name.to_s[0..-2].to_sym : name
      define_accessor_methods(sym)
      send name, *args, &block
    end

    def _parent_keys
      @parent_config ? @parent_config.keys : []
    end
  end

  # ====================================================
  # Class +PushConfig+
  #
  # Pushes changes up the parent chain.
  # ====================================================
  class PushConfig < Config
    def initialize(*args)
      super
    end

    def [](key)
      if @parent_config && @parent_config.key?(key)
        @parent_config[key]
      else
        get_my_property(key)
      end
    end

    def []=(key, value)
      if @parent_config && @parent_config.key?(key)
        @parent_config[key] = value
      else
        set_my_property(key, value)
      end
    end
  end
end
