#!/bin/bash

SCRIPT_PATH=`dirname $0`
ABSOLUTE_PATH=`readlink -m ${SCRIPT_PATH}`

ACTION="${1:-build}"
OVPN_DATA="$ABSOLUTE_PATH/data"
OVPN_PROTO="${OVPN_PROTO:-udp}"
OVPN_SERVER_NAME="${OVPN_SERVER_NAME:-{{ openvpn__server_name }}}"
OVPN_PORT="${OVPN_PORT:-1194}"
OVPN_IMAGE_VERSION="${OVPN_IMAGE_VERSION:-_2020-12-03}"

mkdir -p $OVPN_DATA
cd $OVPN_DATA

function build {
  (cd {{ openvpn__src_dir }} && docker build -t {{ openvpn__image_name }} .)
}

function configure {
  docker run -v $OVPN_DATA:/etc/openvpn --net=none --rm {{ openvpn__image_name }} ovpn_genconfig \
    -C 'AES-256-CBC' \
    -a 'SHA384' \
    -u ${OVPN_PROTO}://${OVPN_SERVER_NAME}:${OVPN_PORT}

  docker run --rm -v $OVPN_DATA:/etc/openvpn -it {{ openvpn__image_name }} ovpn_initpki
  vim openvpn.conf
  docker run --rm -v $OVPN_DATA:/etc/openvpn -it {{ openvpn__image_name }} easyrsa build-client-full CLIENTNAME nopass
  docker run --rm -v $OVPN_DATA:/etc/openvpn     {{ openvpn__image_name }} ovpn_getclient CLIENTNAME > CLIENTNAME.ovpn
}

function start {
  docker run -v $OVPN_DATA:/etc/openvpn -d -p ${OVPN_PORT}:1194/udp --privileged {{ openvpn__image_name }}${OVPN_IMAGE_VERSION}
}

$ACTION
