# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = 'fluent-plugin-stackdriver-v1-metrics'
  gem.version       = '0.4.0'
  gem.authors       = ['Alex Yamauchi']
  gem.email         = ['oss@hotschedules.com']
  gem.homepage      = 'https://github.com/bodhi-space/fluent-plugin-stackdriver-v1-metrics'
  gem.summary       = %q{A Fluentd buffered output plugin to send metrics to StackDriver using the V1 (pre-Google) API}
  gem.description   = gem.summary + '.'
  gem.files         = `git ls-files`.split($\)
  gem.require_paths = ['lib']
  gem.license       = 'Apache-2.0'
  gem.add_runtime_dependency 'fluentd', '>= 0.10.0'
  gem.add_runtime_dependency 'stackdriver', '< 0.3.0'
  gem.signing_key = File.expand_path('~/certs/oss@hotschedules.com.key') if $0 =~ /gem\z/
  gem.cert_chain    = %w[certs/oss@hotschedules.com.cert]
end
