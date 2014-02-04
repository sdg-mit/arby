$LOAD_PATH.unshift File.expand_path('../..', __FILE__)
$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require 'logger'
require 'nilio'
require 'set'
require 'test/unit'
require 'pry'

require 'arby/arby'
require 'sdg_utils/testing/assertions'
require 'sdg_utils/testing/smart_setup'

Arby.set_default :logger => Logger.new(NilIO.instance) # Logger.new(STDOUT)
