require 'logger'
require 'nilio'
require 'sdg_utils/config'

module Arby

  def self.default_symexe_conf
    SDGUtils::Config.new do |c|
      c.convert_missing_fields_to_joins = false
      c.convert_missing_methods_to_fun_calls = true
    end
  end

  def self.short_alloy_printer_conf
    SDGUtils::Config.new do |c|
      c.sig_namer = lambda{|sig|
        case sig
        when String, Symbol then sig.to_s
        when Class
          if sig < Arby::Ast::ASig
            if sig.meta.atom?
              c.atom_sig_namer[sig, sig.meta.atom_id]
            else
              c.prim_sig_namer[sig]
            end
          else
            sig.relative_name
          end
        else
          fail "unknown sig type: #{sig}:#{sig.class}"
        end
      }
      c.prim_sig_namer = lambda{|sig| sig.relative_name}
      c.atom_sig_namer = lambda{|sig, atom_id|
        sc = (Class === sig) ? sig.superclass : sig
        "PI__#{c.sig_namer[sc]}__#{atom_id}"}
      c.fun_namer = lambda{|fun| fun.name}
      c.arg_namer = lambda{|fld| fld.name}
    end
  end

  def self.full_alloy_printer_conf
    c = short_alloy_printer_conf
    c.prim_sig_namer = lambda{|sig| sig.name.gsub /:/, "_"}
    c.arg_namer = lambda{|fld|
      if Class === fld.owner && fld.owner.is_sig?
        "#{c.sig_namer[fld.owner]}__#{fld.name}"
      else
        fld.name
      end
    }
    c
  end

  def self.default_alloy_printer_conf
    full_alloy_printer_conf
    # short_alloy_printer_conf
  end

  # Options
  #   :inv_field_namer [Proc(fld)]
  #   :logger          [Logger]
  def self.default_conf
    SDGUtils::Config.new do |c|
      c.inv_field_namer                    = lambda { |fld| "inv_#{fld.name}" }
      c.turn_methods_into_funs             = true
      c.allow_undef_vars                   = true
      c.allow_undef_consts                 = true
      c.defer_body_eval                    = true
      c.detect_appended_facts              = true
      c.wrap_field_values                  = true
      c.generate_methods_for_global_fields = true
      c.typecheck                          = true
      c.sym_exe                            = default_symexe_conf
      c.logger                             = Logger.new(NilIO.instance)
      c.alloy_printer                      = default_alloy_printer_conf
    end
  end
end
