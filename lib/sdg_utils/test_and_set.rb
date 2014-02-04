module TestAndSet

  def test_and_set(sym)
    fldname = '@' + sym.to_s
    if instance_variable_get(fldname)
      false
    else
      instance_variable_set(fldname, true)
      true
    end
  end

end
