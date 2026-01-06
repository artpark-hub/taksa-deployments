#!/bin/sh
set -e

echo "Rendering HAProxy config from environment variables..."
envsubst < /usr/local/etc/haproxy/haproxy.cfg > /tmp/haproxy.cfg

exec haproxy -f /tmp/haproxy.cfg -db
