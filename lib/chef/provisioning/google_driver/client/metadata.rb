class Chef
  module Provisioning
    module GoogleDriver
      module Client

        # Wraps a response of a projects.get request to the GCE API and provides
        # access to metadata like SSH keys. It can also be modified and passed
        # back to the projects client which will set the new metadata by sending
        # a projects.set_common_instance_metadata request to the GCE API.
        class Metadata
          def initialize(response)
            metadata = response[:body][:commonInstanceMetadata]
            @fingerprint = metadata[:fingerprint]
            @items = metadata[:items].dup || []
            sort_items!
            @changed = false
          end

          attr_reader :fingerprint, :items

          # Returns true iff the metadata has been changed since it has been retrieved
          # from GCE.
          def changed?
            @changed
          end

          # Note that the returned object should not be modified directly.
          # Instead, set_ssh_key or delete_ssh_key should be used.
          def ssh_keys
            @ssh_keys ||= parse_keys(get_metadata_item(SSH_KEYS))
          end

          # Ensure the list of keys stored in GCE contains the provided key.  If
          # the provided key already exists it will be updated
          # TODO: This will need to be updated later with user accounts:
          # see https://cloud.google.com/compute/docs/access/user-accounts/
          def ensure_key(username, local_key)
            ssh_keys << [username, local_key]
            set_metadata_item(SSH_KEYS, serialize_keys(ssh_keys))
          end

          # Deletes an ssh key by value, i.e. by the SSH key.
          def delete_ssh_key(value)
            ssh_keys.reject! { |k, v| v == value }
            set_metadata_item(SSH_KEYS, serialize_keys(ssh_keys))
          end

          # We store the mapping of resource name to key value in GCE so we can tell
          # if a key has changed.
          # Note that the returned object should not be modified directly.
          # Instead, set_ssh_mapping or delete_ssh_mapping should be used.
          def ssh_mappings
            @ssh_mappings ||= Hash[parse_keys(get_metadata_item(SSH_MAPPINGS))]
          end

          def set_ssh_mapping(name, local_key)
            # TODO what if users change the name of the resource but not the key
            # should we remove the old entry from both mappings?
            ssh_mappings[name] = local_key
            set_metadata_item(SSH_MAPPINGS, serialize_keys(ssh_mappings))
          end

          def delete_ssh_mapping(name)
            ssh_mappings.delete(name)
            set_metadata_item(SSH_MAPPINGS, serialize_keys(ssh_mappings))
          end

          private

          def set_metadata_item(key, value)
            @items.delete_if { |m| m[:key] == key }
            @items << { key: key,  value: value }
            sort_items!
            @changed = true
          end

          def sort_items!
            @items.sort_by! { |a| a[:key] }
          end

          # Gets one metadata item with the given key.
          def get_metadata_item(key)
            match = @items.find { |item| item[:key] == key }
            match[:value] if match
          end

          SSH_KEYS = "sshKeys"
          SSH_MAPPINGS = "chef-provisioning-google_ssh-mappings"
          KEY_VALUE_SEPARATOR = ":"
          ITEM_SEPARATOR = "\n"

          # Serializes SSH keys or SSH key mappings into a string.
          # This works both for a hash map or an array of pairs.
          def serialize_keys(keys)
            keys.map { |e| e.join(KEY_VALUE_SEPARATOR) }.join(ITEM_SEPARATOR)
          end

          # Parses SSH keys or SSH key mappings from a string.
          # This returns an array of pairs. If a hash_map is needed, Hash[] can be
          # called on the result.
          def parse_keys(keys_string)
            return [] if keys_string.nil?
            keys_string.split(ITEM_SEPARATOR).map do |line|
              line.split(KEY_VALUE_SEPARATOR, 2)
            end
          end

        end

      end
    end
  end
end
