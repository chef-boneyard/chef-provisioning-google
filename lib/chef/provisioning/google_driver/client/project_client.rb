require_relative 'google_base'

class Chef
module Provisioning
module GoogleDriver
module Client
  class Project < GoogleBase

    # TODO this class is super inefficient - it does a ton of fetches

    SSH_KEYS = "sshKeys"
    SSH_MAPPINGS = "chef-provisioning-google_ssh-mappings"

    def get
      result = make_request(
        compute.projects.get,
        {:project => project}
      )
      return nil if result[:status] == 404
      return result[:body]
    end

    def get_metadata
      result = get
      # If there is no metadata, google doesn't return `items`, so we insert
      # it here to make later calls less messy
      result[:commonInstanceMetadata][:items] ||= []
      result[:commonInstanceMetadata]
    end

    # This method fetches the existing metadata and updates it to ensure the provided
    #   item is contained.  If there is an existing item with the same metadata
    #   key then it is replaced.
    # @param metadata_item [Hash] A hash with a single metadata item.  The hash should
    #   look like `{key: '...', value: '...'}`
    # @return [String] The operation_id of the request
    def set_metadata(metadata_item)
      current_metadata = get_metadata
      fingerprint = current_metadata[:fingerprint]

      items = current_metadata[:items].delete_if {|m| m[:key] == metadata_item[:key]}
      items << metadata_item
      result = make_request(
        compute.projects.set_common_instance_metadata,
        {:project => project},
        {:items => items, :fingerprint => fingerprint}
      )
      return nil if result[:status] == 404
      result[:body][:name]
    end

    # Returns a hash of `username` => `ssh_key`, which is stored on the GCE
    # side as `username:ssh_key`
    def get_ssh_keys
      list = get_metadata[:items].select {|m| m[:key] == SSH_KEYS}.first
      if list
        mappings = {}
        list[:value].split("\n").each do |mapping|
          username = mapping.split(":")[0]
          key = mapping.split(":")[1]
          mappings[username] = key
        end
        return mappings
      end
      {}
    end

    # Ensure the list of keys stored in GCE contains the provided key.  If
    # the provided key already exists it will be updated
    def ensure_key(username, local_key)
      keys = get_ssh_keys
      keys[username] = local_key

      keys_as_string = keys.map {|u, k| "#{u}:#{k}"}.join("\n")
      set_metadata({:key => SSH_KEYS, :value => keys_as_string})
    end

    def delete_key_by_value(value)
      keys = get_ssh_keys
      keys.reject! {|k,v| v == value}

      keys_as_string = keys.map {|u, k| "#{u}:#{k}"}.join("\n")
      set_metadata({:key => SSH_KEYS, :value => keys_as_string})
    end

    # We store the mapping of resource name to key value in GCE so we can tell if a key has changed
    def get_ssh_mappings
      list = get_metadata[:items].select {|m| m[:key] == SSH_MAPPINGS}.first
      if list
        mappings = {}
        list[:value].split("\n").each do |mapping|
          name = mapping.split(":")[0]
          key = mapping.split(":")[1]
          mappings[name] = key
        end
        return mappings
      end
      {}
    end

    def set_ssh_mapping(name, local_key)
      mappings = get_ssh_mappings
      mappings[name] = local_key
      # TODO what if users change the name of the resource but not the key
      # should we remove the old entry from both mappings?

      mappings_as_string = mappings.map {|n, k| "#{n}:#{k}"}.join("\n")
      set_metadata({:key => SSH_MAPPINGS, :value => mappings_as_string})
    end

    def delete_ssh_mapping(name)
      mappings = get_ssh_mappings
      mappings.delete(name)

      mappings_as_string = mappings.map {|n, k| "#{n}:#{k}"}.join("\n")
      set_metadata({:key => SSH_MAPPINGS, :value => mappings_as_string})
    end

  end
end
end
end
end
