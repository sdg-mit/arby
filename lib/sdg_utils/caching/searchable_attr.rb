require 'sdg_utils/caching/cache'

module SDGUtils
  module Caching

    #TODO: generate methods in a separate module and then include that module
    module SearchableAttr
      module Static
        protected

        # Returns plural of the given noun by
        #  (1) replacing the trailing 'y' with 'ies', if `word'
        #      ends with 'y',
        #  (2) appending 'es', if `word' ends with 's'
        #  (3) appending 's', otherwise
        def pl(word)
          word = word.to_s
          if word[-1] == "y"
            word[0...-1] + "ies"
          elsif word[-1] == "s"
            word + "es"
          else
            word + "s"
          end
        end

        # Generates several methods for each symbol in `whats'.  For
        # example, if whats == [:sig] it generates:
        #
        # private
        # def _sigs()          _restrict(@sigs||=[]) end
        # def _sig_cache()     @sig_cache ||= Cache.new "sig", :fast => true end
        # def _sig_fnd_cache() @sig_fnd_cache ||= Cache.new "sig_find", :fast => true end
        #
        # public
        # def sigs()         _sigs end
        # def add_sig(obj)   _add_to(@sigs||=[], obj) end
        # def get_sig(key)   _sig_cache.fetch(key)     {_get_by(_sigs, key)} end
        # def find_sig(key)  _sig_fnd_cache.fetch(key) {_find_by(_sigs, key)} end
        # def get_sig!(key)  get_sig(name) || fail "sig `#{name}' not found" end
        #
        # alias_method :sig, :get_sig
        # alias_method :sig!, :get_sig!
        def attr_searchable(*whats)
          mod = Module.new
          whats.each do |what|
            self.instance_eval <<-RUBY, __FILE__, __LINE__+1
              (@searchable_attrs ||= []) << #{pl(what).to_sym.inspect}
            RUBY
            mod.send :module_eval, <<-RUBY, __FILE__, __LINE__+1
  private
  def _#{pl what}()      _restrict(@#{pl what} ||= []) end
  def _#{what}_cache()
    @#{what}_cache ||= SDGUtils::Caching::Cache.new "#{what}", :fast => true
  end
  def _#{what}_fnd_cache()
    @#{what}_fnd_cache ||= SDGUtils::Caching::Cache.new "#{what}_find", :fast => true
  end

  public
  def #{pl what}()       _#{pl what} end
  def add_#{what}(obj)   _add_to(@#{pl what}||=[], obj) end
  def get_#{what}(key)   _#{what}_cache.fetch(key)    { _get_by(_#{pl what}, key) } end
  def find_#{what}(key)  _#{what}_fnd_cache.fetch(key){ _find_by(_#{pl what}, key) } end
  def get_#{what}!(key)  get_#{what}(key) || fail("#{what} `\#{key}' not found") end

  alias_method :#{what}, :get_#{what}
  alias_method :#{what}!, :get_#{what}!
            RUBY
          end
          self.send :include, mod
        end

        # Generates several methods for each symbol in `whats'.  For
        # example, if whats == [:sig] it generates:
        #
        #   private
        #   def _sigs(own_only)   _fetch(own_only) { _restrict(@sigs ||= []) } end
        #   def _sig_cache()      @sig_cache ||= Cache.new "sig", :fast => true end
        #   def _sig_fnd_cache()  @sig_fnd_cache ||= Cache.new "sig_find", :fast => true end
        #
        #   public
        #   def sigs(own_only=true) _sigs(own_only) end
        #   def add_sig(obj)        _add_to(@sigs ||= [], obj) end
        #   def get_sig(key,own_only=false)
        #     _find(own_only) { _sig_cache.fetch(key) {_get_by(_sigs, key)} }
        #   end
        #   def find_sig(key)
        #     _find(own_only) { _sig_fnd_cache.fetch(key) {_find_by(_sigs, key)} }
        #   end
        #   def get_sig!(key)  get_sig(name) || fail "sig `#{name}' not found" end
        #
        #   alias_method :sig, :get_sig
        #   alias_method :sig!, :get_sig!
        def attr_hier_searchable(*whats)
          mod = Module.new
          whats.each do |what|
            self.instance_eval <<-RUBY, __FILE__, __LINE__+1
              (@searchable_attrs ||= []) << #{pl(what).to_sym.inspect}
            RUBY
            mod.send :module_eval, <<-RUBY, __FILE__, __LINE__+1
  protected
  def _#{pl what}(own_only=true) _fetch(own_only) { _restrict(@#{pl what} ||= []) } end
  def _#{what}_cache()
    @#{what}_cache ||= SDGUtils::Caching::Cache.new "#{what}", :fast => true
  end
  def _#{what}_fnd_cache()
    @#{what}_fnd_cache ||= SDGUtils::Caching::Cache.new "#{what}_find", :fast => true
  end

  public
  def #{pl what}(own_only=true)       _#{pl what}(own_only) end
  def add_#{what}(obj)                _add_to(@#{pl what} ||= [], obj) end
  def get_#{what}(key, own_only=false)
    _find(own_only) do
      _#{what}_cache.fetch(key) { _get_by(_#{pl what}, key) }
    end
  end
  def find_#{what}(key, own_only)
    _find(own_only) do
      _#{what}_fnd_cache.fetch(key){ _find_by(_#{pl what}, key) }
    end
  end

  def get_#{what}!(key, own_only=false)
    get_#{what}(key, own_only) || fail("#{what} `\#{key}' not found")
  end

  alias_method :#{what}, :get_#{what}
  alias_method :#{what}!, :get_#{what}!
            RUBY
          end
          self.send :include, mod
        end
      end

      # ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

      def self.included(base)
        base.extend(Static)
      end

      protected

      def init_searchable_attrs(cls=self.class)
        arr = cls.instance_variable_get("@searchable_attrs") || []
        arr.each do |attr|
          instance_variable_set "@#{attr}", []
        end
      end

      def _clear_caches(*whats)
        whats.each do |w|
          instance_variable_set "@#{w}_cache", nil
          instance_variable_set "@#{w}_fnd_cache", nil
        end
      end

      def _fetch(own_only, &block)
        ans = if !own_only && up = _hierarchy_up
                up._fetch(false, &block)
              else
                []
              end
        ans += self.instance_eval(&block)
      end

      def _find(own_only, &block)
        ans = if !own_only && up = _hierarchy_up
                up._find(false, &block)
              else
                nil
              end
        ans || self.instance_eval(&block)
      end

      def _hierarchy_up
        nil
      end

      def _restrict(src)
        return src
      end

      def _add_to(col, elem)
        col << elem
      end

      def _get_by(col, key)
        col.find {|e| e.name.to_s == key.to_s}
      end

      def _find_by(col, key)
        return nil unless key
        col.find {|e| e.name.to_s.end_with?(key.to_s)}
      end
    end

  end
end
