require "chef/provisioning/google_driver/driver.rb"

Chef::Provisioning.register_driver_class("google", Chef::Provisioning::GoogleDriver::Driver)
