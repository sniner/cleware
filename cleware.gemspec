require_relative './lib/sniner/cleware/version'

Gem::Specification.new do |s|
    s.required_ruby_version = '>= 1.9.3'
    s.name        = 'cleware'
    s.version     = Sniner::Cleware::VERSION
    s.date        = '2015-07-16'
    s.summary     = 'Cleware library'
    s.description = 'Library for Cleware USB devices (currently traffic light only)'
    s.authors     = ['Stefan Schönberger']
    s.email       = ['mail@sniner.net']
    s.homepage    = 'https://github.com/sniner/cleware'
    s.license     = 'LGPL-3.0'
    s.files       = Dir.glob('lib/**/*.rb') + Dir.glob('test/*')
    s.add_runtime_dependency 'ffi', '~> 1.9'
end

# vim: et sw=4 ts=4