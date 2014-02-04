require 'arby/arby'
require 'arby/arby_dsl'
require 'arby/ast/tuple_set'

include Arby::Dsl

module Arby
  module Helpers
    module Test

      module DslHelpers
        def sig_test_helper(sig_cls_str, supercls_str)
          sig_cls = nil
          supercls = nil
          assert_nothing_raised do
            sig_cls = eval "#{sig_cls_str}"
            supercls = eval "#{supercls_str}"
            #sig_cls.new
          end
          assert sig_cls < supercls, "#{sig_cls} not subclass of #{supercls}"
        end

        def assert_accessors_defined(sig_cls, fname)
          assert sig_cls.method_defined?(fname.to_sym),
                 "method `#{fname}' not defined in #{sig_cls}"
          assert sig_cls.method_defined?("#{fname}=".to_sym),
                 "method `#{fname}=' not defined in #{sig_cls}"
        end

        def assert_field_meta(sig_cls, fname)
          x = sig_cls.meta().field(fname)
          assert x, "Field #{fname} not found in class #{sig_cls}"
          assert_equal sig_cls, x.parent
          assert_equal fname, x.name
          assert x.type, "Field #{x} has no type"
          assert_equal false, x.synth
        end

        def assert_inv_field_meta(sig_cls, inv_fname)
          x = sig_cls.meta().inv_field(inv_fname)
          assert x, "Field #{inv_fname} not found in class #{sig_cls}"
          assert_equal sig_cls, x.parent
          assert_equal inv_fname, x.name
          assert x.type, "Field #{x} has no type"
          assert_equal true, x.synth
          assert x.inv, "Field #{x} has no inv"
        end

        def assert_field_access(sig_cls, fname)
          inst = sig_cls.new
          getter = inst.method(fname.to_sym)
          setter = inst.method("#{fname}=".to_sym)
          arity = sig_cls.meta.any_field(fname).type.arity
          val = (0...arity).map{|_| 42}
          Arby.conf.do_with(:typecheck => false) do
            setter.call([val])
            assert_equal Arby::Ast::TupleSet.wrap([val]), getter.call
          end
        end

        def fld_acc_helper(sig_cls, fld_arr)
          fld_arr.each {|f|
            assert_field_meta(sig_cls, f)
            assert_field_access(sig_cls, f)
            assert_accessors_defined(sig_cls, f)
          }
        end

        def inv_fld_acc_helper(sig_cls, fld_arr)
          fld_arr.each {|f|
            inv_fname = "inv_#{f}"
            assert_inv_field_meta(sig_cls, inv_fname)
            assert_field_access(sig_cls, inv_fname)
            assert_accessors_defined(sig_cls, inv_fname)
          }
        end

        def subsig_test_helper(sig_cls, subsig_arr)
          assert_equal subsig_arr.size, sig_cls.meta.subsigs.size
          subsig_arr.each do |ss|
            sig_cls.meta.subsigs.member? ss
          end
        end

        def assert_module_helper(mod, name)
          assert defined?(name), "new module not defined"
          assert_equal mod, (eval name.to_s)
          assert_equal Module, mod.class
        end

        def create_module(name)
          blder = Arby::Dsl::alloy_model(name)
          mod = blder.return_result(:array).first
          assert_module_helper(mod, name)
        end
      end

    end
  end
end
