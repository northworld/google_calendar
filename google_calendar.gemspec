# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "google_calendar"
  s.version = "0.6.5"
  s.date = "2022-09-28"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.authors = ["Steve Zich"]
  s.email = "steve.zich@gmail.com"

  s.summary = "A lightweight Google Calendar API wrapper"
  s.description = "A minimal wrapper around the google calendar API"
  s.homepage = "http://northworld.github.io/google_calendar/"
  s.licenses = ["MIT"]

  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")

  s.require_paths = ["lib"]
  s.rubygems_version = "2.7.6"

  s.add_runtime_dependency(%q<addressable>, ["> 2.7.0"])
  s.add_runtime_dependency(%q<signet>, ["~> 0.7"])
  s.add_runtime_dependency(%q<json>, [">= 1.8.3"])
  s.add_runtime_dependency(%q<TimezoneParser>, ">= 0.3", "< 1.1")

  s.add_development_dependency(%q<terminal-notifier-guard>, ["~> 1.6"])
  s.add_development_dependency(%q<rb-fsevent>, ["~> 0.9"])
  s.add_development_dependency(%q<minitest>, ["~> 5.1"])
  s.add_development_dependency(%q<minitest-reporters>, ["~> 1.2"])
  s.add_development_dependency(%q<shoulda-context>, "~> 2.0")
  s.add_development_dependency(%q<bundler>, [">= 1.2"])
  s.add_development_dependency(%q<mocha>, ["~> 1.4"])
  s.add_development_dependency(%q<rake>, [">= 11"])
  s.add_development_dependency(%q<rdoc>, ["> 6.3.1"])
  s.add_development_dependency(%q<dotenv>, ["~> 2.1"])

end
