# Standalone test script for the sysctl provider's file parsing logic.
# This script does not require Puppet to be installed; it stubs the minimal Puppet API needed to load the provider.

require 'tempfile'
require 'fileutils'

# 1. Stub the Puppet API so the provider file can load successfully
module Puppet
  class Type
    def self.type(name)
      @types ||= {}
      @types[name] ||= Class.new do
        def self.provide(provider_name, &block)
          # Create a new provider class and evaluate the block inside it
          provider_class = Class.new(Provider)
          provider_class.class_eval(&block)
          @providers ||= {}
          @providers[provider_name] = provider_class
        end
        def self.provider(name)
          @providers[name]
        end
      end
    end

    def self.newtype(name, &block)
      # Stub newtype
    end
  end

  class Provider
    attr_accessor :resource, :property_hash
    def initialize(hash = {})
      @property_hash = hash
    end
    def self.desc(msg)
    end
    def self.commands(hash)
    end
  end

  def self.warning(msg)
    puts "WARNING: #{msg}"
  end
end

# 2. Load the provider file
provider_file = File.expand_path('../../lib/puppet/provider/sysctl/sysctl.rb', __FILE__)
require provider_file

# Retrieve the stubbed provider class
SysctlProvider = Puppet::Type.type(:sysctl).provider(:sysctl)

# Helper to run tests
def assert_equal(expected, actual, test_name)
  if expected == actual
    puts "✅ PASS: #{test_name}"
  else
    puts "❌ FAIL: #{test_name}"
    puts "   Expected: #{expected.inspect}"
    puts "   Got:      #{actual.inspect}"
  end
end

# Test case suite
def run_tests
  puts "Running parser logic tests..."

  # Create a temporary file to act as /etc/sysctl.conf
  temp_file = Tempfile.new('sysctl_conf_test')
  target_path = temp_file.path

  # Define initial buggy content (spacing errors, duplicates, comments)
  initial_content = <<~EOF
    # Some initial comments
    net.ipv4.ip_forward = 0
    
    # Another comment line
    net.ipv4.ip_forward=0
    net.ipv6.conf.all.forwarding   =   0
    
    # An active key with weird spacing
    fs.file-max=100000
    net.ipv4.ip_forward   = 0
  EOF

  begin
    # Test 1: Updating a value and clearing duplicates
    File.write(target_path, initial_content)
    
    # Instantiate the provider
    provider = SysctlProvider.new
    
    # Run the persist_setting helper (updates net.ipv4.ip_forward to 1)
    provider.send(:persist_setting, 'net.ipv4.ip_forward', '1', target_path)

    resulting_content = File.read(target_path)
    
    # Expected result: 
    # - The comments should still be there.
    # - All duplicate active lines for net.ipv4.ip_forward should be removed.
    # - Only the last occurrence of net.ipv4.ip_forward should remain and be set to 1.
    expected_content = <<~EOF
      # Some initial comments
      
      # Another comment line
      net.ipv6.conf.all.forwarding   =   0
      
      # An active key with weird spacing
      fs.file-max=100000
      net.ipv4.ip_forward = 1
    EOF

    assert_equal(expected_content, resulting_content, "Clear duplicates and update value")

    # Test 2: Removing a key entirely
    provider.send(:remove_setting, 'fs.file-max', target_path)
    resulting_content_after_remove = File.read(target_path)
    
    expected_after_remove = <<~EOF
      # Some initial comments
      
      # Another comment line
      net.ipv6.conf.all.forwarding   =   0
      
      # An active key with weird spacing
      net.ipv4.ip_forward = 1
    EOF

    assert_equal(expected_after_remove, resulting_content_after_remove, "Remove key and clean up spacing variations")

    # Test 3: Adding a completely new key
    provider.send(:persist_setting, 'vm.swappiness', '10', target_path)
    resulting_content_after_add = File.read(target_path)
    
    expected_after_add = expected_after_remove + "vm.swappiness = 10\n"
    assert_equal(expected_after_add, resulting_content_after_add, "Add new setting to the end of the file")

  ensure
    # Cleanup temporary file
    temp_file.close
    temp_file.unlink
  end
end

run_tests
