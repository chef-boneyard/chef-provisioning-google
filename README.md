# chef-provisioning-google

[![Build Status](https://travis-ci.org/chef/chef-provisioning-google.svg?branch=master)](https://travis-ci.org/chef/chef-provisioning-google)

## Development Process

The [GoogleDriver](https://github.com/someara/chef-provisioning-google/blob/master/lib/chef/provisioning/google_driver/driver.rb) class needs to implement required methods from [its parent](https://github.com/chef/chef-provisioning/blob/master/lib/chef/provisioning/driver.rb) to successfully create [base resources](https://github.com/chef/chef-provisioning/tree/master/lib/chef/resource) like `machine` and `load_balancer`.

I added all the driver methods to support creating and destroying a machine. The action `:converge_only` currently does not work because the machine spec does not store credential information. But this should be fixed as part of the credentials update TODO.

## Prerequisites

Before you start writing a recipe, you need to log into the [google developers console](https://console.developers.google.com/) and create a project. This project must be enabled for billing. Once billing is enabled you should be able to create VM instances through the console.

Then you need to set up credentials to use for connecting. We use the Google OAuth 2.0 credentials. Because we cannot present a pop-up to cookbook writers to authorize access, we need a service account key and a service user to act on our behalf and request instances.

Service account key workflow:

- Access `API Manager` -> `Credentials` from the navigation gutter.
- Click the `New Credentials` button and select `Service Account key`.
- Select the service account to create the key for or 'New service account' if you haven't created one yet.
- Choose `JSON Key` in the Key type options. This will create your service user and will download the JSON key to your workstation.

Provide the full path to the downloaded JSON file as `:json_key_path` anb the `Email Address` (can be found in "Pemissions" -> "Service accounts") as the `:google_client_email`.

## Sample Recipe

I am running the following recipe to test the code:

```ruby
require 'chef/provisioning/google_driver'

with_driver 'google:us-central1-a:some-project',
  :google_credentials => {
    :json_key_path => 'REDACTED',
    :google_client_email => 'REDACTED',
  }

google_key_pair "chef_default" do
  private_key_path "google_default"
  public_key_path "google_default.pub"
end

machine 'test' do
  machine_options key_name: "google_default"
  action [:converge, :destroy]
end
```

Currently, you _must_ specify `key_name` as an option to `machine_options`.

## Supplying `insert_options` for machine creation

Google requires a minimum set of options to provision a machine during a `compute.instances.create` call. You can see the minimum set of options in the `instance_client.rb` file. It is a machine with Ubuntu 14.04 installed, 1 disc available and 1 network device configured.

To customize your machine you provide override options as `:insert_options` to the `machine_options` attribute. The full list of options is available at <https://cloud.google.com/compute/docs/reference/latest/instances#resource> EG,

```ruby
machine 'test' do
  machine_options insert_options: {
    :machineType=> "zones/us-central1-a/machineTypes/n1-standard-1",
    :tags => {
      :items => [
        "http-server",
        "https-server"
      ]
    },
    :disks => [
      {
        :deviceName => 'test',
        :autoDelete=>true,
        :boot=>true,
        :initializeParams=>{
          :sourceImage => "projects/ubuntu-os-cloud/global/images/ubuntu-1404-trusty-v20150316",
          :diskType => "zones/us-central1-a/diskTypes/pd-ssd",
          :diskSizeGb => 200
        },
        :type=>"PERSISTENT"
      },
      {
        :type => "PERSISTENT",
        :mode => "READ_WRITE",
        :zone => "zones/us-central1-a",
        :source => "zones/us-central1-a/disks/disk-1",
        :deviceName => "disk-1"
      }
    ],
    :serviceAccounts => [
      {
        :email => "default",
        :scopes => [
          "https://www.googleapis.com/auth/devstorage.read_only",
          "https://www.googleapis.com/auth/bigquery",
          "https://www.googleapis.com/auth/logging.write"
        ]
      }
    ]
  }, key_name: "google_default"
  action [:converge, :destroy]
end
```

Some remaining TODOs with this are to make it easier to specify options - users shouldn't be required to specify `zones/us-central1-a/machineTypes/f1-micro` for the machine type. It should just be `f1-micro.

The user also shouldn't be required to specify all the required options for each `disc` if they are overwriting the default. If the user wants to specify `:autoDelete => false` they shouldn't also have to specify name, boot, initializeParams, etc. The logic that merges user provided values with default values should be smarter.

## TODO items

- Update the Credentials to read from the file system or environmental variables - it is a big no-no to put credentials in the cookbook.
- DRY up the client request/response logic.
- Lots of polish
- Support for machine_image, machine_batch, machine_execute and load_balancer resources
- Windows hosts

# Resources

## google_key_pair

This creates a local private/public keypair and uploads it to Google as a project-wide key. This is used to SSH into the instance.

TODO: Add support for instance-specific keys.
