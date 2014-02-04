module SDGUtils
  module Random
    extend self

    def integer_salt(salt_digits=4)
      ::Random.rand((10**(salt_digits-1))..(10**salt_digits - 1))
    end

    def salted_timestamp(fmt="%s_%s", time_fmt="%s_%L", salt_digits=4)
      time = Time.now.utc.strftime(time_fmt)
      salt = integer_salt(salt_digits)
      fmt % [time, salt]
    end

  end
end
