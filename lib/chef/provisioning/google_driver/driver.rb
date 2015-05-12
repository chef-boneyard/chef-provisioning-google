require 'chef/provisioning/driver'
require 'chef/provisioning/google_driver/credentials'
require 'chef/provisioning/google_driver/version'
require 'chef/mixin/deep_merge'

require_relative 'client/instance_client'
require_relative 'client/operations_client'
require_relative 'client/project_client'

require 'google/api_client'
require 'retryable'

class Chef
module Provisioning
module GoogleDriver
  # Provisions machines using the Google SDK
  # TODO look at the superclass comments for further explanation of the overridden methods in this class
  class Driver < Chef::Provisioning::Driver

    include Chef::Mixin::DeepMerge

    attr_reader :google, :zone, :project, :instance_client, :operations_client, :project_client
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
      # TODO: Move zone into bootstrap_options
      @zone = m[1]
      @project = m[2]

      @google = Google::APIClient.new(
        :application_name => 'chef-provisioning-google',
        :application_version => Chef::Provisioning::GoogleDriver::VERSION
      )
      key = Google::APIClient::KeyUtils.load_from_pkcs12(google_credentials[:p12_path], google_credentials[:passphrase])
      google.authorization = Signet::OAuth2::Client.new(
        :token_credential_uri => 'https://accounts.google.com/o/oauth2/token',
        :audience => 'https://accounts.google.com/o/oauth2/token',
        :scope => ['https://www.googleapis.com/auth/compute','https://www.googleapis.com/auth/compute.readonly'],
        :issuer => google_credentials[:issuer],
        :signing_key => key,
      )
      google.authorization.fetch_access_token!

      @operations_client = Client::Operations.new(google, project, zone)
      @instance_client = Client::Instance.new(google, project, zone)
      @project_client = Client::Project.new(google, project, zone)

    end

    def self.canonicalize_url(driver_url, config)
      [ driver_url, config ]
    end

    def allocate_machine(action_handler, machine_spec, machine_options)
      name = machine_spec.name
      # TODO update to `instance_for` when we get the reference storing/updating correctly
      # TODO how do we handle running `allocate` and there is already a machine in AWS
      #   but no node in chef?  We should just start tracking it.
      if instance_client.get(name).nil?
        operation_id = nil
        action_handler.perform_action "creating instance named #{name} in zone #{zone}" do
          default_options = instance_client.default_create_options(zone, name)
          options = hash_only_merge(default_options,machine_options[:insert_options])
          operation_id = instance_client.create(options)
        end
        operation = wait_for_operation(action_handler, operation_id)
        if operation[:error]
          error = operation[:error][:errors][0]
          raise "#{error[:code]}: #{error[:message]}"
        end
        machine_spec.reference = {
            'driver_version' => Chef::Provisioning::GoogleDriver::VERSION,
            'allocated_at' => Time.now.utc.to_s,
            'host_node' => action_handler.host_node
        }
        machine_spec.driver_url = driver_url
        # machine_spec.reference['key_name'] = bootstrap_options[:key_name] if bootstrap_options[:key_name]
        # %w(is_windows ssh_username sudo use_private_ip_for_ssh ssh_gateway).each do |key|
        #   machine_spec.reference[key] = machine_options[key.to_sym] if machine_options[key.to_sym]
        # end
      end
    end

    def destroy_machine(action_handler, machine_spec, machine_options)
      name = machine_spec.name
      instance = instance_client.get(name)
      # https://cloud.google.com/compute/docs/instances#checkmachinestatus
      if instance && instance[:status] != "STOPPING"
        operation_id = nil
        action_handler.perform_action "destroying instance named #{name} in zone #{zone}" do
          operation_id = instance_client.delete(name)
        end
        wait_for_operation(action_handler, operation_id)
      end

      # strategy = convergence_strategy_for(machine_spec, machine_options)
      # strategy.cleanup_convergence(action_handler, machine_spec)
    end

    private

    # TODO load from file or env variables using common google method
    # https://cloud.google.com/sdk/gcloud/#gcloud.auth
    def google_credentials
      # Grab the list of possible credentials
      @google_credentials ||= if driver_options[:google_credentials]
                             Credentials.from_hash(driver_options[:google_credentials])
                           else
                             credentials = Credentials.new
                             credentials.load_defaults
                             credentials
                           end
    end

    # TODO make these configurable
    def tries
      30
    end
    def sleep
      5
    end
    # TODO the operation_id isn't useful output
    # TODO update to take the full operation body
    def wait_for_operation(action_handler, operation_id)
      Retryable.retryable(:tries => tries, :sleep => sleep, :matching => /Not done/) do |retries, exception|
        action_handler.report_progress("  waited #{retries*sleep}/#{tries*sleep}s for operation #{operation_id} to complete")
        # TODO it is really awesome that there are 3 types of operations, and the only way of telling
        # which is which is to parse the full `:selfLink` from the response body
        operation = operations_client.zone_get(operation_id)
        raise "Not done" unless operation[:body][:status] == "DONE"
        operation
      end
    end

  end
end
end
end
