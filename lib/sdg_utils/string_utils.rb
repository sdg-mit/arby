module SDGUtils
  module StringUtils
    extend self

    def to_iden(str)
      str.to_s.gsub(/[^a-zA-Z0-9_]/, "_")
    end
  end
end
