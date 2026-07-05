# @summary Simple sysctl entries management
#
# Assigns given sysctl key a defined value and target file
#
# @example
#   include sysctl
#
# @param settings
#   Hash containing sysctl configuration keys and its values
#
# @param target
#   Optional custom file path to persist the sysctl settings into
#
class sysctl (
  Hash $settings = {},
  Optional[Stdlib::Absolutepath] $target = undef,
) {
  # Loop through the settings hash using a lambda loop
  $settings.each |String $parameter_name, $value| {
    if $target {
      sysctl { $parameter_name:
        val    => String($value),
        target => $target,
      }
    } else {
      sysctl { $parameter_name:
        val => String($value),
      }
    }
  }
}
