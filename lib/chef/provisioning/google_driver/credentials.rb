class Chef
module Provisioning
module GoogleDriver
  # Access various forms of Google credentials
  # TODO: load credentials from metadata server when provisioning from a GCE machine
  class Credentials

    def initialize
      @credentials = {}
    end

    def [](name)
      @credentials[name]
    end

    def []=(name, value)
      @credentials[name] = value
    end

    def self.from_hash(h)
      credentials = self.new
      h.each do |k, v|
        credentials[k] = v
      end
      credentials.validate!
      credentials
    end

    # Validates whether the key settings are present in the credential object and keys are in the correct format.
    # If no client_email is specified, method will try to load the client_email from the json key.
    def validate!
      unless self[:p12_key_path] || self[:json_key_path]
        raise "Google key path is missing. Options provided: #{self.inspect}"
      end
      if self[:json_key_path]
        json_key_hash = JSON.load(File.open(self[:json_key_path]))

        unless self[:google_client_email]
          # Try to load client_email from json if not present
          if json_key_hash["client_email"]
            self[:google_client_email] = json_key_hash["client_email"]
          else
            raise "google_client_email must be specified"
          end
        end

        raise "Invalid Google JSON key, no private key" unless json_key_hash.include?("private_key")
      elsif self[:p12_key_path]
        raise "p12 key doesn't exist in the path specified" unless File.exist?(self[:p12_key_path])
        raise "google_client_email must be specified" unless self[:google_client_email]
      else
        raise "json_key_path or p12_key_path is missing. Options provided: #{self}"
      end
    end

    def load_defaults
      raise NotImplementedError
    end

  end
end
end
end
