require_relative "operations_base"

class Chef
  module Provisioning
    module GoogleDriver
      module Client
        # Wraps a GlobalOperations service of the GCE API.
        class GlobalOperations < OperationsBase

          def operations_service
            compute.global_operations
          end

        end
      end
    end
  end
end
