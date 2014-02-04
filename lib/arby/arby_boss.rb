require 'sdg_utils/event/events'

module Arby

  class BigBoss
    include SDGUtils::Events::EventProvider

    def side_effects()       @side_effects ||= [] end
    def add_side_effect(e)   side_effects << e end
    def clear_side_effects() x = @side_effects; @side_effects = []; x end
  end

end
