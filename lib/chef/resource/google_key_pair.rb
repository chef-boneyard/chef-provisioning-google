require 'chef/resource/lwrp_base'

class Chef::Resource::GoogleKeyPair < Chef::Resource::LWRPBase
  # TODO instance specific or project wide?

  actions :create, :destroy
  default_action :create

    # Private key to use as input (will be generated if it does not exist)
  attribute :private_key_path, :kind_of => String
  # Public key to use as input (will be generated if it does not exist)
  attribute :public_key_path, :kind_of => String
  # List of parameters to the private_key resource used for generation of the key
  attribute :private_key_options, :kind_of => Hash

  attribute :allow_overwrite, :kind_of => [TrueClass, FalseClass], :default => false
end
