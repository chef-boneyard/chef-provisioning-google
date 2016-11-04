require_relative "google_base"
require_relative "operation"
require_relative "google_compute_error"
require "retryable"

class Chef
  module Provisioning
    module GoogleDriver
      module Client
        class OperationsBase < GoogleBase

          # The operations service that should be used,
          # i.e. global_operations or zone_operations.
          def operations_service
            raise NotImplementedError
          end

          def get(operation)
            response = make_request(
              operations_service.get,
              { operation: operation.name }
            )
            operation_response(response)
          end

          def wait_for_done(action_handler, operation)
            Retryable.retryable(:tries => TRIES, :sleep => SLEEP_SECONDS, :matching => /not be completed/) do |retries, exception|
              # TODO the operation name isn't useful output
              action_handler.report_progress("  waited #{retries * SLEEP_SECONDS}/#{TRIES * SLEEP_SECONDS}s for operation #{operation.name} to complete")
              # TODO it is really awesome that there are 3 types of operations, and the only way of telling
              # which is which is to parse the full `:selfLink` from the response body.  Update this method
              # to take the full operation response from Google so it can tell which operation endpoint
              # to hit
              response_operation = get(operation)
              raise GoogleComputeError, "Operation #{operation.name} could not be completed." unless response_operation.done?
              response_operation
            end
          end

        end
      end
    end
  end
end
