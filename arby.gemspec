require 'rubygems'

Gem::Specification.new do |s|
  s.name = "arby"
  s.author = "Aleksandar Milicevic"
  s.email = "aleks@csail.mit.edu"
  s.version = "0.0.1"
  s.summary = "Aolloy DSL embedded in Ruby"
  s.description = "Embedding of the Alloy modeling language into Ruby"
  s.files = Dir['lib/**/*.rb']
  s.require_paths = ["lib"]
  s.test_files = Dir['test/**/*test.rb']

  s.add_runtime_dependency "nilio"
  s.add_runtime_dependency "parser", ["~>2.0.0.pre7"]
end
