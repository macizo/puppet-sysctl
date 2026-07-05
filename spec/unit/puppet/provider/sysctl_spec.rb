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
      initial_content = "net.ipv4.ip_forward\t=\t0\n"
      File.write(target, initial_content)

      provider.persist_setting('net.ipv4.ip_forward', '1', target)
      
      expect(File.read(target)).to eq("net.ipv4.ip_forward = 1\n")
    end

    it "should ignore full-line comments and empty lines" do
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
      initial_content = <<~EOF
        net.ipv4.ip_forward = 0
        # intermediary comment
        net.ipv4.ip_forward = 0
      EOF
      File.write(target, initial_content)

      provider.persist_setting('net.ipv4.ip_forward', '1', target)

      expected = <<~EOF
        # intermediary comment
        net.ipv4.ip_forward = 1
      EOF
      expect(File.read(target)).to eq(expected)
    end

    it "should clean up duplicate keys when removing a setting" do
      initial_content = <<~EOF
        net.ipv4.ip_forward = 1
        net.ipv4.ip_forward = 0
      EOF
      File.write(target, initial_content)

      provider.remove_setting('net.ipv4.ip_forward', target)

      expect(File.read(target)).to eq("")
    end
  end

  describe "exists? method" do
    let(:resource) do
      Puppet::Type.type(:sysctl).new(
        :name   => 'net.ipv4.ip_forward',
        :val    => '0',
        :target => target
      )
    end
    let(:prov) { resource.provider }

    before(:each) do
      # Set up default property hash (simulates prefetch/instances loading state)
      prov.instance_variable_set(:@property_hash, {
        :ensure => :present,
        :val    => '0'
      })
    end

    it "should return true if live value matches target value and file has exactly one clean setting" do
      File.write(target, "net.ipv4.ip_forward = 0\n")
      expect(prov.exists?).to be true
    end

    it "should return false if live value is different from target value" do
      prov.instance_variable_set(:@property_hash, {
        :ensure => :present,
        :val    => '1'
      })
      File.write(target, "net.ipv4.ip_forward = 0\n")
      expect(prov.exists?).to be false
    end

    it "should return false if target file is missing" do
      # Remove temp file
      temp_file.close
      temp_file.unlink
      expect(prov.exists?).to be false
    end

    it "should return false if target file is empty" do
      File.write(target, "")
      expect(prov.exists?).to be false
    end

    it "should return false if target file contains duplicates" do
      File.write(target, "net.ipv4.ip_forward = 0\nnet.ipv4.ip_forward = 0\n")
      expect(prov.exists?).to be false
    end
  end
end
