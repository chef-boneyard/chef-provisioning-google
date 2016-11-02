require 'chef/provisioning/google_driver/client/projects'
require 'chef/provisioning/google_driver/client/google_compute_error'
require_relative 'services_helper'

include Chef::Provisioning::GoogleDriver::Client

RSpec.describe Projects do

  FINGERPRINT = "asdf"
  ITEMS = [{key: 'sshKeys', value: "testuser1:key1\ntestuser2:key2"},
           {key: 'chef-provisioning-google_ssh-mappings',
             value: "testuser3:key3\ntestuser4:key4"}]
  SSH_KEYS = [['testuser1', 'key1'], ['testuser2', 'key2']]
  SSH_MAPPINGS = {'testuser3' => 'key3', 'testuser4' => 'key4'}

  include ServicesHelper

  before(:example) do
    setup_service('projects', ['get', 'set_common_instance_metadata'])
    @projects_client = Projects.new(@google, ServicesHelper::PROJECT,
                                    ServicesHelper::ZONE)
  end

  def expect_get(status, body)
    expect_call('projects.get', {}, nil, status, body)
  end

  def expect_successful_get
    expect_get(200, {name: 'name', commonInstanceMetadata: {
                   fingerprint: FINGERPRINT,
                   items: ITEMS
                 }})
  end

  context 'when get is called' do

    it 'raises an error if the API call failed' do
      expect_get(400, {})
      expect {
        @projects_client.get
      }.to raise_error(GoogleComputeError)
    end

    it 'raises an error if the response contains errors' do
      expect_get(200, {error: {errors: [{message: 'failure!'}]}})
      expect {
        @projects_client.get
      }.to raise_error(GoogleComputeError)
    end

    it 'returns a valid result if everything goes well' do
      expect_successful_get
      metadata = @projects_client.get
      expect(metadata).not_to be_changed
      expect(metadata.ssh_keys).to eq(SSH_KEYS)
      expect(metadata.ssh_mappings).to eq(SSH_MAPPINGS)
      expect(metadata).not_to be_changed
    end

  end

  context 'when set_common_instance_metadata is called' do
    before(:example) do
      expect_successful_get
      @metadata = @projects_client.get
    end

    def expect_set_common_instance_metadata(ssh_keys, ssh_mappings, status,
                                            response_body)
      request_body = {
        items: [{key: 'chef-provisioning-google_ssh-mappings',
                  value: ssh_mappings},
                {key: 'sshKeys', value: ssh_keys}],
        fingerprint: FINGERPRINT
      }
      expect_call('projects.set_common_instance_metadata', {}, request_body,
                  status, response_body)
    end

    it 'does nothing if the metadata hasn\'t been changed' do
      @metadata.ssh_keys
      @metadata.ssh_mappings
      @projects_client.set_common_instance_metadata(@metadata)
    end

    it 'raises an error if the API call failed' do
      expect_set_common_instance_metadata(
        "testuser1:key1\ntestuser2:key2\nfoo:bar",
        "testuser3:key3\ntestuser4:key4",
        400,
        {})
      # Change something such that the API call actually happens.
      @metadata.ensure_key('foo', 'bar')
      expect {
        @projects_client.set_common_instance_metadata(@metadata)
      }.to raise_error(GoogleComputeError)
    end

    it 'raises an error if the response contains errors' do
      expect_set_common_instance_metadata(
        "testuser1:key1\ntestuser2:key2\nfoo:bar",
        "testuser3:key3\ntestuser4:key4",
        200, 
        {error: {errors: [{message: 'failure!'}]}})
      # Change something such that the API call actually happens.
      @metadata.ensure_key('foo', 'bar')
      expect {
        @projects_client.set_common_instance_metadata(@metadata)
      }.to raise_error(GoogleComputeError)
    end

    it 'returns a valid result if an ssh key is added successfully' do
      expect_set_common_instance_metadata(
        "testuser1:key1\ntestuser2:key2\nfoo:bar",
        "testuser3:key3\ntestuser4:key4",
        200,
        {status: 'DONE'})
      @metadata.ensure_key('foo', 'bar')
      expect(@metadata).to be_changed
      operation = @projects_client.set_common_instance_metadata(@metadata)
      expect(operation).to be_done
    end

    it 'returns a valid result if an ssh mapping is added successfully' do
      expect_set_common_instance_metadata(
        "testuser1:key1\ntestuser2:key2",
        "testuser3:key3\ntestuser4:key4\nfoo:bar",
        200,
        {status: 'DONE'})
      @metadata.set_ssh_mapping('foo', 'bar')
      expect(@metadata).to be_changed
      operation = @projects_client.set_common_instance_metadata(@metadata)
      expect(operation).to be_done
    end

    it 'returns a valid result if an ssh key is removed successfully' do
      expect_set_common_instance_metadata(
        "testuser1:key1",
        "testuser3:key3\ntestuser4:key4",
        200,
        {status: 'DONE'})
      @metadata.delete_ssh_key('key2')
      expect(@metadata).to be_changed
      operation = @projects_client.set_common_instance_metadata(@metadata)
      expect(operation).to be_done
    end

    it 'returns a valid result if an ssh mapping is removed successfully' do
      expect_set_common_instance_metadata(
        "testuser1:key1\ntestuser2:key2",
        "testuser3:key3",
        200,
        {status: 'DONE'})
      @metadata.delete_ssh_mapping('testuser4')
      expect(@metadata).to be_changed
      operation = @projects_client.set_common_instance_metadata(@metadata)
      expect(operation).to be_done
    end

  end

end
