require "chef/provisioning/google_driver"

# TODO stuff credentials in config.rb or knife.rb if there is not an existing pattern in
# the SDK for loading credentials - https://developers.google.com/cloud/sdk/gcloud/reference/compute/?hl=en_US
with_driver "google:us-central1-f:inspired-bebop-234",
  :google_credentials => {
    :json_key_path => "",
    :google_client_email => "",
  }

google_key_pair "chef_default" do
  private_key_path "google_default"
  public_key_path "google_default.pub"
end

machine "test" do
  machine_options key_name: "google_default"
  action [:converge, :destroy]
end

# load_balancer "test_lb" do
#   machines ['test']
# end
