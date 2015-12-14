require 'chef/provider/lwrp_base'
require 'cheffish/key_formatter'
require 'chef/resource/google_key_pair'
require 'retryable'

class Chef::Provider::GoogleKeyPair < Chef::Provider::LWRPBase
  use_inline_resources

  # TODO make sure we can take relative paths - where do we get base path from then?
  action :create do
    if !current_resource_exists?  || allow_overwrite
      converge_local_keys(:create)
    end

    #Check if keys exist
    unless allow_overwrite
      if current_resource.private_key_path && current_resource.private_key_path != new_private_key_path ||
         current_resource.public_key_path && current_resource.public_key_path != new_public_key_path ||
         current_fingerprint && current_fingerprint != Cheffish::KeyFormatter.encode(desired_key,:format => :fingerprint)
        raise "cannot update google_key_pair[#{new_resource.name}] because 'allow_overwrite' is false"
      end
    end

    # We store the mapping from resource name to key in GCE
    name_to_key = driver.project_client.get_ssh_mappings
    if name_to_key.key?(new_resource.name)
      remote_key = name_to_key[new_resource.name]
      if remote_key != desired_key_openssh
        if allow_overwrite
          set_key_and_mapping
        else
          raise "the remote key is different than local but cannot be updated because 'allow_overwrite' is false"
        end
      end
      # if local key same as server - we are done
    else
      # We need to upload the key for the first time
      set_key_and_mapping
    end

  end

  action :destroy do
    name_to_key = driver.project_client.get_ssh_mappings
    remote_key = name_to_key[new_resource.name]
    if remote_key
      operation_id = nil
      username = remote_key.split(" ")[2].split("@")[0]
      converge_by "deleting key for username #{username}" do
        operation_id = driver.project_client.delete_key_by_value(remote_key)
      end
      wait_for_operation(operation_id)

      converge_by "deleting metadata mapping for google_key_pair[#{new_resource.name}]" do
        operation_id = driver.project_client.delete_ssh_mapping(new_resource.name)
      end
      wait_for_operation(operation_id)
    end
    # TODO do we care about deleting the local key?
  end

  attr_reader :current_fingerprint

  def load_current_resource
    @current_resource = Chef::Resource::GoogleKeyPair.new(new_resource.name, run_context)

    existing_key = driver.project_client.get_ssh_mappings[new_resource.name]
    if existing_key
      @current_fingerprint = Cheffish::KeyFormatter.encode(
        Cheffish::KeyFormatter.decode(existing_key)[0],
        :format => :fingerprint
      )
    else
      current_resource.action :destroy
    end

    if new_private_key_path && ::File.exist?(new_private_key_path)
      current_resource.private_key_path new_private_key_path
    end
    if new_public_key_path && ::File.exist?(new_public_key_path)
      current_resource.public_key_path new_public_key_path
    end
  end

  def current_resource_exists?
    @current_resource.action != [ :destroy ]
  end

  # Converge the local keys
  # private_key_path will always be populated but public_key_path can be
  # parsed from the private key later if it isn't provided
  def converge_local_keys(action)
    resource = new_resource
    # TODO I think Cheffish will take care of the directories, but need to test
    Cheffish.inline_resource(self, action) do
      private_key resource.private_key_path do
        public_key_path resource.public_key_path if resource.public_key_path
        if resource.private_key_options
          resource.private_key_options.each_pair do |key,value|
            send(key, value)
          end
        end
      end
    end
  end

  def allow_overwrite
    new_resource.allow_overwrite
  end

  def new_private_key_path
    new_resource.private_key_path
  end

  def new_public_key_path
    new_resource.public_key_path
  end

  def desired_private_key
    @desired_private_key ||= begin
      private_key, format = Cheffish::KeyFormatter.decode(IO.read(new_private_key_path))
      private_key
    end
  end

  def desired_key
    @desired_public_key ||= begin
      if new_public_key_path
        public_key, format = Cheffish::KeyFormatter.decode(IO.read(new_public_key_path))
        public_key
      else
        desired_private_key.public_key
      end
    end
  end

  def desired_key_openssh
    Cheffish::KeyFormatter.encode(desired_key, :format => :openssh)
  end

  def set_key_and_mapping
    operation_id = nil
    username = desired_key_openssh.split(" ")[2].split("@")[0]
    converge_by "adding key for username #{username}" do
      operation_id = driver.project_client.ensure_key(username, desired_key_openssh)
    end
    wait_for_operation(operation_id)

    converge_by "ensuring we store metadata mapping for google_key_pair[#{new_resource.name}]" do
      operation_id = driver.project_client.set_ssh_mapping(new_resource.name, desired_key_openssh)
    end
    wait_for_operation(operation_id)
  end

  # TODO abstract into base class
  def driver
    new_resource.driver
  end

  # TODO abstract into base class
  def action_handler
    @action_handler ||= Chef::Provisioning::ChefProviderActionHandler.new(self)
  end

  # TODO de-dup with driver or abstract to base class
  # TODO update to take the full operation body
  def wait_for_operation(operation_id)
    Retryable.retryable(:tries => 30, :sleep => 5, :matching => /Not done/) do |retries, exception|
      action_handler.report_progress("  waited #{retries*5}/#{30*5}s for operation #{operation_id} to complete")
      # TODO it is really awesome that there are 3 types of operations, and the only way of telling
      # which is which is to parse the full `:selfLink` from the response body
      operation = driver.operations_client.global_get(operation_id)
      raise "Not done" unless operation[:body][:status] == "DONE"
      operation
    end
  end
end
