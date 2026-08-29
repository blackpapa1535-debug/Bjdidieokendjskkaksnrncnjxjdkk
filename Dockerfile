FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# =====================================================
# LIGHTWEIGHT XFCE + XRDP
# =====================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-terminal \
    xrdp \
    xorgxrdp \
    dbus-x11 \
    sudo \
    firefox \
    ca-certificates \
    curl \
    wget \
    nano \
    net-tools \
    procps \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =====================================================
# XRDP STARTUP
# =====================================================
RUN cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh

unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

export LANG=C.UTF-8
export LANGUAGE=C.UTF-8
export LC_ALL=C.UTF-8

exec dbus-launch --exit-with-session startxfce4
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# =====================================================
# DESKTOP START SCRIPT
# =====================================================
RUN cat > /usr/local/bin/start-desktop.sh <<'EOF'
#!/bin/bash

set -e

# =====================================================
# CHANGE ONLY THESE TWO
# =====================================================

RDP_USERNAME="root"
RDP_PASSWORD="root"

# =====================================================
# START
# =====================================================

echo "========================================"
echo " Lightweight XFCE + XRDP"
echo "========================================"

# Don't allow root login
if [ "$RDP_USERNAME" = "root" ]; then
    echo "ERROR: Choose a normal username."
    exit 1
fi

# Create user
if ! id "$RDP_USERNAME" >/dev/null 2>&1; then
    useradd -m -s /bin/bash "$RDP_USERNAME"
fi

# Set password
echo "$RDP_USERNAME:$RDP_PASSWORD" | chpasswd

# Give sudo access
usermod -aG sudo "$RDP_USERNAME"

# Find home directory
USER_HOME="$(getent passwd "$RDP_USERNAME" | cut -d: -f6)"

mkdir -p "$USER_HOME"

# =====================================================
# XFCE SESSION
# =====================================================

cat > "$USER_HOME/.xsession" <<'XEOF'
#!/bin/sh

unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

export LANG=C.UTF-8
export LANGUAGE=C.UTF-8
export LC_ALL=C.UTF-8

exec dbus-launch --exit-with-session startxfce4
XEOF

chown "$RDP_USERNAME:$RDP_USERNAME" "$USER_HOME/.xsession"
chmod +x "$USER_HOME/.xsession"

# =====================================================
# XRDP DIRECTORIES
# =====================================================

mkdir -p /var/run/xrdp
mkdir -p /var/run/xrdp-sesman

rm -f /var/run/xrdp/xrdp.pid
rm -f /var/run/xrdp/xrdp-sesman.pid

# =====================================================
# START XRDP
# =====================================================

echo "Starting XRDP..."

/usr/sbin/xrdp-sesman
/usr/sbin/xrdp

echo
echo "========================================"
echo "       DESKTOP IS READY"
echo "========================================"
echo "USERNAME : $RDP_USERNAME"
echo "PASSWORD : $RDP_PASSWORD"
echo "PORT     : 3389"
echo "========================================"
echo

exec tail -f /dev/null
EOF

RUN chmod +x /usr/local/bin/start-desktop.sh

EXPOSE 3389

CMD ["/usr/local/bin/start-desktop.sh"]