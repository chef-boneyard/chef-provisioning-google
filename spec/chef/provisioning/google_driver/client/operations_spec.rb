require 'chef/provisioning/google_driver/client/global_operations'
require 'chef/provisioning/google_driver/client/zone_operations'
require 'chef/provisioning/google_driver/client/google_compute_error'
require 'chef/provisioning/google_driver/client/operation'
require_relative 'services_helper'

include Chef::Provisioning::GoogleDriver::Client

RSpec.shared_examples 'Operations' do |service_name, client_class|

  include ServicesHelper

  before(:example) do
    setup_service(service_name, ['get'])
    @service_name = service_name
    @operations_client = client_class.new(@google, ServicesHelper::PROJECT,
                                          ServicesHelper::ZONE)
    @operation = Operation.new({body: {name: 'op', status: 'NOT_DONE'}})
  end

  context 'when get is called' do

    def expect_get(status, body)
      expect_call("#{@service_name}.get", {operation: 'op'}, nil, status, body)
    end

    it 'raises an error if the API call failed' do
      expect_get(400, {})
      expect {
        @operations_client.get(@operation)
      }.to raise_error(GoogleComputeError)
    end

    it 'raises an error if the response contains errors' do
      expect_get(200, {error: {errors: [{message: 'failure!'}]}})
      expect {
        @operations_client.get(@operation)
      }.to raise_error(GoogleComputeError)
    end

    it 'returns a valid result if everything goes well' do
      expect_get(200, {name: 'op', status: 'NOT_DONE'})
      operation = @operations_client.get(@operation)
      expect(operation.name).to eq('op')
      expect(operation).not_to be_done
    end

  end

end

RSpec.describe GlobalOperations do

  it_behaves_like 'Operations', 'global_operations', GlobalOperations

end

RSpec.describe ZoneOperations do

  it_behaves_like 'Operations', 'zone_operations', ZoneOperations

end
