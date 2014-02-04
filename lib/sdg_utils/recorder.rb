require 'sdg_utils/io'
require 'sdg_utils/delegator'

module SDGUtils

  class MethodRecorder < BasicObject
    def initialize(target, &block)
      @target = target
      @cb = block || Proc.new {|x|}
    end

    def method_missing(name, *args, &block)
      if name == :send
        return method_missing(*args, &block)
      end
      #TODO: what about args?
      m = @target.send :define_method, name, &block
      @cb.call(name, m)
      nil
    end
  end

  class Recorder < BasicObject
    TAB = "  "

    attr_reader :var

    def initialize(hash={})
      @buffer     = hash[:buffer]     || ""
      @indent     = hash[:indent]     || ""
      @var        = hash[:var]        || ""
      @block_var  = hash[:block_var]  || "x"
      @block_vars = hash[:block_vars] || []
      @trace      = []
      @no_trace   = hash[:no_trace]; @no_trace = true if @no_trace.nil?
      @no_buffer  = hash[:no_buffer]  || false
    end

    def __print(obj)
      @buffer << obj.to_s
    end

    def __newline
      __print "\n"
    end

    def method_missing(name, *args, &block)
      if name == :send
        return method_missing(*args, &block)
      end
      unless @no_trace
        @trace << { :name => name, :args => args, :block => block }
      end
      unless @no_buffer
        argstr = args.map(&:inspect).join(", ")
        buff = ""
        buff << @indent
        buff << (@var.empty? ? '' : "#{@var}.") << name.to_s << " #{argstr}"
        if block
          buff << " do "
          if block.arity == 0
            buff << "\n"
            r = Recorder.new :buffer => buff,
                             :indent => @indent + TAB,
                             :var    => "",
                             :block_var => @var
            r.instance_eval(block)
          else
            block_args = block.arity.times.each_with_index.map do |x, idx|
              bv = block.arity == 1 ? @block_var : "#{@block_var}#{x}"
              if @block_vars.size == block.arity
                bv = @block_vars[idx]
              end
              Recorder.new :buffer => buff,
                           :indent => @indent + TAB,
                           :var    => "#{bv}",
                           :block_var => "#{@block_var}_@{block_var}"
            end
            buff << "|" << block_args.map(&:var).join(", ") << "|\n"
            block.call(*block_args)
          end
          buff << @indent << "end"
        end
        buff << "\n"
        @buffer << buff
      end
    end

    def __buffer
      @buffer
    end

    def to_s
      @buffer.clone rescue ""
    end
  end

  class LoggerRecorder < Recorder
    def initialize(logger, hash={})
      super(hash)
      @buffer = ::SDGUtils::IO::LoggerIO.new(logger)
    end
  end

  class RecorderDelegator
    def initialize(obj, hash={})
      __update_receiver(obj, hash)
    end

    def method_missing(name, *args, &block)
      unless @target; return end
      @recorder.method_missing(name, *args, &block)
      @target.send(name, *args, &block)
    end

    def __print(obj)
      @recorder.__print(obj) rescue false
    end

    def __update_receiver(obj, hash={})
      unless obj; return end
      @target = obj
      opts = hash.clone
      opts[:var] ||= obj.to_s
      if @recorder
        opts[:buffer] ||= @recorder.__buffer
      end
      @recorder = opts[:recorder] || Recorder.new(opts)
      self
    end

    def __recorded_str
      @recorder.to_s
    end

  end


end
