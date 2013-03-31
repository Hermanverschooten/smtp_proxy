# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'smtp_proxy/version'

Gem::Specification.new do |gem|
  gem.name          = "smtp_proxy"
  gem.version       = SmtpProxy::VERSION
  gem.authors       = ["Herman verschooten"]
  gem.email         = ["Herman@verschooten.net"]
  gem.description   = %q{Simple SMTP Proxy Server}
  gem.summary       = %q{Proxies SMTP connection to a give server, with support to replace the offered username and password}
  gem.homepage      = "http://www.gratwifi.eu"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
