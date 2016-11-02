require_relative "operations_base"

class Chef
  module Provisioning
    module GoogleDriver
      module Client
        # Wraps a ZoneOperations service of the GCE API.
        class ZoneOperations < OperationsBase

          def operations_service
            compute.zone_operations
          end

        end
      end
    end
  end
end
