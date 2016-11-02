require_relative 'google_base'
require_relative 'instance'
require_relative 'google_compute_error'
require 'retryable'

class Chef
module Provisioning
module GoogleDriver
module Client
  # Wraps an Instances service of the GCE API.
  class Instances < GoogleBase

    # Retrieves the instance with the given name.
    # If the instance doesn't exist, returns nil.
    def get(name)
      response = make_request(
        compute.instances.get,
        {instance: name}
      )
      return nil if is_not_found?(response)
      raise_if_error(response)
      Instance.new(response)
    end

    def create(options={})
      response = make_request(
        compute.instances.insert,
        nil,
        options
      )
      operation_response(response)
    end

    def delete(name)
      response = make_request(
        compute.instances.delete,
        {instance: name}
      )
      operation_response(response)
    end

    def start(name)
      response = make_request(
        compute.instances.start,
        {instance: name}
      )
      operation_response(response)
    end

    def stop(name)
      response = make_request(
        compute.instances.stop,
        {instance: name}
      )
      operation_response(response)
    end

    # This returns the minimum set of options needed to create a Google
    # instance.  It adds required options (like name) to the object.
    # https://cloud.google.com/compute/docs/instances#startinstanceapi
    def default_create_options(name)
      {
        machineType: "zones/#{zone}/machineTypes/f1-micro",
        name: name,
        disks: [{
          deviceName: name,
          autoDelete: true,
          boot: true,
          initializeParams: {
            sourceImage: "projects/ubuntu-os-cloud/global/images/ubuntu-1404-trusty-v20150316"
          },
          type: "PERSISTENT"
        }],
        networkInterfaces: [{
          network: "global/networks/default",
          name: "nic0",
          accessConfigs: [{
            type: "ONE_TO_ONE_NAT",
            name: "External NAT"
          }]
        }]
      }
    end

    def wait_for_status(action_handler, instance, status)
      Retryable.retryable(tries: TRIES, sleep: SLEEP_SECONDS, matching: /reach status/) do |retries, exception|
        action_handler.report_progress("  waited #{retries*SLEEP_SECONDS}/#{TRIES*SLEEP_SECONDS}s for instance #{instance.name} to become #{status}")
        instance = get(instance.name)
        raise GoogleComputeError, "Instance #{instance.name} didn't reach status #{status} yet." unless instance.status == status
        instance
      end
    end

  end
end
end
end
end
