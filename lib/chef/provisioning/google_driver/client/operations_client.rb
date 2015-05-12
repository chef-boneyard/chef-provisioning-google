require_relative 'google_base'

class Chef
module Provisioning
module GoogleDriver
module Client
  class Operations < GoogleBase

    def zone_get(id)
      get(id, :zone)
    end

    def global_get(id)
      get(id, :global)
    end

    private

    def get(id, type)
      result = make_request(
        compute.send("#{type.to_s}_operations").get,
        {:operation => id}
      )
      raise result[:body] if result[:status] == 404
      result
    end

  end
end
end
end
end
