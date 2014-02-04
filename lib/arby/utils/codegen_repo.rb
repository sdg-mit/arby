require 'ostruct'
require 'sdg_utils/lambda/sourcerer'
require 'sdg_utils/random'

module Arby
module Utils

  module CodegenRepo
    class << self

      @@loc_to_src = {}

      @@gen_code = []
      def gen_code() @@gen_code end

      def for_target(target)
        @@gen_code.select{|e|
          e.target == target || e.desc.target == target
        }
      end

      def for_kind(kind)
        @@gen_code.select{|e|
          e.kind == kind || e.desc.kind == kind
        }
      end

      def get_code_for_target(target) for_target(target).map(&:code) end
      def get_code_for_kind(kind)     for_kind(kind).map(&:code) end

      # @param location [String] e.g., file name
      def source_for_location(location)
        @@loc_to_src[location]
      end

      def proc_to_src(proc)
        src_loc = proc.source_location rescue nil
        return nil unless src_loc
        source = source_for_location(src_loc[0])
        SDGUtils::Lambda::Sourcerer.proc_to_src(source || proc)
      end

      # --------------------------------------------------------------
      #
      # Evaluates a source code block (`src') in the context of a
      # module (`mod'), and remembers it for future reference.
      #
      # @param mod [Class]  - module to add code to
      # @param src [String]  - source code to be evaluated for module
      #                        `mod'
      # @param file [String] - optional file name of the source
      # @param line [String] - optional line number in the source file
      #                        source code
      # @param desc [Hash]   - arbitrary hash to be stored alongside
      #
      # --------------------------------------------------------------
      def class_eval_code(cls, src, file=nil, line=nil, desc={})
        eval_code_using(cls, src, :class_eval, file, line, desc)
      end

      alias_method :eval_code, :class_eval_code

      def module_eval_code(mod, src, file=nil, line=nil, desc={})
        eval_code_using(mod, src, :module_eval, file, line, desc)
      end

      def module_safe_eval_method(mod, meth, src, file=nil, line=nil, desc={})
        unless mod.methods.member? meth.to_sym
          module_eval_code(mod, src, file=nil, line=nil, desc={})
        end
      end

      # --------------------------------------------------------------
      #
      # Evaluates a source code block (`src') in the context of a
      # module (`mod'), and remembers it for future reference.
      #
      # @param code [String]   - arbitrary code
      # @param target [Object] - optional target
      # @param desc [Hash]     - arbitrary hash to be stored alongside
      #
      # --------------------------------------------------------------
      def record_code(code, target=nil, desc={})
        __append :kind => :code, :target => target, :code => code, :desc => desc
      end

      private

      def eval_code_using(mod, src, eval_meth, file=nil, line=nil, desc={})
        # Red.conf.log.debug "------------------------- in #{mod}"
        # Red.conf.log.debug src
        __append :kind => :eval_code, :target => mod, :code => src, :desc => desc
        if file.nil? && line.nil?
          file = "<synthesized__#{SDGUtils::Random.salted_timestamp}>"
          line = 1
          @@loc_to_src[file] = src
        end
        args = [file, line].compact
        mod.send eval_meth, src, *args
      end


      def __append(hash)
        hash[:desc] = OpenStruct.new(hash[:desc])
        @@gen_code << OpenStruct.new(hash)
      end

    end
  end

end
end
