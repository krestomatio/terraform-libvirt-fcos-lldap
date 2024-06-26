data "template_file" "butane_snippet_install_lldap" {
  template = <<TEMPLATE
---
variant: fcos
version: 1.4.0
storage:
  files:
    # pkg dependencies to be installed by additional-rpms.service
    - path: /var/lib/additional-rpms.list
      overwrite: false
      append:
        - inline: |
            firewalld
    - path: /usr/local/bin/lldap-installer.sh
      mode: 0754
      overwrite: true
      contents:
        inline: |
          #!/bin/bash -e
          # vars

          ## firewalld rules
          if ! systemctl is-active firewalld &> /dev/null
          then
            echo "Enabling firewalld..."
            systemctl restart dbus.service
            restorecon -rv /etc/firewalld
            systemctl enable --now firewalld
            echo "Firewalld enabled..."
          fi
          # Add firewalld rules
          echo "Adding firewalld rules..."
          %{~if length(var.cidr_sources) > 0~}
          %{~for cidr_source in var.cidr_sources~}
          firewall-cmd --zone=public --permanent --add-rich-rule='rule family="ipv4" source address="${cidr_source}" port protocol="tcp" port="${local.lldap_port}" accept'
          %{~endfor~}
          %{~else~}
          firewall-cmd --zone=public --permanent --add-port=${local.lldap_port}/tcp
          %{~endif~}
          firewall-cmd --zone=public --permanent --add-port=17170/tcp
          # firewall-cmd --zone=public --add-masquerade
          firewall-cmd --reload
          echo "Firewalld rules added..."

          # selinux context to data dir
          chcon -Rt svirt_sandbox_file_t ${local.data_volume_path}
          # selinux context to backup dir
          chcon -Rt svirt_sandbox_file_t ${local.backup_volume_path}

          # install
          echo "Installing lldap service..."
          podman kill lldap 2>/dev/null || echo
          podman rm lldap 2>/dev/null || echo
          podman create --pull never --rm --restart on-failure --stop-timeout ${local.systemd_stop_timeout} \
            --network host \
            %{~if var.cpus_limit > 0~}
            --cpus ${var.cpus_limit} \
            %{~endif~}
            %{~if var.memory_limit != ""~}
            --memory ${var.memory_limit} \
            %{~endif~}
            -e LLDAP_JWT_SECRET='${var.jwt_secret}' \
            -e LLDAP_LDAP_USER_PASS='${var.ldap_user_pass}' \
            -e LLDAP_LDAP_BASE_DN='${var.ldap_base_dn}' \
            %{~if local.ssl~}
            -e LLDAP_LDAPS_OPTIONS__ENABLED='true' \
            -e LLDAP_LDAPS_OPTIONS__CERT_FILE='/data/${local.ssl_path}/fullchain.pem' \
            -e LLDAP_LDAPS_OPTIONS__KEY_FILE='/data/${local.ssl_path}/privkey.pem' \
            %{~endif~}
            %{~for var, value in var.envvars~}
            -e ${var}='${value}' \
            %{~endfor~}
            -e LLDAP_HTTP_URL='${local.ssl ? "https" : "http"}://${var.external_fqdn}' \
            -e ${local.ssl ? "LLDAP_LDAPS_OPTIONS__PORT" : "LLDAP_LDAP_PORT"}='${local.lldap_port}' \
            --volume /etc/localtime:/etc/localtime:ro \
            --volume "${local.data_volume_path}:/data" \
            --name lldap ${local.lldap_image}
          podman generate systemd --new \
            --restart-sec 15 \
            --start-timeout 180 \
            --stop-timeout ${local.systemd_stop_timeout} \
            --after lldap-image-pull.service \
            --name lldap > /etc/systemd/system/lldap.service
          systemctl daemon-reload
          systemctl enable --now lldap.service
          echo "lldap service installed..."
    - path: /usr/local/bin/lldap-backup.sh
      mode: 0750
      overwrite: true
      contents:
        inline: |
          #!/bin/bash -e

          # vars
          DB_PATH="${local.data_volume_path}"
          DB_FILE_NAME="users.db"
          DB_FILE="$DB_PATH/$DB_FILE_NAME"
          BACKUP_PATH="${local.backup_volume_path}"
          BACKUP_FILE_NAME="users.db"
          BACKUP_FILE="$BACKUP_PATH/$BACKUP_FILE_NAME"
          SQLITE_IMAGE=docker.io/keinos/sqlite3:3.42.0

          echo "checking db file exist..."
          test -f $DB_FILE || { echo "db file: '$DB_FILE' does not exist, exiting..."; exit 0; }

          # backup
          echo "creating backup file in '$BACKUP_FILE'..."
          podman run -t --rm \
              --replace \
              --user $(id -u):$(id -g) \
              --volume /etc/localtime:/etc/localtime:ro \
              --volume "$DB_FILE:$DB_FILE" \
              --volume "$BACKUP_PATH:$BACKUP_PATH" \
              --name sqlite $SQLITE_IMAGE sqlite3 "$DB_FILE" ".backup '$BACKUP_FILE'"
          # integrity check
          echo "checking backup file integrity..."
          podman run -t --rm \
              --replace \
              --user $(id -u):$(id -g) \
              --volume /etc/localtime:/etc/localtime:ro \
              --volume "$BACKUP_FILE:$BACKUP_FILE" \
              --name sqlite $SQLITE_IMAGE sqlite3 "$BACKUP_FILE" 'pragma integrity_check;'
          %{~if var.backup_script_additiona_block != ""~}

          # Additional block
          ${indent(10, var.backup_script_additiona_block)}
          %{~endif~}
systemd:
  units:
    - name: lldap-image-pull.service
      enabled: true
      contents: |
        [Unit]
        Description="Pull lldap image"
        Wants=network-online.target
        After=network-online.target
        After=additional-rpms.service
        Requires=additional-rpms.service
        Before=install-lldap.service
        Before=lldap.service

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        Restart=no
        TimeoutStartSec=90
        ExecStart=/usr/bin/podman pull ${local.lldap_image}

        [Install]
        WantedBy=multi-user.target
    - name: install-lldap.service
      enabled: true
      contents: |
        [Unit]
        Description=Install lldap
        # We run before `zincati.service` to avoid conflicting rpm-ostree
        # transactions.
        Before=zincati.service
        Wants=network-online.target
        After=network-online.target
        After=additional-rpms.service
        After=install-certbot.service
        After=lldap-image-pull.service
        Requires=additional-rpms.service
        Requires=lldap-image-pull.service
        ConditionPathExists=/usr/local/bin/lldap-installer.sh
        ConditionPathExists=!/var/lib/%N.done

        [Service]
        Type=oneshot
        RemainAfterExit=yes
        Restart=no
        TimeoutStartSec=90
        ExecStart=/usr/local/bin/lldap-installer.sh
        ExecStart=/bin/touch /var/lib/%N.done

        [Install]
        WantedBy=multi-user.target
    - name: lldap-backup.service
      enabled: false
      contents: |
        [Unit]
        Description=Lldap backup task
        Wants=lldap-backup.timer

        [Service]
        Type=oneshot
        ExecStart=/usr/local/bin/lldap-backup.sh

        [Install]
        WantedBy=multi-user.target
    - name: lldap-backup.timer
      enabled: true
      contents: |
        [Unit]
        Description=Lldap backup task
        Wants=network-online.target
        After=network-online.target
        After=install-lldap.service
        Requires=lldap-backup.service

        [Timer]
        Unit=lldap-backup.service
        OnCalendar=${var.backup_task_on_calendar}
        AccuracySec=1m
        Persistent=true

        [Install]
        WantedBy=timers.target
TEMPLATE
}

module "butane_snippet_install_certbot" {
  count = var.certbot != null ? 1 : 0

  source  = "krestomatio/butane-snippets/ct//modules/certbot"
  version = "0.0.12"

  domain       = var.external_fqdn
  http_01_port = var.certbot.http_01_port
  post_hook    = local.post_hook
  agree_tos    = var.certbot.agree_tos
  staging      = var.certbot.staging
  email        = var.certbot.email
}
