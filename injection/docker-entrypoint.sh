#!/bin/sh
# vim: set noet :

set -eu

##############################################################################
# Default
##############################################################################

if [ -z "${HRAFTD_UID:-}" ]; then
	HRAFTD_UID=1000
fi
if [ -z "${HRAFTD_GID:-}" ]; then
	HRAFTD_GID=1000
fi

if [ -z "${HRAFTD_NODE_NAME:-}" ]; then
	HRAFTD_NODE_NAME="$(hostname)"
fi
if [ -z "${HRAFTD_HTTP_BIND_ADDRESS:-}" ]; then
	HRAFTD_HTTP_BIND_ADDRESS=":11000"
fi
if [ -z "${HRAFTD_RAFT_BIND_ADDRESS:-}" ]; then
	HRAFTD_RAFT_BIND_ADDRESS=":12000"
fi
if [ -z "${HRAFTD_JOIN_ADDRESS:-}" ]; then
	HRAFTD_JOIN_ADDRESS=""
fi
if [ -z "${HRAFTD_INMEM_STORAGE:-}" ]; then
	HRAFTD_INMEM_STORAGE="true"
fi
if [ -z "${HRAFTD_DATA_DIR:-}" ]; then
	HRAFTD_DATA_DIR="/var/lib/hraftd"
fi

if [ -z "${TZ:-}" ]; then
	TZ="UTC"
fi

##############################################################################
# Logging
##############################################################################

echo 'Environment Variables'
echo ''
echo "HRAFTD_UID:      '${HRAFTD_UID}'"
echo "HRAFTD_GID:      '${HRAFTD_GID}'"
echo "HRAFTD_DATA_DIR: '${HRAFTD_DATA_DIR}'"
echo "TZ:              '${TZ}'"
echo ''

##############################################################################
# Check
##############################################################################

if echo "${HRAFTD_UID}" | grep -Eqsv '^[0-9]+$'; then
	echo "HRAFTD_UID: '${HRAFTD_UID}'"
	echo 'Please numric value: HRAFTD_UID'
	exit 1
fi
if [ "${HRAFTD_UID}" -le 0 ]; then
	echo "HRAFTD_UID: '${HRAFTD_UID}'"
	echo 'Please 0 or more: HRAFTD_UID'
	exit 1
fi
if [ "${HRAFTD_UID}" -ge 60000 ]; then
	echo "HRAFTD_UID: '${HRAFTD_UID}'"
	echo 'Please 60000 or less: HRAFTD_UID'
	exit 1
fi

if echo "${HRAFTD_GID}" | grep -Eqsv '^[0-9]+$'; then
	echo "HRAFTD_GID: '${HRAFTD_GID}'"
	echo 'Please numric value: HRAFTD_GID'
	exit 1
fi
if [ "${HRAFTD_GID}" -le 0 ]; then
	echo "HRAFTD_GID: '${HRAFTD_GID}'"
	echo 'Please 0 or more: HRAFTD_GID'
	exit 1
fi
if [ "${HRAFTD_GID}" -ge 60000 ]; then
	echo "HRAFTD_GID: '${HRAFTD_GID}'"
	echo 'Please 60000 or less: HRAFTD_GID'
	exit 1
fi

if echo "${HRAFTD_INMEM_STORAGE}" | grep -Eqsv '^(true|false)$'; then
	echo "HRAFTD_INMEM_STORAGE: '${HRAFTD_INMEM_STORAGE}'"
	echo 'Please true or false: HRAFTD_INMEM_STORAGE'
	exit 1
fi

if [ "x$(cat < '/proc/mounts' | grep "${HRAFTD_DATA_DIR}" | awk '{print substr($4,0,2)}')" = 'xro' ]; then
	echo 'Do not have write permission: HRAFTD_DATA_DIR'
	exit 1
fi

if [ ! -f "/usr/share/zoneinfo/${TZ}" ]; then
	echo "TZ: '${TZ}'"
	echo 'Not Found Timezone: TZ'
	exit 1
fi

##############################################################################
# Clear
##############################################################################

if getent passwd | awk -F ':' -- '{print $1}' | grep -Eqs '^hraftd$'; then
	deluser 'hraftd'
fi
if getent passwd | awk -F ':' -- '{print $3}' | grep -Eqs "^${HRAFTD_UID}$"; then
	deluser "${HRAFTD_UID}"
fi
if getent group | awk -F ':' -- '{print $1}' | grep -Eqs '^hraftd$'; then
	delgroup 'hraftd'
fi
if getent group | awk -F ':' -- '{print $3}' | grep -Eqs "^${HRAFTD_GID}$"; then
	delgroup "${HRAFTD_GID}"
fi

##############################################################################
# Group
##############################################################################

addgroup -g "${HRAFTD_GID}" 'hraftd'

##############################################################################
# User
##############################################################################

adduser -h '/nonexistent' \
	-g 'hraftd user' \
	-s '/usr/sbin/nologin' \
	-h '/dev/null' \
	-G 'hraftd' \
	-D \
	-H \
	-u "${HRAFTD_UID}" \
	'hraftd'

##############################################################################
# Timezone
##############################################################################

ln -fs "/usr/share/zoneinfo/${TZ}" '/etc/localtime'

##############################################################################
# Directory
##############################################################################

if [ ! -d "${HRAFTD_DATA_DIR}" ]; then
	mkdir -p "${HRAFTD_DATA_DIR}"
fi

##############################################################################
# Permission
##############################################################################

chown -R "${HRAFTD_UID}:${HRAFTD_GID}" "${HRAFTD_DATA_DIR}"

##############################################################################
# Daemon
##############################################################################

ARGS="-id ${HRAFTD_NODE_NAME}"

if [ -n "${HRAFTD_JOIN_ADDRESS}" ]; then
	ARGS="${ARGS} -join ${HRAFTD_JOIN_ADDRESS}"
fi

if [ -n "${HRAFTD_HTTP_BIND_ADDRESS}" ]; then
	ARGS="${ARGS} -haddr ${HRAFTD_HTTP_BIND_ADDRESS}"
fi

if [ -n "${HRAFTD_RAFT_BIND_ADDRESS}" ]; then
	ARGS="${ARGS} -raddr ${HRAFTD_RAFT_BIND_ADDRESS}"
fi

if [ "${HRAFTD_INMEM_STORAGE}" = "true" ]; then
	ARGS="${ARGS} -inmem"
fi

ARGS="${ARGS} ${HRAFTD_DATA_DIR}"

mkdir -p '/etc/sv/hraftd'
cat > '/etc/sv/hraftd/run' <<- __EOF__
#!/bin/sh
set -e
exec 2>&1
exec su-exec ${HRAFTD_UID}:${HRAFTD_GID} hraftd -id ${HRAFTD_NODE_NAME} ${HRAFTD_DATA_DIR}
__EOF__
chmod 0755 '/etc/sv/hraftd/run'

##############################################################################
# Service
##############################################################################

ln -s '/etc/sv/hraftd' '/etc/service/hraftd'

##############################################################################
# Running
##############################################################################

if [ "$1" = 'hraftd' ]; then
	echo ''
	echo 'Starting Server'
	echo ''
	exec runsvdir '/etc/service'
fi

exec "$@"
