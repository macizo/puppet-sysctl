require 'spec_helper'
require 'tempfile'

describe Puppet::Type.type(:sysctl).provider(:sysctl) do
  let(:provider) { Puppet::Type.type(:sysctl).provider(:sysctl).new }
  let(:temp_file) { Tempfile.new('sysctl_conf') }
  let(:target) { temp_file.path }

  after(:each) do
    temp_file.close
    temp_file.unlink
  end

  describe "when parsing and persisting settings" do
    it "should handle different whitespaces and tabs around =" do
      # 1. Test different spacing (spaces and tabs)
      initial_content = "net.ipv4.ip_forward\t=\t0\n"
      File.write(target, initial_content)

      provider.persist_setting('net.ipv4.ip_forward', '1', target)
      
      expect(File.read(target)).to eq("net.ipv4.ip_forward = 1\n")
    end

    it "should ignore full-line comments and empty lines" do
      # 2. Test full-line comments and empty lines are preserved
      initial_content = <<~EOF
        # This is a comment
        
        net.ipv4.ip_forward = 0
      EOF
      File.write(target, initial_content)

      provider.persist_setting('net.ipv4.ip_forward', '1', target)

      expected = <<~EOF
        # This is a comment
        
        net.ipv4.ip_forward = 1
      EOF
      expect(File.read(target)).to eq(expected)
    end

    it "should clean up duplicate keys, keeping only the last one" do
      # 3. Test duplicates cleanup
      initial_content = <<~EOF
        net.ipv4.ip_forward = 0
        # intermediary comment
        net.ipv4.ip_forward = 0
      EOF
      File.write(target, initial_content)

      provider.persist_setting('net.ipv4.ip_forward', '1', target)

      # Expect only the last occurrence to remain, and the first to be deleted
      expected = <<~EOF
        # intermediary comment
        net.ipv4.ip_forward = 1
      EOF
      expect(File.read(target)).to eq(expected)
    end

    it "should clean up duplicate keys when removing a setting" do
      # 4. Test duplicate removal on delete
      initial_content = <<~EOF
        net.ipv4.ip_forward = 1
        net.ipv4.ip_forward = 0
      EOF
      File.write(target, initial_content)

      provider.remove_setting('net.ipv4.ip_forward', target)

      expect(File.read(target)).to eq("")
    end
  end
end