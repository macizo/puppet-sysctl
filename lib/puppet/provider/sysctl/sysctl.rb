Puppet::Type.type(:sysctl).provide(:sysctl) do
  desc "A provider for sysctl parameters that handles live state, cleans duplicates, and warns about syntax errors."

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
    
    # Validate syntax of target files once
    targets = resources.values.map { |res| res[:target] }.uniq
    targets.each do |target|
      if File.exist?(target)
        File.readlines(target).each_with_index do |line, index|
          stripped = line.strip
          next if stripped.empty? || stripped.start_with?('#') || stripped.start_with?(';')
          unless stripped.include?('=')
            Puppet.warning("sysctl provider: Target file #{target} contains invalid syntax on line #{index + 1}: '#{stripped}'")
          end
        end
      end
    end

    resources.each do | key, value |
      matching_provider = sysctl_instances.find { |inst| inst.name == key }
      if matching_provider
        value.provider = matching_provider
      end
    end
  end

  def exists?
    # 1. Check live system state (from prefetch/instances)
    return false unless @property_hash[:ensure] == :present
    return false if @property_hash[:val] != resource[:val]

    # 2. Check the configuration file state
    target_file = resource[:target]
    return false unless File.exist?(target_file)

    lines = File.readlines(target_file)
    matches = []

    lines.each_with_index do |line, index|
      if line =~ /^\s*#{Regexp.escape(resource[:name])}\s*=\s*(.*)$/
        matches << { index: index, val: $1.strip }
      end
    end

    # If it is missing from the file, has duplicate entries, or has the wrong value:
    return false if matches.size != 1
    return false if matches.first[:val] != resource[:val]

    true
  end

  def create
    # Run 'sysctl -w key=value' to update the running system
    sysctl_cmd('-w', "#{resource[:name]}=#{resource[:val]}")
    
    # Save it to target file, automatically cleaning duplicates
    persist_setting(resource[:name], resource[:val], resource[:target])
    
    @property_hash[:ensure] = :present
    @property_hash[:val] = resource[:val]
  end

  def destroy
    # Clean it out of target file
    remove_setting(resource[:name], resource[:target])
    @property_hash[:ensure] = :absent
  end

  def val
    @property_hash[:val]
  end

  def val=(value)
    # Run 'sysctl -w key=value' to update the running system
    sysctl_cmd('-w', "#{resource[:name]}=#{value}")
    
    # Save it to target file, automatically cleaning duplicates
    persist_setting(resource[:name], value, resource[:target])
    
    @property_hash[:ensure] = :present
    @property_hash[:val] = value
  end

  def remove_setting(name, target)
    return unless File.exist?(target)

    lines = File.readlines(target)
    new_lines = lines.reject do |line|
      line =~ /^\s*#{Regexp.escape(name)}\s*=/
    end

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
