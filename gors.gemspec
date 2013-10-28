Gem::Specification.new do |s|
  s.name        = 'gors'
  s.version     = '0.0.1'
  s.date        = '2013-10-20'
  s.summary     = "Great Opensource Rack Server"
  s.description = "A web framework built on top of Rack, it has the simplicity of sinatra and the structure of rails"
  s.authors     = ["Bram Vandenbogaerde"]
  s.email       = 'bram.vandenbogaerde@gmail.com'
  s.files       = ["lib/gors.rb"]
  s.homepage    =
    'http://rubygems.org/gems/gors'
  s.license = "MIT"
  s.add_runtime_dependency "tilt"
  s.add_runtime_dependency "json"
  s.add_runtime_dependency "rack"
end