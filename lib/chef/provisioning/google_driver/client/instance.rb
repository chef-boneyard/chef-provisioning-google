require_relative 'google_compute_error'

class Chef
module Provisioning
module GoogleDriver
module Client

  # Wraps a response of an instances.get request to the GCE API and provides
  # access to information about the instance.
  class Instance
    def initialize(response)
      @response = response
    end

    def name
      @response[:body][:name]
    end

    def id
      @response[:body][:id]
    end

    def status
      @response[:body][:status]
    end

    def terminated?
      status == 'TERMINATED'
    end

    def running?
      status == 'RUNNING'
    end

    def stopping?
      status == 'STOPPING'
    end

    def stopped?
      status == 'STOPPED'
    end

    # TODO right now we assume the host has a accessConfig which is public
    # https://cloud.google.com/compute/docs/reference/latest/instances#resource
    def determine_remote_host
      interfaces = @response[:body][:networkInterfaces]
      interfaces.each do |i|
        if i.key?(:accessConfigs)
          i[:accessConfigs].each do |a|
            if a.key?(:natIP)
              return a[:natIP]
            end
          end
        end
      end
      raise GoogleComputeError, "Server #{name} has no private or public IP address!"
    end

  end

end
end
end
end
