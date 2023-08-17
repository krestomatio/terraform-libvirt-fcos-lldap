locals {
  data_volume_path     = "/var/opt/lldap"
  systemd_stop_timeout = 30
  lldap_image          = "${var.image.name}:${var.image.version}"
  ssl                  = var.certbot != null ? true : false
  ssl_path             = "/etc/certs/${var.external_fqdn}"
  lldap_port           = local.ssl ? 6360 : 3890
  post_hook = {
    path    = "/usr/local/bin/lldap-certbot-renew-hook"
    content = <<-TEMPLATE
      #!/bin/bash

      # vars
      lldap_cert_folder_path="${local.data_volume_path}/${local.ssl_path}"
      lldap_cert_path="$$${lldap_cert_folder_path}/fullchain.pem"
      lldap_key_path="$$${lldap_cert_folder_path}/privkey.pem"
      lldap_proxy_uid="0"
      lldap_proxy_gid="0"
      source_cert_folder_path="/etc/letsencrypt/live/${var.external_fqdn}"
      source_cert_path="$$${source_cert_folder_path}/fullchain.pem"
      source_key_path="$$${source_cert_folder_path}/privkey.pem"

      # handle cert correct placement
      # dir
      mkdir -p $$${lldap_cert_folder_path}
      # cert
      cp -f "$$${source_cert_path}" "$$${lldap_cert_path}"
      # key
      cp -f "$$${source_key_path}" "$$${lldap_key_path}"
      # owner
      chown $$${lldap_proxy_uid}:$$${lldap_proxy_gid} "$$${lldap_cert_folder_path}" "$$${lldap_cert_path}" "$$${lldap_key_path}"
      # permissions
      chmod 0600 "$$${lldap_cert_path}" "$$${lldap_key_path}"

      # restart container
      if podman ps lldap &> /dev/null
      then
        podman restart lldap
      else
        echo "lldap container not running"
      fi
    TEMPLATE
  }
}
