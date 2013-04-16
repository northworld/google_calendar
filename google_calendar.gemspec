# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "google_calendar"
  s.version = "0.3.0"
  s.date = "2013-04-15"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=

  s.authors = ["Steve Zich"]
  s.email = "steve.zich@gmail.com"

  s.summary = "A lightweight google calendar API wrapper"
  s.description = "A minimal wrapper around the google calendar API, which uses nokogiri for fast parsing."
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


  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<nokogiri>, [">= 1.4.4"])
      s.add_runtime_dependency(%q<addressable>, [">= 2.2.2"])
      s.add_development_dependency(%q<shoulda>, [">= 0"])
      s.add_development_dependency(%q<bundler>, [">= 1.0.0"])
      s.add_development_dependency(%q<mocha>, [">= 0"])
    else
      s.add_dependency(%q<nokogiri>, [">= 1.4.4"])
      s.add_dependency(%q<addressable>, [">= 2.2.2"])
      s.add_dependency(%q<shoulda>, [">= 0"])
      s.add_dependency(%q<bundler>, [">= 1.0.0"])
      s.add_dependency(%q<mocha>, [">= 0"])
    end
  else
    s.add_dependency(%q<nokogiri>, [">= 1.4.4"])
    s.add_dependency(%q<addressable>, [">= 2.2.2"])
    s.add_dependency(%q<shoulda>, [">= 0"])
    s.add_dependency(%q<bundler>, [">= 1.0.0"])
    s.add_dependency(%q<mocha>, [">= 0"])
  end
end

