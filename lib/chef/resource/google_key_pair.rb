require 'chef/resource/lwrp_base'

class Chef::Resource::GoogleKeyPair < Chef::Resource::LWRPBase
  self.resource_name = self.dsl_name

  # TODO instance specific or project wide?
  # Right now we only have project wide keys

  provides :google_key_pair

  actions :create, :destroy
  default_action :create

  # Private key to use as input (will be generated if it does not exist)
  attribute :private_key_path, :kind_of => String
  # Public key to use as input (will be generated if it does not exist)
  attribute :public_key_path, :kind_of => String
  # List of parameters to the private_key resource used for generation of the key
  attribute :private_key_options, :kind_of => Hash

  # This applies to both the local keys and the remote key
  attribute :allow_overwrite, :kind_of => [TrueClass, FalseClass], :default => false

  # TODO: add a `user` attribute which sets the user to login with the key
  # GCE uses the key user to create a user on the instance, which may duplicate
  # some logic the user is trying to do with their chef recipes

  def after_created
    # We default these here so load_current_resource can diff
    if private_key_path.nil?
      private_key_path ::File.join(driver.config[:private_key_write_path], 'google_default')
    elsif Pathname.new(private_key_path).relative?
      private_key_path ::File.join(driver.config[:private_key_write_path], private_key_path)
    end
    # TODO you don't actually need to write the private key to disc if it isn't provided
    # it can be read from the private key, but this code update needs testing
    if public_key_path.nil?
      public_key_path ::File.join(driver.config[:private_key_write_path], 'google_default.pub')
    elsif Pathname.new(public_key_path).relative?
      public_key_path ::File.join(driver.config[:private_key_write_path], public_key_path)
    end
  end


  # TODO introduce base class and add this as attribute, like AWS does
  # Ideally, we won't be creating lots of copies of the same driver object, but it is okay
  # if we do - they aren't singletons
  def driver
    run_context.chef_provisioning.driver_for(run_context.chef_provisioning.current_driver)
  end
end
