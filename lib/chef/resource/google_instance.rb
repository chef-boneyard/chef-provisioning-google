require 'chef/resource/lwrp_base'

class Chef::Resource::GoogleInstance < Chef::Resource::LWRPBase
  # So far, it looks like instances are unique by name
  attribute :name, kind_of: String, name_attribute: true
end
