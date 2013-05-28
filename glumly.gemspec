# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'glumly/version'

Gem::Specification.new do |spec|
  spec.name          = "glumly"
  spec.version       = Glumly::VERSION
  spec.authors     = ["asatou"]
  spec.email       = ["asatou@val.co.jp"]
  spec.summary     = %q{UMLクラス図ジェネレーター.}
  spec.description = %q{UMLクラス図を生成. DOT言語で.}
  spec.homepage      = ""
  spec.license       = ""

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]
end
