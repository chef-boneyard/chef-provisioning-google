require "chef/provisioning/driver"
require "chef/provisioning/google_driver/credentials"
require "chef/provisioning/google_driver/version"
require "chef/mixin/deep_merge"
require "chef/provisioning/convergence_strategy/install_cached"
require "chef/provisioning/convergence_strategy/install_sh"
require "chef/provisioning/convergence_strategy/install_msi"
require "chef/provisioning/convergence_strategy/no_converge"
require "chef/provisioning/transport/ssh"
require "chef/provisioning/transport/winrm"
require "chef/provisioning/machine/windows_machine"
require "chef/provisioning/machine/unix_machine"
require "chef/provisioning/machine_spec"

require_relative "client/instances"
require_relative "client/global_operations"
require_relative "client/projects"
require_relative "client/zone_operations"

require "google/api_client"
require "retryable"
require "etc"

class Chef
  module Provisioning
    module GoogleDriver
      # Provisions machines using the Google SDK
      # TODO look at the superclass comments for further explanation of the overridden methods in this class
      class Driver < Chef::Provisioning::Driver

        include Chef::Mixin::DeepMerge

        attr_reader :google, :zone, :project, :instance_client, :global_operations_client, :zone_operations_client, :project_client
        URL_REGEX = /^google:(.+?):(.+)$/

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
            :application_name => "chef-provisioning-google",
            :application_version => Chef::Provisioning::GoogleDriver::VERSION
          )
          if google_credentials[:p12_key_path]
            signing_key = Google::APIClient::KeyUtils.load_from_pkcs12(google_credentials[:p12_key_path], "notasecret")
          elsif google_credentials[:json_key_path]
            json_private_key = JSON.load(File.open(google_credentials[:json_key_path]))["private_key"]
            signing_key = Google::APIClient::KeyUtils.load_from_pem(json_private_key, "notasecret")
          end
          google.authorization = Signet::OAuth2::Client.new(
            :token_credential_uri => "https://accounts.google.com/o/oauth2/token",
            :audience => "https://accounts.google.com/o/oauth2/token",
            :scope => ["https://www.googleapis.com/auth/compute", "https://www.googleapis.com/auth/compute.readonly"],
            :issuer => google_credentials[:google_client_email],
            :signing_key => signing_key
          )
          google.authorization.fetch_access_token!

          @instance_client = Client::Instances.new(google, project, zone)
          @project_client = Client::Projects.new(google, project, zone)
          @global_operations_client =
            Client::GlobalOperations.new(google, project, zone)
          @zone_operations_client =
            Client::ZoneOperations.new(google, project, zone)
        end

        def self.canonicalize_url(driver_url, config)
          [ driver_url, config ]
        end

        def allocate_machine(action_handler, machine_spec, machine_options)
          # TODO how do we handle running `allocate` and there is already a machine in GCE
          #   but no node in chef?  We should just start tracking it.
          if instance_for(machine_spec).nil?
            name = machine_spec.name
            operation = nil
            action_handler.perform_action "creating instance named #{name} in zone #{zone}" do
              default_options = instance_client.default_create_options(name)
              options = hash_only_merge(default_options, machine_options[:insert_options])
              operation = instance_client.create(options)
            end
            zone_operations_client.wait_for_done(action_handler, operation)
            machine_spec.reference = {
                "driver_version" => Chef::Provisioning::GoogleDriver::VERSION,
                "allocated_at" => Time.now.utc.to_s,
                "host_node" => action_handler.host_node,
            }
            machine_spec.driver_url = driver_url
            # %w(is_windows ssh_username sudo use_private_ip_for_ssh ssh_gateway).each do |key|
            %w{ssh_username sudo ssh_gateway key_name}.each do |key|
              machine_spec.reference[key] = machine_options[key.to_sym] if machine_options[key.to_sym]
            end
          end
        end

        def ready_machine(action_handler, machine_spec, machine_options)
          name = machine_spec.name
          instance = instance_for(machine_spec)

          if instance.nil?
            raise "Machine #{name} does not have an instance associated with it, or instance does not exist."
          end

          if !instance.running?
            # could be PROVISIONING, STAGING, STOPPING, TERMINATED
            if %w{STOPPING TERMINATED}.include?(instance.status)
              action_handler.perform_action "instance named #{name} in zone #{zone} was stopped - starting it" do
                instance_client.start(name)
              end
            end
            instance_client.wait_for_status(action_handler, instance, "RUNNING")
          end

          # Refresh instance object so we get the new ip address and status
          instance = instance_for(machine_spec)

          wait_for_transport(action_handler, machine_spec, machine_options, instance)
          machine_for(machine_spec, machine_options, instance)
        end

        def destroy_machine(action_handler, machine_spec, machine_options)
          name = machine_spec.name
          instance = instance_for(machine_spec)
          # https://cloud.google.com/compute/docs/instances#checkmachinestatus
          # TODO Shouldn't we also delete stopped machines?
          if instance && !%w{STOPPING TERMINATED}.include?(instance.status)
            operation = nil
            action_handler.perform_action "destroying instance named #{name} in zone #{zone}" do
              operation = instance_client.delete(name)
            end
            zone_operations_client.wait_for_done(action_handler, operation)
          end

          strategy = convergence_strategy_for(machine_spec, machine_options)
          strategy.cleanup_convergence(action_handler, machine_spec)
          # TODO clean up known_hosts entry
        end

        def stop_machine(action_handler, machine_spec, machine_options)
          name = machine_spec.name
          instance = instance_for(machine_spec)

          if instance.nil?
            raise "Machine #{name} does not have an instance associated with it, or instance does not exist."
          end

          unless instance.terminated?
            unless instance.stopping?
              action_handler.perform_action "stopping instance named #{name} in zone #{zone}" do
                instance_client.stop(name)
              end
            end
            instance_client.wait_for_status(action_handler, instance, "TERMINATED")
          end

          if instance.terminated?
            Chef::Log.info "Instance #{instance.name} already stopped, nothing to do."
          end
        end

        # TODO make these configurable and find a good place where to put them.
        def tries
          Client::GoogleBase::TRIES
        end

        def sleep
          Client::GoogleBase::SLEEP_SECONDS
        end

        def wait_for_transport(action_handler, machine_spec, machine_options, instance)
          transport = transport_for(machine_spec, machine_options, instance)
          unless transport.available?
            if action_handler.should_perform_actions
              Retryable.retryable(:tries => tries, :sleep => sleep, :matching => /Not done/) do |retries, exception|
                action_handler.report_progress("  waited #{retries * sleep}/#{tries * sleep}s for instance #{instance.name} to be connectable (transport up and running) ...")
                raise "Not done" unless transport.available?
              end
              action_handler.report_progress "#{machine_spec.name} is now connectable"
            end
          end
        end

        def transport_for(machine_spec, machine_options, instance)
          # TODO winrm
          # if machine_spec.reference['is_windows']
          #   create_winrm_transport(machine_spec, machine_options, instance)
          # else
          create_ssh_transport(machine_spec, machine_options, instance)
          # end
        end

        def create_ssh_transport(machine_spec, machine_options, instance)
          ssh_options = ssh_options_for(machine_spec, machine_options, instance)
          username = machine_spec.reference["ssh_username"] || machine_options[:ssh_username] || Etc.getlogin
          if machine_options.has_key?(:ssh_username) && machine_options[:ssh_username] != machine_spec.reference["ssh_username"]
            Chef::Log.warn("Server #{machine_spec.name} was created with SSH username #{machine_spec.reference['ssh_username']} and machine_options specifies username #{machine_options[:ssh_username]}.  Using #{machine_spec.reference['ssh_username']}.  Please edit the node and change the chef_provisioning.reference.ssh_username attribute if you want to change it.")
          end
          options = {}
          if machine_spec.reference[:sudo] || (!machine_spec.reference.has_key?(:sudo) && username != "root")
            options[:prefix] = "sudo "
          end

          remote_host = instance.determine_remote_host

          #Enable pty by default
          options[:ssh_pty_enable] = true
          options[:ssh_gateway] = machine_spec.reference["ssh_gateway"] if machine_spec.reference.has_key?("ssh_gateway")

          Chef::Provisioning::Transport::SSH.new(remote_host, username, ssh_options, options, config)
        end

        def ssh_options_for(machine_spec, machine_options, instance)
          result = {
            :auth_methods => [ "publickey" ],
            :keys_only => true,
            :host_key_alias => "#{instance.id}.GOOGLE",
          }.merge(machine_options[:ssh_options] || {})
          # TODO right now we only allow keys created for the whole project and specified in the
          # bootstrap options - look at AWS for other options
          if machine_options[:key_name]
            # TODO how do I add keys to config[:private_keys] ?
            # result[:key_data] = [ get_private_key(machine_options[:key_name]) ]
            # TODO: what to do if we find multiple valid keys in config[:private_key_paths] ?
            config[:private_key_paths].each do |path|
              result[:key_data] = IO.read("#{path}/#{machine_options[:key_name]}") if File.exist?("#{path}/#{machine_options[:key_name]}")
            end
            unless result[:key_data]
              raise "#{machine_options[:key_name]} doesn't exist in private_key_paths:#{config[:private_key_paths]}"
            end
          else
            raise "No key found to connect to #{machine_spec.name} (#{machine_spec.reference.inspect})!"
          end
          result
        end

        def machine_for(machine_spec, machine_options, instance = nil)
          instance ||= instance_for(machine_spec)

          unless instance
            raise "Instance for node #{machine_spec.name} has not been created!"
          end

          # TODO winrm
          # if machine_spec.reference['is_windows']
          #   Chef::Provisioning::Machine::WindowsMachine.new(machine_spec, transport_for(machine_spec, machine_options, instance), convergence_strategy_for(machine_spec, machine_options))
          # else
          Chef::Provisioning::Machine::UnixMachine.new(machine_spec, transport_for(machine_spec, machine_options, instance), convergence_strategy_for(machine_spec, machine_options))
          # end
        end

        def convergence_strategy_for(machine_spec, machine_options)
          # Tell Ohai that this is an EC2 instance so that it runs the EC2 plugin
          convergence_options = Cheffish::MergedConfig.new(
            machine_options[:convergence_options] || {},
            # TODO what is the right ohai hints file?
            ohai_hints: { "google" => "" })

          # Defaults
          unless machine_spec.reference
            return Chef::Provisioning::ConvergenceStrategy::NoConverge.new(convergence_options, config)
          end

          # TODO winrm
          # if machine_spec.reference['is_windows']
          #   Chef::Provisioning::ConvergenceStrategy::InstallMsi.new(convergence_options, config)
          if machine_options[:cached_installer] == true
            Chef::Provisioning::ConvergenceStrategy::InstallCached.new(convergence_options, config)
          else
            Chef::Provisioning::ConvergenceStrategy::InstallSh.new(convergence_options, config)
          end
        end

        def instance_for(machine_spec)
          if machine_spec.reference
            if machine_spec.driver_url != driver_url
              raise "Switching a machine's driver from #{machine_spec.driver_url} to #{driver_url} is not currently supported!  Use machine :destroy and then re-create the machine on the new driver."
            end
            instance_client.get(machine_spec.name)
          end
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

      end
    end
  end
end
