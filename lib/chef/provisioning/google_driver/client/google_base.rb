require 'ffi_yajl'

class Chef
module Provisioning
module GoogleDriver
module Client
  class GoogleBase
    attr_reader :google, :project, :zone

    def initialize(google, project, zone)
      @google = google
      @project = project
      @zone = zone
    end

    def make_request(method, parameters=nil, body=nil)
      result = google.execute(
        :api_method => method,
        :parameters => default_parameters.merge(parameters || {}),
        :body_object => body
      )
      {
        :status => result.response.status,
        :body => FFI_Yajl::Parser.parse(result.response.body, :symbolize_keys => true)
      }
    end

    def compute
      @compute ||= google.discovered_api('compute')
    end

    def default_parameters
      {:project => project, :zone => zone}
    end
  end
end
end
end
end
