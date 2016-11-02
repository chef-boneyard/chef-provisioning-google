$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'chef/provisioning/google_driver/version'

Gem::Specification.new do |s|
  s.name = 'chef-provisioning-google'
  s.version = Chef::Provisioning::GoogleDriver::VERSION
  s.platform = Gem::Platform::RUBY
  s.extra_rdoc_files = ['README.md', 'LICENSE']
  s.summary = 'Provisioner for creating google containers in Chef Provisioning.'
  s.description = s.summary
  s.author = 'Sean OMeara'
  s.email = 'sean@sean.io'
  s.homepage = 'https://github.com/chef/chef-provisioning-google'

  s.add_dependency 'chef', '~> 12.1', "!= 12.4.0"  # 12.4.0 is incompatible.
  s.add_dependency 'chef-provisioning', '>= 1.0'
  s.add_dependency 'google-api-client', '< 0.9', '>= 0.6.2'
  s.add_dependency 'ffi-yajl', '~> 2.2'
  s.add_dependency 'retryable', '~> 2.0'

  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-byebug'

  s.bindir       = 'bin'
  s.executables  = %w( )

  s.require_path = 'lib'
  s.files = %w(Rakefile LICENSE README.md) + Dir.glob('{distro,lib,tasks,spec}/**/*', File::FNM_DOTMATCH).reject { |f| File.directory?(f) }
end
