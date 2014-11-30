# coding: utf-8
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "site_watcher/version"

Gem::Specification.new do |spec|
  spec.name          = "site_watcher"
  spec.version       = SiteWatcher::VERSION
  spec.authors       = ["Alex Genco"]
  spec.email         = ["alexgenco@gmail.com"]
  spec.summary       = %q{Periodically monitor a website}
  spec.homepage      = "https://github.com/alexgenco/site_watcher"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri"
  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"
end
