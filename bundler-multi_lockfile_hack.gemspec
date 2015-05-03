Gem::Specification.new do |s|
    s.name        = 'bundler-multi_lockfile_hack'
    s.version     = '0.0.0'
    s.summary     = "Hola!"
    s.description = "Hack to make bundler generate multiple lockfiles (e.g. for a particular group or sub-gemfile)."
    s.authors     = ["Cheney Lin"]
    s.email       = 'lincheney@gmail.com'
    s.files       = ["bundler/multi_lockfile_hack.rb"]
    s.homepage    = 'https://github.com/lincheney/bundler-multi-lockfile-hack'
    s.license     = 'MIT'

    s.add_development_dependency "rake"
    s.add_development_dependency 'rspec', "~> 3.1"
end
