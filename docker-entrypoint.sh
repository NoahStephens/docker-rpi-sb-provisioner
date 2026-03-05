#!/usr/bin/env bash
set -Eeuo pipefail

mkdir -p /etc/rpi-sb-provisioner /srv/rpi-sb-provisioner/images /srv/rpi-sb-provisioner/work /var/log/rpi-sb-provisioner

if [ ! -s /etc/rpi-sb-provisioner/config ] && [ -f /usr/share/rpi-sb-provisioner/config.default ]; then
	cp /usr/share/rpi-sb-provisioner/config.default /etc/rpi-sb-provisioner/config
fi

# Seed the manufacturing DB so the web UI can render on a fresh container.
if [ ! -f /srv/rpi-sb-provisioner/manufacturing.db ]; then
	sqlite3 /srv/rpi-sb-provisioner/manufacturing.db '
		CREATE TABLE IF NOT EXISTS devices (
			serial TEXT,
			endpoint TEXT,
			state TEXT,
			image TEXT,
			ip_address TEXT,
			ts INTEGER DEFAULT (strftime('"'"'%s'"'"','"'"'now'"'"')),
			provision_ts INTEGER,
			boardname TEXT,
			processor TEXT,
			rpi_duid TEXT
		);
	'
fi

# rpi-provisioner-ui queries systemd state via sd-bus, so provide a system bus in containers.
if [ ! -S /run/dbus/system_bus_socket ]; then
	mkdir -p /run/dbus
	dbus-uuidgen --ensure=/etc/machine-id
	dbus-daemon --system --fork --nopidfile
fi

exec "$@"
