ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)

require 'bundler/setup' # Set up gems listed in the Gemfile.

# If you see this error raised, then you must be using a newer version of Ruby
# than what this has been tested with in the past. It may have fixed the bug in
# Ruby that makes bootsnap incompatible with ARM. If you have a Chromebook,
# Raspberry Pi, or something that has an ARM processor, try removing the
# `unless` statement below on that machine with Ruby 2.4.1 to repro the issue,
# and Ruby 2.6 to see if the issue has been fixed.
if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.6')
  raise 'Opportunity to improve this'
end

unless File.exists?("/proc/cpuinfo") && File.read("/proc/cpuinfo").include?("ARMv7")
  require 'bootsnap/setup'
end
