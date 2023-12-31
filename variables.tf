# certbot
variable "certbot" {
  type = object(
    {
      agree_tos    = bool
      staging      = optional(bool)
      email        = string
      http_01_port = optional(number)
    }
  )
  description = "Certbot config"
  default     = null
}

# lldap
variable "image" {
  type = object(
    {
      name    = optional(string, "docker.io/nitnelave/lldap")
      version = optional(string, "latest")
    }
  )
  description = "Lldap container image"
  default = {
    name    = "docker.io/nitnelave/lldap"
    version = "stable"
  }
  nullable = false
}

variable "external_fqdn" {
  type        = string
  description = "FQDN to access Lldap"
}

variable "jwt_secret" {
  type        = string
  description = "Lldap JWT secret"
  sensitive   = true
}

variable "ldap_user_pass" {
  type        = string
  description = "Lldap user password"
  sensitive   = true
}

variable "ldap_base_dn" {
  type        = string
  description = "Lldap base distinguished name (DN)"
}

variable "port" {
  type        = number
  description = "Ldap port"
  default     = null
}

variable "cidr_sources" {
  type        = list(string)
  description = "Cidr of sources allowed in firewall to lldap port"
  default     = []
  nullable    = false
}

variable "cpus_limit" {
  type        = number
  description = "Number of CPUs to limit the container"
  default     = 0
}

variable "memory_limit" {
  type        = string
  description = "Amount of memory to limit the container"
  default     = ""
  nullable    = false
}

variable "backup_script_additiona_block" {
  type        = string
  description = "Additional block to add to backup script"
  default     = ""
  nullable    = false
}

variable "backup_task_on_calendar" {
  type        = string
  description = "Backup task on calendar value. See systemd.time(7)"
  default     = "daily"
  nullable    = false
}

variable "envvars" {
  type        = map(string)
  sensitive   = true
  description = "Additional environment variables for lldap"
  default     = {}
  nullable    = false
}

# butane custom
variable "butane_snippets_additional" {
  type        = list(string)
  default     = []
  description = "Additional butane snippets"
  nullable    = false
}

# butane common
variable "ssh_authorized_key" {
  type        = string
  description = "Authorized ssh key for core user"
}

variable "nameservers" {
  type        = list(string)
  description = "List of nameservers for VMs"
  default     = null
}

variable "timezone" {
  type        = string
  description = "Timezone for VMs as listed by `timedatectl list-timezones`"
  default     = null
}

variable "rollout_wariness" {
  type        = string
  description = "Wariness to update, 1.0 (very cautious) to 0.0 (very eager)"
  default     = null
}

variable "periodic_updates" {
  type = object(
    {
      time_zone = optional(string, "")
      windows = list(
        object(
          {
            days           = list(string)
            start_time     = string
            length_minutes = string
          }
        )
      )
    }
  )
  description = <<-TEMPLATE
    Only reboot for updates during certain timeframes
    {
      time_zone = "localtime"
      windows = [
        {
          days           = ["Sat"],
          start_time     = "23:30",
          length_minutes = "60"
        },
        {
          days           = ["Sun"],
          start_time     = "00:30",
          length_minutes = "60"
        }
      ]
    }
  TEMPLATE
  default     = null
}

variable "keymap" {
  type        = string
  description = "Keymap"
  default     = null
}

variable "etc_hosts" {
  type = list(
    object(
      {
        ip       = string
        hostname = string
        fqdn     = string
      }
    )
  )
  description = "/etc/host list"
  default     = null
}

variable "etc_hosts_extra" {
  type        = string
  description = "/etc/host extra block"
  default     = null
}

variable "additional_rpms" {
  type = object(
    {
      cmd_pre  = optional(list(string), [])
      list     = optional(list(string), [])
      cmd_post = optional(list(string), [])
    }
  )
  description = "Additional rpms to install during boot using rpm-ostree, along with any pre or post command"
  default = {
    cmd_pre  = []
    list     = []
    cmd_post = []
  }
  nullable = false
}

variable "interface_name" {
  type        = string
  description = "Network interface name"
  default     = null
}

variable "sync_time_with_host" {
  type        = bool
  description = "Sync guest time with the kvm host"
  default     = null
}

# libvirt node
variable "fqdn" {
  type        = string
  description = "Node FQDN"
}

variable "cidr_ip_address" {
  type        = string
  description = "CIDR IP Address. Ex: 192.168.1.101/24"
  validation {
    condition     = can(cidrhost(var.cidr_ip_address, 1))
    error_message = "Check cidr_ip_address format"
  }
  default = null
}

variable "mac" {
  type        = string
  description = "Mac address"
  default     = null
}

variable "cpu_mode" {
  type        = string
  description = "Libvirt default cpu mode for VMs"
  default     = null
}

variable "vcpu" {
  type        = number
  description = "Node default vcpu count"
  default     = null
}

variable "memory" {
  type        = number
  description = "Node default memory in MiB"
  default     = 512
  nullable    = false
}

variable "machine" {
  type        = string
  description = "The machine type, you normally won't need to set this unless you are running on a platform that defaults to the wrong machine type for your template"
  default     = null
}

variable "root_volume_pool" {
  type        = string
  description = "Node default root volume pool"
  default     = null
}

variable "root_volume_size" {
  type        = number
  description = "Node default root volume size in bytes"
  default     = null
}

variable "root_base_volume_name" {
  type        = string
  description = "Node default base root volume name"
  nullable    = false
}

variable "root_base_volume_pool" {
  type        = string
  description = "Node default base root volume pool"
  default     = null
}

variable "log_volume_pool" {
  type        = string
  description = "Node default log volume pool"
  default     = null
}

variable "log_volume_size" {
  type        = number
  description = "Node default log volume size in bytes"
  default     = null
}

variable "data_volume_pool" {
  type        = string
  description = "Node default data volume pool"
  default     = null
}

variable "data_volume_size" {
  type        = number
  description = "Node default data volume size in bytes"
  default     = null
}

variable "backup_volume_pool" {
  type        = string
  description = "Node default backup volume pool"
  default     = null
}

variable "backup_volume_size" {
  type        = number
  description = "Node default backup volume size in bytes"
  default     = null
}

variable "ignition_pool" {
  type        = string
  description = "Default ignition files pool"
  default     = null
}

variable "wait_for_lease" {
  type        = bool
  description = "Wait for network lease"
  default     = null
}

variable "autostart" {
  type        = bool
  description = "Autostart with libvirt host"
  default     = null
}

variable "network_bridge" {
  type        = string
  description = "Libvirt default network bridge name for VMs"
  default     = null
}

variable "network_id" {
  type        = string
  description = "Libvirt default network id for VMs"
  default     = null
}

variable "network_name" {
  type        = string
  description = "Libvirt default network name for VMs"
  default     = null
}
