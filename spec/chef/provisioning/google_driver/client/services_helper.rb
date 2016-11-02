require "ffi_yajl"

# Helper module for testing classes that do calls to the Google API.
module ServicesHelper
  PROJECT = "test-project"
  ZONE = "test-zone"
  DEFAULT_PARAMETERS = { project: PROJECT, zone: ZONE }

  def setup_service(service_name, methods)
    service = double(service_name)
    methods.each do |m|
      allow(service).to receive(m.to_sym).and_return("#{service_name}.#{m}")
    end
    compute = double("compute")
    allow(compute).to receive(service_name.to_sym).and_return(service)
    @google = double("google")
    allow(@google).to receive(:discovered_api).and_return(compute)
  end

  def expect_call(method, parameters, request_body,
                  status, response_body)
    inner_response = double("inner_response")
    allow(inner_response).to receive(:status).and_return(status)
    encoded_body = FFI_Yajl::Encoder.encode(response_body)
    allow(inner_response).to receive(:body).and_return(encoded_body)
    response = double("response")
    allow(response).to receive(:response).and_return(inner_response)
    allow(@google).to receive(:execute).with(
      hash_including(api_method: method,
                     parameters: parameters.merge(DEFAULT_PARAMETERS),
                     body_object: request_body)).and_return(response)
  end
end
