Puppet::Type.newtype(:sysctl) do
  @doc = "Manages kernel parameters using the sysctl command and persists them."

  ensurable
  
  newparam(:name, :namevar => true) do
    desc "The name of the sysctl parameter."
    
    validate do |value|
      unless value =~ /^[a-zA-Z0-9_.-]+$/
        raise ArgumentError, "Invalid sysctl parameter name: '#{value}'"
      end
    end
  end

  def self.title_patterns
    [
      # Pattern 1: Matches 'net.ipv4.ip_forward: 1'
      # Captures key name in group 1, and value in group 2
      [
        /^((?:fs|kernel|net|vm)(?:\.[a-z0-9_]+)+):\s*(-?[0-9]+)$/,
        [
          [:name, lambda { |x| x.strip }],
          [:val,  lambda { |x| x.strip }]
        ]
      ],
      # Pattern 2: Fallback if they only specify the name
      # e.g., 'net.ipv4.ip_forward' (and pass 'val' as a property)
      [
        /^((?:fs|kernel|net|vm)(?:\.[a-z0-9_]+)+)$/,
        [
          [:name, lambda { |x| x.strip }]
        ]
      ]
    ]
  end

  newproperty(:val) do
    desc "The value to set."
    
    validate do |value|
      if value.to_s.strip.empty?
        raise ArgumentError, "A value must be provided for the sysctl parameter"
      end
    end

    munge do |value|
      value.to_s.strip
    end
  end

  newparam(:target) do
    desc "The configuration file path."
    defaultto '/etc/sysctl.conf'
    
    validate do |value|
      unless value =~ %r{^/[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*$}
        raise ArgumentError, 'Invalid absolute path'
      end
    end
  end
end
