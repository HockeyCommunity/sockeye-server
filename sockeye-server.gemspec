# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "sockeye-server"
  spec.version       = "0.1.1"
  spec.authors       = ["Jack Hayter"]
  spec.email         = ["jack.hayter@googlemail.com"]

  spec.summary       = "A websockets based server for payload delivery to clients"
  spec.description   = "A websockets based real-time message solution for delivering messages to specific clients"
  spec.homepage      = "https://github.com/HockeyCommunity/sockeye-server"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_runtime_dependency 'eventmachine', '~> 1.2', '>= 1.2.3'
  spec.add_runtime_dependency 'websocket-eventmachine-server', '~> 1.0', '>= 1.0.1'
end
