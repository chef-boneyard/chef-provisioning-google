class Chef
module Provisioning
module GoogleDriver
  # Access various forms of Google credentials
  # TODO: currently only supports [API key](https://developers.google.com/api-client-library/ruby/auth/api-keys)
  # OAuth 2.0 is required for accessing user data
  class Credentials

    REQUIRED_KEYS = [:p12_path, :issuer, :passphrase].freeze

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
      unless REQUIRED_KEYS - h.keys == []
        raise "You must provide all required keys #{REQUIRED_KEYS.inspect}"
      end
      credentials = self.new
      h.each do |k, v|
        credentials[k] = v
      end
      credentials
    end

    def load_defaults
      raise NotImplementedError
    end

  end
end
end
end
