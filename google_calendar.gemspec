# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "google_calendar"
  s.version = "0.4.0"
  s.date = "2014-11-17"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.authors = ["Steve Zich"]
  s.email = "steve.zich@gmail.com"

  s.summary = "A lightweight Google calendar API wrapper"
  s.description = "A minimal wrapper around the google calendar API"
  s.homepage = "http://github.com/northworld/google_calendar"
  s.licenses = ["MIT"]  
  
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.24"

  s.add_runtime_dependency(%q<signet>, [">= 0.5.1"])
  s.add_runtime_dependency(%q<addressable>, [">= 2.2.2"])

  s.add_development_dependency(%q<minitest>, ["~> 5.1"])
  s.add_development_dependency(%q<shoulda-context>, [">= 0"])
  s.add_development_dependency(%q<bundler>, [">= 1.0.0"])
  s.add_development_dependency(%q<mocha>, [">= 0"])
  s.add_development_dependency(%q<rake>, ["> 10"])
  s.add_development_dependency(%q<rdoc>, [">= 3"])
  
end