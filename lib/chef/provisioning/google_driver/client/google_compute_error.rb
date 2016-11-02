class Chef
  module Provisioning
    module GoogleDriver
      module Client
        class GoogleComputeError < StandardError

          def initialize(result)
            #TODO better error formatting
            super(result)
          end

        end
      end
    end
  end
end
