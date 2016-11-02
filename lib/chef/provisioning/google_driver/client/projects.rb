require_relative 'google_base'
require_relative 'metadata'

class Chef
module Provisioning
module GoogleDriver
module Client
  # Wraps a Projects service of the GCE API.
  class Projects < GoogleBase

    def get
      # The default arguments are already enough for this call.
      response = make_request(compute.projects.get)
      raise_if_error(response)
      Metadata.new(response)
    end

    # Takes a metadata object retrieved via #get and updates the metadata on GCE
    # using the projects.set_common_instance_metadata API call.
    # This fails if the metadata on GCE has been updated since the passed
    # metadata object has been retrieved via #get.
    # Note that this omits the API call if the metadata object hasn't changed
    # locally since it was retrieved via #get.
    def set_common_instance_metadata(metadata)
      return nil unless metadata.changed?
      response = make_request(
        compute.projects.set_common_instance_metadata,
        # Default paremeters are sufficient.
        {}, 
        {items: metadata.items, fingerprint: metadata.fingerprint}
      )
      operation_response(response)
    end

  end
end
end
end
end
