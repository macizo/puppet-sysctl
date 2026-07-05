require 'spec_helper'

describe Puppet::Type.type(:sysctl) do
  
  # Group 1: Testing validations for parameters
  describe "when validating parameters" do
    it "should accept a valid name" do
      expect {
        Puppet::Type.type(:sysctl).new(:name => 'net.ipv4.ip_forward', :val => '1')
      }.not_to raise_error
    end

    it "should reject a name with invalid characters" do
      expect {
        Puppet::Type.type(:sysctl).new(:name => 'invalid-name!', :val => '1')
      }.to raise_error(Puppet::Error)
    end
  end

  # Group 2: Testing title parsing (title_patterns)
  describe "when parsing titles" do
    it "should parse compound titles (key: value) correctly" do
      resource = Puppet::Type.type(:sysctl).new(:title => 'net.ipv4.ip_forward: 1')
      expect(resource[:name]).to eq('net.ipv4.ip_forward')
      expect(resource[:val]).to eq('1')
    end

    it "should fallback to simple titles when val is provided separately" do
      resource = Puppet::Type.type(:sysctl).new(:title => 'net.ipv4.ip_forward', :val => '1')
      expect(resource[:name]).to eq('net.ipv4.ip_forward')
      expect(resource[:val]).to eq('1')
    end
  end
end
