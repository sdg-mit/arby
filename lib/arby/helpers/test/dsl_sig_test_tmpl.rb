module Arby
  module Helpers
    module Test

      module DslSigTestTmpl
        extend self
        def get_test_template(cls_name, model_func, sig_func, base_sig_cls)
          <<-EOM
    require 'arby/helpers/test/dsl_helpers'
    require 'sdg_utils/meta_utils.rb'

    #{model_func} do
      #{sig_func} S_#{cls_name}
      #{sig_func} :S_sym_#{cls_name}
      #{sig_func} :S_ext_#{cls_name} < S_#{cls_name}
    end

    #{model_func} "X_#{cls_name}" do
      #{sig_func} S_#{cls_name}
      #{sig_func} :S_sym_#{cls_name}
      #{sig_func} :S_ext_#{cls_name} < S_#{cls_name}
    end

    module M_#{cls_name}
      #{model_func} do
      #{sig_func} S_#{cls_name}
      #{sig_func} :S_sym_#{cls_name}
      #{sig_func} :S_ext_#{cls_name} < S_#{cls_name}
    end

    #{model_func} "X_#{cls_name}" do
      #{sig_func} S_#{cls_name}
      #{sig_func} :S_sym_#{cls_name}
      #{sig_func} :S_ext_#{cls_name} < S_#{cls_name}
    end

    module N_#{cls_name}
      #{model_func} do
      #{sig_func} S_#{cls_name}
      #{sig_func} :S_sym_#{cls_name}
      #{sig_func} :S_ext_#{cls_name} < S_#{cls_name}
    end

    #{model_func} "X_#{cls_name}" do
      #{sig_func} S_#{cls_name}
      #{sig_func} :S_sym_#{cls_name}
      #{sig_func} :S_ext_#{cls_name} < S_#{cls_name}
    end
      end
    end

    class #{cls_name} < Test::Unit::TestCase
      include Arby::Helpers::Test::DslHelpers

      def test_sig_inner1
        #{model_func} do
          #{sig_func} Inner_#{cls_name}
        end
        sig_test_helper('Inner_#{cls_name}', #{base_sig_cls})
      end

      def test_sig_inner2
        #{model_func} "I_#{cls_name}" do
          #{sig_func} Inner_#{cls_name}
        end
        sig_test_helper('I_#{cls_name}::Inner_#{cls_name}', #{base_sig_cls})
      end

      def test_create_sig_global
        sig_test_helper('S_#{cls_name}', #{base_sig_cls})
        sig_test_helper('S_sym_#{cls_name}', #{base_sig_cls})
        sig_test_helper('S_ext_#{cls_name}', S_#{cls_name})
      end

      def test_create_sig_module
        sig_test_helper('X_#{cls_name}::S_#{cls_name}', #{base_sig_cls})
        sig_test_helper('X_#{cls_name}::S_sym_#{cls_name}', #{base_sig_cls})
        sig_test_helper('X_#{cls_name}::S_ext_#{cls_name}', X_#{cls_name}::S_#{cls_name})
      end

      def test_create_sig_nested_module
        sig_test_helper('M_#{cls_name}::S_#{cls_name}', #{base_sig_cls})
        sig_test_helper('M_#{cls_name}::S_sym_#{cls_name}', #{base_sig_cls})
        sig_test_helper('M_#{cls_name}::S_ext_#{cls_name}', M_#{cls_name}::S_#{cls_name})
      end

      def test_create_sig_nested_module2
        sig_test_helper('M_#{cls_name}::X_#{cls_name}::S_#{cls_name}', #{base_sig_cls})
        sig_test_helper('M_#{cls_name}::X_#{cls_name}::S_sym_#{cls_name}', #{base_sig_cls})
        sig_test_helper('M_#{cls_name}::X_#{cls_name}::S_ext_#{cls_name}', M_#{cls_name}::X_#{cls_name}::S_#{cls_name})
      end

      def test_create_sig_nested_module3
        sig_test_helper('M_#{cls_name}::N_#{cls_name}::X_#{cls_name}::S_#{cls_name}', #{base_sig_cls})
        sig_test_helper('M_#{cls_name}::N_#{cls_name}::X_#{cls_name}::S_sym_#{cls_name}', #{base_sig_cls})
        sig_test_helper('M_#{cls_name}::N_#{cls_name}::X_#{cls_name}::S_ext_#{cls_name}', M_#{cls_name}::N_#{cls_name}::X_#{cls_name}::S_#{cls_name})
      end

      def test_no_override1
        assert_raise(NameError) do
          #{model_func} do
            #{sig_func} S_#{cls_name}
          end
        end
        assert_raise(NameError) do
          #{model_func} do
            #{sig_func} :S_sym_#{cls_name}
          end
        end
      end

      def test_no_override2
        assert_raise(NameError) do
          #{model_func} "X_#{cls_name}" do
            #{sig_func} S_#{cls_name}
          end
        end
        assert_raise(NameError) do
          #{model_func} "X_#{cls_name}" do
            #{sig_func} :S_sym_#{cls_name}
          end
        end
      end

      def test_empty_name
        assert_raise(ArgumentError) do
          #{model_func} "X_#{cls_name}" do
            #{sig_func} nil
          end
        end
        assert_raise(NameError) do
          #{model_func} "X_#{cls_name}" do
            #{sig_func} ""
          end
        end
      end

      def test_invalid_name
        assert_raise(NameError) do
          #{model_func} "X_#{cls_name}" do
            #{sig_func} "   "
          end
        end
        assert_raise(NameError) do
          #{model_func} "X_#{cls_name}" do
            #{sig_func} :x
          end
        end
      end

      def test_base_sig_ok
        assert_nothing_raised do
          #{model_func} do
            #{sig_func} X1_#{cls_name} < S_#{cls_name}
            #{sig_func} X2_#{cls_name} < X_#{cls_name}::S_#{cls_name}
            #{sig_func} X3_#{cls_name} < M_#{cls_name}::X_#{cls_name}::S_#{cls_name}
          end
        end
      end

      def test_base_sig_not_sig1
        assert_raise(ArgumentError) do
          #{model_func} do; #{sig_func} X4_#{cls_name} < String end
        end
      end

      def test_base_sig_not_sig2
        assert_raise(ArgumentError) do
          #{model_func} do; #{sig_func} X5_#{cls_name} < Arby::Ast::SigMeta end
        end
      end

      def test_base_sig_not_class
        assert_raise(ArgumentError) do
          #{model_func} do; #{sig_func} X6_#{cls_name} < "KJdf" end
        end
        assert_raise(ArgumentError) do
          #{model_func} do; #{sig_func} X7_#{cls_name} < 1 end
        end
        assert_raise(ArgumentError) do
          #{model_func} do; #{sig_func} X8_#{cls_name} < :X8 end
        end
      end
    end
  EOM
end

      end

    end
  end
end
