Encoding.default_external = Encoding::UTF_8
reference = ENV.fetch('GRONGIGO_RUBY_ROOT', File.expand_path('../.reference/grongigo', __dir__))
$LOAD_PATH.unshift File.join(reference, 'lib')
require 'grongigo'

source = File.read(ARGV.fetch(0), encoding: 'UTF-8')
compiler = Grongigo::Compiler.new(output_tokens: true, output_ast: true)
code = compiler.compile(source)
if code
  puts '=== C ==='
  puts code
else
  puts '=== Errors ==='
  puts compiler.errors
end
