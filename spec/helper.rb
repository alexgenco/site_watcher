require "rubygems"
require "bundler/setup"
require "site_watcher"
require "timeout"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed

  config.around do |spec|
    Timeout.timeout(3) { spec.run }
  end
end
