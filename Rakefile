require "bundler"
require "bundler/gem_tasks"

task default: [:spec, :style]

begin
  require "chefstyle"
  require "rubocop/rake_task"

  desc "Run Ruby style checks"
  RuboCop::RakeTask.new(:style)
rescue LoadError => e
  puts ">>> Gem load error: #{e}, omitting #{task.name}" unless ENV["CI"]
end

begin
  desc "Run rspec"
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError => e
  puts ">>> Gem load error: #{e}, omitting #{task.name}" unless ENV["CI"]
end
