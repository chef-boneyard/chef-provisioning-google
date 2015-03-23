require 'chef/provisioning/driver'
require 'chef/provisioning/google_driver/credentials'
require 'chef/resource/google_instance'

require 'google/api_client'

class Chef
module Provisioning
module GoogleDriver
  # Provisions machines using the Google SDK
  # TODO look at the superclass comments for further explanation of the overridden methods in this class
  class Driver < Chef::Provisioning::Driver

    attr_reader :client, :zone, :project
    URL_REGEX = /^google:(.+):(.+)$/

    # URL scheme:
    # google:zone
    def self.from_url(driver_url, config)
      self.new(driver_url, config)
    end

    def initialize(driver_url, config)
      super

      m = URL_REGEX.match(driver_url)
      if m.nil?
        raise "Driver URL [#{driver_url}] must match #{URL_REGEX.inspect}"
      end
      @zone = m[1]
      @project = m[2]

      @client = Google::APIClient.new
      key = Google::APIClient::KeyUtils.load_from_pkcs12(google_credentials[:p12_path], google_credentials[:passphrase])
      client.authorization = Signet::OAuth2::Client.new(
        :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
        :audience => 'https://accounts.google.com/o/oauth2/token',
        :scope => ['https://www.googleapis.com/auth/compute','https://www.googleapis.com/auth/compute.readonly'],
        :issuer => google_credentials[:issuer],
        :signing_key => key)
      client.authorization.fetch_access_token!
    end

    def self.canonicalize_url(driver_url, config)
      [ driver_url, config ]
    end

    def allocate_machine(action_handler, machine_spec, machine_options)
      result = client.execute(
        :api_method => compute.instances.get,
        :parameters => {:instance => machine_spec.name, :project => project, :zone => zone}
      )
      action_handler.perform_action "Creating instance named #{machine_spec.name} in zone #{zone}" do
        if result.response.status == 404
          # We need to create the machine
          bootstrap_options = machine_options[:bootstrap_options]
          bootstrap_options.merge!({:project => project, :zone => zone})
          result = client.execute(
            :api_method => compute.instances.insert,
            :parameters => bootstrap_options
          )
          raise result.response.body if result.response.body != 200
        end
      end
    end

    def compute
      @compute ||= client.discovered_api('compute')
    end

    private

    def google_credentials
      # Grab the list of possible credentials
      @google_credentials ||= if driver_options[:google_credentials]
                             Credentials.from_hash(driver_options[:google_credentials])
                           else
                             credentials = Credentials.new
                             # TODO look at aws_credentials - do we load from a file or env resources?
                             credentials.load_defaults
                             credentials
                           end
    end

  end
end
end
end
