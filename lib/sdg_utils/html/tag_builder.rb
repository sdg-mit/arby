module SDGUtils
  module HTML

    class TagBuilder
      attr_reader :tag_name

      def initialize(tag_name)
        @tag_name = tag_name
        @attrs = {}
      end

      def body(body_text)
        get_body().concat(body_text.to_s)
        self
      end

      def attr(name, value)
        get_attr(name).concat(" " + value.to_s)
        self
      end

      def attrs(hash)
        hash.each{|k,v| attr(k,v)}
        self
      end

      def when(condition, action_sym, *args)
        send action_sym, *args if condition
        self
      end

      def build(escape_body=true)
        attrs_str = @attrs.map{ |key, val|
          val = val.strip
          (val.empty?) ? nil : "#{esc(key)}=#{val.inspect}"
        }.compact.join(" ")
        if get_body().empty?
          "<#{tag_name} #{attrs_str}/>"
        else
          body_text = escape_body ? esc(get_body) : get_body
          "<#{tag_name} #{attrs_str}>#{body_text}</#{tag_name}>"
        end
      end

      def esc(str)
        require 'cgi'
        CGI::escapeHTML(str)
      end

      def get_body() @body ||= "" end
      def get_attr(attr) @attrs[attr.to_s] ||= "" end
    end

  end
end
