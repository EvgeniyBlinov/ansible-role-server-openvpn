#!/bin/bash

SCRIPT_PATH="$(dirname $0)"
ABSOLUTE_PATH="$(readlink -m ${SCRIPT_PATH})"

if test -f .env ; then
    set -o allexport;
    source .env;
    set +o allexport;
fi


PROJECT_DIR_NAME="$(basename ${ABSOLUTE_PATH})"
ACTION="${1:-build}"
OVPN_DATA="$ABSOLUTE_PATH/data"
OVPN_PROTO="${OVPN_PROTO:-udp}"
OVPN_SERVER_NAME="${OVPN_SERVER_NAME:-example.com}"
OVPN_PORT="${OVPN_PORT:-1194}"
OVPN_IMAGE_VERSION="${OVPN_IMAGE_VERSION:-_2022-02-04}"
OVPN_NAME="${OVPN_NAME:-${PROJECT_DIR_NAME}}"
OVPN_IMAGE_NAME="${OVPN_IMAGE_NAME:-cent/openvpn-docker${OVPN_IMAGE_VERSION}}"
OVPN_DOCKER_PROJECT_PATH="${OVPN_DOCKER_PROJECT_PATH:-/opt/openvpn-docker}"


mkdir -p "$OVPN_DATA"
cd "$OVPN_DATA"

function build {
  if ! docker images | grep -q $OVPN_IMAGE_NAME ; then
    (cd "${OVPN_DOCKER_PROJECT_PATH}" && docker build -t "${OVPN_IMAGE_NAME}" .)
  fi
}

function cmd {
    local cmds=$*
    echo "$cmds"
    $cmds
}

function configure {
  set -ex;
  cmd docker run -v "${OVPN_DATA}:/etc/openvpn" --net=none --rm "${OVPN_IMAGE_NAME}" ovpn_genconfig \
    -C 'AES-256-CBC' \
    -a 'SHA384' \
    -u "${OVPN_PROTO}://${OVPN_SERVER_NAME}:${OVPN_PORT}"

  cmd docker run --rm -v "${OVPN_DATA}:/etc/openvpn"     "${OVPN_IMAGE_NAME}" touch /etc/openvpn/vars
  cmd docker run --rm -v "${OVPN_DATA}:/etc/openvpn" -it "${OVPN_IMAGE_NAME}" ovpn_initpki nopass
  vim openvpn.conf
  cmd docker run --rm -v "${OVPN_DATA}:/etc/openvpn" -it "${OVPN_IMAGE_NAME}" easyrsa build-client-full CLIENTNAME nopass
  docker run --rm -v "${OVPN_DATA}:/etc/openvpn"     "${OVPN_IMAGE_NAME}" ovpn_getclient CLIENTNAME > CLIENTNAME.ovpn
}

function start {
  cmd docker run \
    -d \
    --privileged \
    -v "${OVPN_DATA}:/etc/openvpn" \
    -p "${OVPN_PORT}:1194/udp" \
    --name "${OVPN_NAME}" \
    "${OVPN_IMAGE_NAME}"
}

"$ACTION"
