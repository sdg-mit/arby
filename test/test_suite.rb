#TODO: add configuration options
# - pattern
# - folder
# - individual files

Dir[File.join(File.dirname(__FILE__), "{**/*test.rb}")].each do |d|
  puts d
  require d
end
