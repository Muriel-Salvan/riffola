require File.expand_path('../lib/riffola/version', __FILE__)
require 'date'

Gem::Specification.new do |s|
  s.name = 'riffola'
  s.version = Riffola::VERSION
  s.date = Date.today.to_s
  s.authors = ['Muriel Salvan']
  s.email = ['muriel@x-aeon.com']
  s.summary = 'Riffola - Reading extended RIFF files'
  s.description = 'Library reading an extended RIFF format, supporting huge files. RIFF format is composed of a list of chunks, each chunk being an identifier, an encoded data size, an optional header and chunk data itself. Riffola has ways to deal with RIFF files taking some liberties on the RIFF format (additional headers, wrong chunk size...).'
  s.homepage = 'https://github.com/Muriel-Salvan/riffola'
  s.license = 'BSD-4-Clause'

  s.files = Dir['{bin,lib,spec}/**/*']
  Dir['bin/**/*'].each do |exec_name|
    s.executables << File.basename(exec_name)
  end

  # Development dependencies (tests, debugging)
  # Test framework
  s.add_development_dependency 'rspec'
  # To add simple hex ways to dump strings
  s.add_development_dependency 'hex_string'
  # To debug
  s.add_development_dependency 'byebug'
  # To check code syntax
  s.add_development_dependency 'rubocop'
  # To profile performance
  s.add_development_dependency 'ruby-prof'
end
