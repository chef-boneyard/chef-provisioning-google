# chef-provisioning-google

## Development Process

The [GoogleDriver](https://github.com/someara/chef-provisioning-google/blob/master/lib/chef/provisioning/google_driver/driver.rb) class needs to implement required methods from [its parent](https://github.com/chef/chef-provisioning/blob/master/lib/chef/provisioning/driver.rb) to successfully create [base resources](https://github.com/chef/chef-provisioning/tree/master/lib/chef/resource) like `machine` and `load_balancer`.  The only method defined so far is `allocation_machine`, and I am currently experiencing an error.

Once that method is completed, you should get another `NoMethodError` as the base driver tries to complete the machine convergence process.  Implementing all these required methods should successfully create the machine in Google.  Documentation is available in chef-provisioning, but it is slightly out of date.  I tend to look at chef-provisioning-aws as a template.  This is not perfect though because many chef-provisioning-aws resources/providers require storing the unique aws identifier in data bags.  In my testing with Google, the machine name was enough to uniquely identify the resource.

All convergence steps should take place in an `action_handler.perform_action` block.  This notifies the output formatter to output information, as well as providing debug output for `why_run` mode.  

## Sample Recipe

I am running the following recipe to test the code:

```ruby
require 'chef/provisioning/google_driver'

with_driver 'google:us-central1-a:some-project',
  :google_credentials => {
    :p12_path => 'REDACTED',
    :issuer => 'REDACTED',
    :passphrase => 'REDACTED'
  }

machine 'test' do
  machine_options bootstrap_options: {
    :machineType=>"zones/us-central1-a/machineTypes/f1-micro",
    :name=>"instance-2",
    :disks=>[{
      :autoDelete=>true,
      :boot=>true,
      :initializeParams=>{
        :sourceImage=>"projects/coreos-cloud/global/images/coreos-stable-607-0-0-v20150317"
      },
      :type=>"PERSISTENT"
    }],
    :networkInterfaces=>[{:network=>"global/networks/default"}]
  }
end
```

The `bootstrap_options` contain unnecessary duplicated information (like zone and machine name) which should be refactored out.  I am experiencing an issue with my Google API call that I don't want to spend more time troubleshooting without help.

## TODO items

* Update the Credentials to read from the file system or environmental variables - it is a big no-no to put credentials in the cookbook.
* Put in sane defaults for the machine resource - you should be able to successfully create a machine with only `machine 'test'`.
* DRY up the client request/response logic.