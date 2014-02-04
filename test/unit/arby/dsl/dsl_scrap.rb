require 'unit/alloy/arby_test_helper.rb'

alloy_module "Users" do
  sig SigB do
    persistent {{
      x: SigB
    }}

    transient {{
      sel: Bool
    }}
  end

end

puts Users::SigB.meta.fields

#
# puts Users::SigA.to_alloy
# puts Users::SigB.to_alloy
#
# puts Users::SigA.instance_variables.inspect
# puts Users::SigB.instance_variables.inspect
#
# x = Users::SigA.new
# x.f0 = 3
# puts x.f0

