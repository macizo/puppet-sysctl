# Puppet Sysctl Module

A native, robust Puppet custom type and provider for managing kernel parameters via `sysctl`.

## Motivation

Managing `sysctl` settings is a critical part of system administration and security compliance. While other solutions exist, they often suffer from reliability issues:

### Why this module is better than Augeas-based providers:

* **No More Parsing Failures:** Augeas relies on strict file lenses to map text files to trees. If a configuration file contains unexpected spacing, inline comments, or syntax anomalies, Augeas can fail to parse the file entirely. This native provider uses robust, flexible Regular Expressions to read and parse configurations safely.
* **Automatic Duplicate Cleanup & Self-Healing:** A common bug in Augeas providers is that they can append duplicate configuration lines instead of updating existing ones. This provider scans the entire file. If it finds duplicate entries for a key—even if the value is correct—it flags the resource as out of sync (corrective) and automatically purges all duplicates, keeping only a single, clean line.
* **Flexible Declarations (Title Patterns):** Supports both separated property declarations and compound title declarations, allowing you to write clean manifests and easily structure your Hiera data.
* **Handling Spacing Variations:** Spacing variations like `key=value`, `key = value`, and `key   =   value` are automatically matched, cleaned, and standardized to `key = value`.

---

## Usage

This module is designed to be completely generic and works out of the box with manifests and Hiera.

### Option 1: Compound Title Syntax (Shortest)

You can specify the parameter and its desired value directly in the resource title:

```puppet
sysctl { 'net.ipv4.ip_forward: 1': }
sysctl { 'vm.swappiness: 10': }
```

### Option 2: Explicit Syntax

Alternatively, you can separate the key and the value:

```puppet
sysctl { 'net.ipv4.ip_forward':
  val => '1',
}
```

### Option 3: Hiera Integration (Lambda Loop)

In your Hiera YAML data, define your settings:

```yaml
sysctl::settings:
  net.ipv4.ip_forward: 1
  vm.swappiness: 10
  net.ipv6.conf.all.disable_ipv6: 1
```

And load them in your profile or class using a lambda loop:

```puppet
class sysctl (
  Hash $settings = {},
) {
  $settings.each |String $parameter_name, $value| {
    sysctl { $parameter_name:
      val => String($value),
    }
  }
}
```

---

## Hiera Overrides & Hierarchy

For standard environments, it is recommended to have a **`common.yaml`** file acting as your baseline default configuration. 

You can override these configurations at different levels of your Hiera hierarchy (e.g., role, environment, or node-specific level) using the **Deep Merge** lookup strategy.

### Example Setup

**1. Define default baseline settings in `common.yaml`:**
```yaml
sysctl::settings:
  net.ipv4.ip_forward: 0
  vm.swappiness: 10
```

**2. Define overrides for specific nodes in `nodes/db-server.example.com.yaml`:**
```yaml
sysctl::settings:
  vm.swappiness: 5
```

**3. Load the settings with Deep Merge in `init.pp`:**
Using the `deep` parameter in your lookup tells Puppet to merge the hashes across the hierarchy rather than discarding the baseline:
```puppet
class sysctl {
  # Perform a deep merge lookup across Hiera files
  $settings = lookup('sysctl::settings', Hash, 'deep', {})
  
  $settings.each |String $parameter_name, $value| {
    sysctl { $parameter_name:
      val => String($value),
    }
  }
}
```

Or in hiera:

```yaml
lookup_options:
  sysctl::settings:
    merge: deep
```

In this scenario, `db-server.example.com` will receive `net.ipv4.ip_forward: 0` from common, and `vm.swappiness` will be cleanly overridden to `5`!

---

## Development & Testing

This module includes a full suite of RSpec unit tests.

### Running Tests Locally

1. Install dependencies locally inside the module root:
   ```bash
   bundle config set --local path 'vendor/bundle'
   bundle install
   ```

2. Run the test suite:
   ```bash
   bundle exec rspec
   ```
