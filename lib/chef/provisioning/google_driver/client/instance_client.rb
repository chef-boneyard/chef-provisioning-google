require_relative 'google_base'
require 'retryable'

class Chef
module Provisioning
module GoogleDriver
module Client
  class Instance < GoogleBase

    def get(name)
      result = make_request(
        compute.instances.get,
        {:instance => name}
      )
      return nil if result[:status] == 404
      return result[:body]
    end

    def create(options={})
      result = make_request(
        compute.instances.insert,
        nil,
        options
      )
      raise result[:body] if result[:status] != 200
      operation_id = result[:body][:name]
    end

    def delete(name)
      result = make_request(
        compute.instances.delete,
        {:instance => name}
      )
      raise result[:body] if result[:status] != 200
      operation_id = result[:body][:name]
    end

    def start(name)
      result = make_request(
        compute.instances.start,
        {:instance => name}
      )
      return nil if result[:status] == 404
      operation_id = result[:body][:name]
    end

    def stop(name)
      result = make_request(
        compute.instances.stop,
        {:instance => name}
      )
      return nil if result[:status] == 404
      operation_id = result[:body][:name]
    end

    # This returns the minimum set of options needed to create a Google
    # instance.  It adds required options (like name) to the object.
    # https://cloud.google.com/compute/docs/instances#startinstanceapi
    def default_create_options(zone, name)
      {
        :machineType=>"zones/#{zone}/machineTypes/f1-micro",
        :name=>name,
        :disks=>[{
          :deviceName => name,
          :autoDelete=>true,
          :boot=>true,
          :initializeParams=>{
            :sourceImage=>"projects/ubuntu-os-cloud/global/images/ubuntu-1404-trusty-v20150316"
          },
          :type=>"PERSISTENT"
        }],
        :networkInterfaces => [{
          :network=>"global/networks/default",
          :name => "nic0",
          :accessConfigs => [{
            "type" => "ONE_TO_ONE_NAT",
            "name" => "External NAT"
          }]
        }]
      }
    end

  end
end
end
end
end
