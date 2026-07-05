Puppet::Type.type(:sysctl).provide(:sysctl) do
  desc "A provider for sysctl."

  commands :sysctl_cmd => 'sysctl'

  def self.instances
    begin
      output = sysctl_cmd('-a')
    rescue Puppet::ExecutionFailure => e
      Puppet.warning("Could not execute sysctl -a: #{e}")
      return []
    end  

    resources = []

    output.each_line do |line| 
      if line =~ /^\s*([a-zA-Z0-9_.-]+)\s*=\s*(.*)$/
        key = $1.strip
        value = $2.strip

        resources << new(
          :name   => key,
          :val    => value,
          :ensure => :present
        )
      end
    end
    resources      
  end

  def self.prefetch(resources)
    sysctl_instances = instances
    resources.each do | key, value |
      # Find the provider instance on the system that has the matching key name
      matching_provider = sysctl_instances.find { |inst| inst.name == key }
      
      # If we found it, attach it to the catalog resource
      if matching_provider
        value.provider = matching_provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    # Run 'sysctl -w key=value' to update the running system
    sysctl_cmd('-w', "#{resource[:name]}=#{resource[:val]}")
    
    # Save it to /etc/sysctl.conf
    persist_setting(resource[:name], resource[:val], resource[:target])
    
    @property_hash[:ensure] = :present
    @property_hash[:val] = resource[:val]
  end

  def destroy
    # Clean it out of /etc/sysctl.conf
    remove_setting(resource[:name], resource[:target])
    @property_hash[:ensure] = :absent
  end

  def val
    @property_hash[:val]
  end

  def val=(value)
    # Run 'sysctl -w key=value' to update the running system
    sysctl_cmd('-w', "#{resource[:name]}=#{value}")
    
    # Save it to /etc/sysctl.conf
    persist_setting(resource[:name], value, resource[:target])
    
    @property_hash[:ensure] = :present
    @property_hash[:val] = resource[:val]

    @property_hash[:val] = value
  end

  def remove_setting(name, target)
    return unless File.exist?(target)

    # 1. Read all lines
    lines = File.readlines(target)

    # 2. Reject any line that matches our key (keeping everything else)
    new_lines = lines.reject do |line|
      line =~ /^\s*#{Regexp.escape(name)}\s*=/
    end

    # 3. Write the remaining clean lines back to the file
    File.open(target, 'w') do |f|
      new_lines.each { |line| f.write(line) }
    end
  end

  def persist_setting(name, value, target)
    lines = []
    active_indices = []
    if File.exists?(target)
      lines = File.readlines(target)
    end

    lines.each_with_index do |line, index|
      if line =~ /^\s*#{Regexp.escape(name)}\s*=/
        active_indices << index
      end
    end

    if active_indices.empty?
      lines << name + " = " + value + "\n"  
    else
      last_index = active_indices.pop
      lines[last_index] = name + " = " + value + "\n"
      active_indices.reverse_each do |dup_index| 
        lines.delete_at(dup_index)
      end
    end
    File.open(target, 'w') { |f| lines.each { |l| f.write(l) } } 
  end
end
