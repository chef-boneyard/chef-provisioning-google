class Chef
  module Provisioning
    module GoogleDriver
      module Client
        class Operation

          def initialize(response)
            @response = response
          end

          def name
            @response[:body][:name]
          end

          def done?
            @response[:body][:status] == "DONE"
          end

        end
      end
    end
  end
end
