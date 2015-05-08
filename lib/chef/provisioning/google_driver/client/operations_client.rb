require_relative 'google_base'

class Chef
module Provisioning
module GoogleDriver
module Client
  class Operations < GoogleBase

    def get(id)
      make_request(
        compute.zone_operations.get,
        {:operation => id}
      )
      # TODO log any operations warnings - result[:warnings][0][:message]
    end

  end
end
end
end
end
