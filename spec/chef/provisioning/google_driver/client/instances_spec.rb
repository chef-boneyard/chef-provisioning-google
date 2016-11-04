require "chef/provisioning/google_driver/client/instances"
require "chef/provisioning/google_driver/client/google_compute_error"
require_relative "services_helper"

include Chef::Provisioning::GoogleDriver::Client

RSpec.describe Instances do
  include ServicesHelper

  before(:example) do
    setup_service("instances", %w{get insert delete start stop})
    @instances_client = Instances.new(@google, ServicesHelper::PROJECT,
                                      ServicesHelper::ZONE)
  end

  context "when start is called" do

    def expect_start(status, body)
      expect_call("instances.start", { instance: "instance_name" },
                  nil, status, body)
    end

    it "raises an error if the API call failed" do
      expect_start(400, {})
      expect do
        @instances_client.start("instance_name")
      end.to raise_error(GoogleComputeError)
    end

    it "raises an error if the response contains errors" do
      expect_start(200, { error: { errors: [{ message: "failure!" }] } })
      expect do
        @instances_client.start("instance_name")
      end.to raise_error(GoogleComputeError)
    end

    it "returns a valid operation if everything goes well" do
      expect_start(200, { name: "name", status: "LOL" })
      operation = @instances_client.start("instance_name")
      expect(operation.name).to eq("name")
      expect(operation).not_to be_done
    end

  end

  context "when stop is called" do

    def expect_stop(status, body)
      expect_call("instances.stop", { instance: "instance_name" },
                  nil, status, body)
    end

    it "raises an error if the API call failed" do
      expect_stop(400, {})
      expect do
        @instances_client.stop("instance_name")
      end.to raise_error(GoogleComputeError)
    end

    it "raises an error if the response contains errors" do
      expect_stop(200, { error: { errors: [{ message: "failure!" }] } })
      expect do
        @instances_client.stop("instance_name")
      end.to raise_error(GoogleComputeError)
    end

    it "returns a valid operation if everything goes well" do
      expect_stop(200, { name: "name", status: "LOL" })
      operation = @instances_client.stop("instance_name")
      expect(operation.name).to eq("name")
      expect(operation).not_to be_done
    end

  end

  context "when delete is called" do

    def expect_delete(status, body)
      expect_call("instances.delete", { instance: "instance_name" },
                  nil, status, body)
    end

    it "raises an error if the API call failed" do
      expect_delete(400, {})
      expect do
        @instances_client.delete("instance_name")
      end.to raise_error(GoogleComputeError)
    end

    it "raises an error if the response contains errors" do
      expect_delete(200, { error: { errors: [{ message: "failure!" }] } })
      expect do
        @instances_client.delete("instance_name")
      end.to raise_error(GoogleComputeError)
    end

    it "returns a valid operation if everything goes well" do
      expect_delete(200, { name: "name", status: "LOL" })
      operation = @instances_client.delete("instance_name")
      expect(operation.name).to eq("name")
      expect(operation).not_to be_done
    end

  end

  context "when create is called" do

    def expect_create(status, body)
      expect_call("instances.insert", {}, { some_option: 123 },
                  status, body)
    end

    it "raises an error if the API call failed" do
      expect_create(400, {})
      expect do
        @instances_client.create(some_option: 123)
      end.to raise_error(GoogleComputeError)
    end

    it "raises an error if the response contains errors" do
      expect_create(200, { error: { errors: [{ message: "failure!" }] } })
      expect do
        @instances_client.create(some_option: 123)
      end.to raise_error(GoogleComputeError)
    end

    it "returns a valid operation if everything goes well" do
      expect_create(200, { name: "name", status: "DONE" })
      operation = @instances_client.create(some_option: 123)
      expect(operation.name).to eq("name")
      expect(operation).to be_done
    end

  end

  context "when get is called" do

    def expect_get(status, body)
      expect_call("instances.get", { instance: "instance_name" },
                  nil, status, body)
    end

    it 'returns nil if the instance couldn\'t be found' do
      expect_get(404, {})
      @instances_client.get("instance_name")
    end

    it "raises an error if the API call failed" do
      expect_get(400, {})
      expect do
        @instances_client.get("instance_name")
      end.to raise_error(GoogleComputeError)
    end

    it "raises an error if the response contains errors" do
      expect_get(200, { error: { errors: [{ message: "failure!" }] } })
      expect do
        @instances_client.get("instance_name")
      end.to raise_error(GoogleComputeError)
    end

    it "returns a valid instance if everything goes well" do
      networkInterface = { accessConfigs: [{ natIP: "ip" }] }
      expect_get(200, {
                   name: "instance_name",
                   id: "instance_id",
                   status: "RUNNING",
                   networkInterfaces: [networkInterface],
                 })
      instance = @instances_client.get("instance_name")
      expect(instance.name).to eq("instance_name")
      expect(instance.id).to eq("instance_id")
      expect(instance.status).to eq("RUNNING")
      expect(instance).to be_running
      expect(instance).not_to be_stopped
      expect(instance).not_to be_stopping
      expect(instance).not_to be_terminated
      expect(instance.determine_remote_host).to eq("ip")
    end

  end

  context "when wait_for_status is called" do

    def expect_get(name, body)
      expect_call("instances.get", { instance: name },
                  nil, 200, body)
    end

    before(:example) do
      @action_handler = double("action_handler")
      expect(@action_handler).to receive(:report_progress)
    end

    it "returns a valid instance if everything goes well" do
      expect_get("instance_name", { name: "instance_name2" })
      instance = @instances_client.get("instance_name")
      expect_get("instance_name2", { name: "instance_name2", status: "RUNNING" })
      running_instance = @instances_client.wait_for_status(@action_handler,
                                                           instance, "RUNNING")
      expect(running_instance.name).to eq("instance_name2")
    end
  end

end
