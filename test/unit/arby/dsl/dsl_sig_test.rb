require 'my_test_helper'
require 'arby/helpers/test/dsl_helpers'
require 'arby/helpers/test/dsl_sig_test_tmpl'

tmpl = Arby::Helpers::Test::DslSigTestTmpl.get_test_template('DslSigTest',
                                                              'Arby::Dsl::alloy_model',
                                                              'sig',
                                                              'Arby::Ast::Sig')
eval tmpl

