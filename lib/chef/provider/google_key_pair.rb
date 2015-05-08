require 'chef/provider/lwrp_base'

class Chef::Provider::GoogleKeyPair < Chef::Provider::LWRPBase
  use_inline_resources

  action :create do
    require 'pry'; binding.pry
    # First, make sure private key exists
    if File.exists?(new_private_key_path)
      # update it if overwrite is set
    else
      action = :create
      # create the private & public key
      # create enclosing directory
      Cheffish.inline_resource(self, action) do
        directory Pathname.new(new_private_key_path).dirname.expand_path.to_s
      end
      # create key using Cheffish
      resource = new_resource
      Cheffish.inline_resource(self, action) do
        private_key new_private_key_path do
          public_key_path resource.public_key_path
          if resource.private_key_options
            resource.private_key_options.each_pair do |key,value|
              send(key, value)
            end
          end
        end
      end
    end

    # now check if what we have locally matches google
    # if not, upload (or reupload) to google


  end

  action :destroy do
    if
      converge_by "delete AWS key pair #{new_resource.name} on region #{region}" do
        driver.ec2.key_pairs[new_resource.name].delete
      end
    end
  end

  def load_current_resource
    @current_resource = Chef::Resource::GoogleKeyPair.new(new_resource.name, run_context)

    if new_private_key_path && ::File.exist?(new_private_key_path)
      current_resource.private_key_path new_private_key_path
    end
    if new_public_key_path && ::File.exist?(new_public_key_path)
      current_resource.public_key_path new_public_key_path
    end
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

end
