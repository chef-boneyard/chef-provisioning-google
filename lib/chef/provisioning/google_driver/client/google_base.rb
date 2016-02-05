require 'ffi_yajl'
require_relative 'google_compute_error'
require_relative 'operation'

class Chef
module Provisioning
module GoogleDriver
module Client
  class GoogleBase
    # TODO make these configurable
    TRIES = 30
    SLEEP_SECONDS = 5

    NOT_FOUND = 404
    OK = 200

    attr_reader :google, :project, :zone

    def initialize(google, project, zone)
      @google = google
      @project = project
      @zone = zone
    end

    def make_request(method, parameters=nil, body=nil)
      response = google.execute(
        api_method: method,
        parameters: default_parameters.merge(parameters || {}),
        body_object: body
      )
      {
        status: response.response.status,
        body: FFI_Yajl::Parser.parse(response.response.body,
                                     symbolize_keys: true)
      }
    end

    def compute
      @compute ||= google.discovered_api('compute')
    end

    def default_parameters
      {project: project, zone: zone}
    end

    # Takes the response of an API call and if the response contains an error,
    # it raises an error. If the response was successful, it returns an
    # operation.
    def operation_response(response)
      raise_if_error(response)
      Operation.new(response)
    end

    # Takes a response of an API call and returns true iff this has status not
    # found.
    def is_not_found?(response)
      response[:status] == NOT_FOUND
    end

    # Takes a response of an API call and raises an error if the call was
    # unsuccessful.
    def raise_if_error(response)
      # TODO Display warnings in some way.
      if response[:status] != OK || response[:body][:error]
        raise GoogleComputeError, response
      end
    end
  end
end
end
end
end
