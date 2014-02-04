require 'sdg_utils/delegator'
require 'sdg_utils/random'

module SDGUtils

  class Proxy
    instance_methods.each { |m| undef_method m unless m =~ /(^__|^send$|^object_id$)/ }

    include SDGUtils::MDelegator

    def initialize(obj)
      @target = obj
    end
  end

  class AroundProxy < Proxy
    def initialize(*args, &block)
      @around_block = block
      super(*args)
    end

    def method_missing(name, *args, &block)
      @around_block.call(name, args, block, ::Proc.new{
        _get_handler(name).call(*args, &block)
      })
    end
  end

  module MethodInstrumenter
    extend self

    def self.expand(method, default_impl)
      %w(lambda send direct_call).each do |impl|
      self.class_eval <<-RUBY, __FILE__, __LINE__+1
def #{method}_#{impl}(obj, name_pattern=/.*/, cb_obj=nil, &block)
  __#{method}(__#{impl}_opts, obj, name_pattern, cb_obj, &block)
end
RUBY
      end
      alias_method method.to_sym, "#{method}_#{default_impl}".to_sym
    end

    expand :around, :lambda
    expand :before, :lambda
    expand :after, :lambda

    private

    def __save_cb(bndg)
      nil
    end

    def __around(opts, obj, name_pattern=/.*/, cb_obj=nil, &block)
      alias_sym_proc     = opts[:alias_sym] || lambda{|bndg|
        m, rand = bndg.eval '[m, rand]'
        "#{m}__#{rand}__".to_sym
      }
      define_method_proc = opts[:define_method]
      pre_proc           = opts[:pre] || lambda{|bndg|}
      post_proc          = opts[:post] || lambda{|bndg|}
      fail "no define_method_proc given" unless define_method_proc

      store = {}
      cls = class << obj; self end
      cb = cb_obj || block
      rand = SDGUtils::Random.salted_timestamp
      fail "no callback given" unless cb

      mthds = cls.instance_methods.reject{|m|
        /(^__|^send$|^object_id$)/ === m
      }.grep(name_pattern)

      pre_proc.call(binding)
      mthds.each{|m|
        alias_sym = alias_sym_proc.call(binding)
        cls.send :alias_method, alias_sym, m
        define_method_proc.call(binding)
      }
      post_proc.call(binding)
    end

    def __before(opts, obj, name_pattern=/.*/, cb_obj=nil, &before_cb)
      cb = cb_obj || before_cb
      fail "no callback given" unless cb
      __around(opts, obj, name_pattern) do |name, args, block, &yield_cb|
        cb.call(name, args, block)
        yield_cb.call
      end
    end

    def __after(opts, obj, name_pattern=/.*/, cb_obj=nil, &after_cb)
      cb = cb_obj || after_cb
      fail "no callback given" unless cb
      __around(opts, obj, name_pattern) do |name, args, block, &yield_cb|
        ans = yield_cb.call
        cb.call(name, args, block, ans)
        ans
      end
    end

    def __lambda_opts
      {
        :define_method => lambda{|bndg|
          cls, rand, cb, m, alias_sym = bndg.eval "[cls, rand, cb, m, alias_sym]"
          cls.send :define_method, m, lambda{|*a, &b|
            cb.call(m, a, b) {
              self.send alias_sym, *a, &b
            }
          }
        }
      }
    end

    def __send_opts
      {
        :pre => lambda{|bndg|
          obj, cls, cb, rand = bndg.eval '[obj, cls, cb, rand]'
          cb_var = "cb__#{rand}"
          obj.instance_variable_set "@#{cb_var}", cb
          cls.send :attr_reader, cb_var.to_sym
          bndg.eval "store[:cb_var] = #{cb_var.inspect}"
        },
        :define_method => lambda{|bndg|
          cls, cb_var, m, alias_sym = bndg.eval "[cls, store[:cb_var], m, alias_sym]"
          cls.class_eval <<-RUBY, __FILE__, __LINE__+1
def #{m}(*args, &block)
  #{cb_var}.call(#{m.inspect}, args, block) {
    self.send #{alias_sym.inspect}, *args, &block
  }
end
RUBY
        }
      }
    end

    def __direct_call_opts
      {
        :pre => __send_opts[:pre],
        :alias_sym => lambda{|bndg|
          m, rand = bndg.eval '[m, rand]'
          "__#{m.hash.abs}__#{rand}__".to_sym
        },
        :define_method => lambda{|bndg|
          cls, cb_var, m, alias_sym = bndg.eval "[cls, store[:cb_var], m, alias_sym]"
          cls.class_eval <<-RUBY, __FILE__, __LINE__+1
def #{m}(*args, &block)
  @#{cb_var}.call(#{m.inspect}, args, block) {
    #{alias_sym}(*args, &block)
  }
end
RUBY
        }
      }
    end

  end

end
