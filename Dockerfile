FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# =========================================================
# INSTALL LIGHTWEIGHT XFCE + XRDP
# =========================================================

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        xfce4 \
        xfce4-terminal \
        xrdp \
        xorgxrdp \
        dbus \
        dbus-x11 \
        sudo \
        firefox \
        ca-certificates \
        curl \
        wget \
        nano \
        procps \
        net-tools \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# XRDP STARTWM
# =========================================================

RUN cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh

unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

export LANG=C.UTF-8
export LANGUAGE=C.UTF-8
export LC_ALL=C.UTF-8

if [ -r /etc/profile ]; then
    . /etc/profile
fi

exec dbus-launch --exit-with-session startxfce4
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# =========================================================
# XRDP CONFIG
# =========================================================

RUN sed -i 's/^max_bpp=.*/max_bpp=24/' /etc/xrdp/xrdp.ini || true

# =========================================================
# STARTUP SCRIPT
# =========================================================

RUN cat > /usr/local/bin/start-desktop.sh <<'EOF'
#!/bin/bash

set -u

echo "========================================"
echo "     LIGHTWEIGHT XFCE + XRDP"
echo "========================================"

# =========================================================
# CHANGE ONLY THESE TWO LINES
# =========================================================

RDP_USERNAME="desktop"
RDP_PASSWORD="Desktop2026"

# =========================================================
# NEVER USE ROOT FOR XRDP
# =========================================================

if [ -z "$RDP_USERNAME" ] || [ "$RDP_USERNAME" = "root" ]; then
    RDP_USERNAME="desktop"
fi

if [ -z "$RDP_PASSWORD" ]; then
    RDP_PASSWORD="Desktop2026"
fi

echo "Username: $RDP_USERNAME"

# =========================================================
# CREATE USER
# =========================================================

if ! id "$RDP_USERNAME" >/dev/null 2>&1; then
    useradd \
        --create-home \
        --shell /bin/bash \
        "$RDP_USERNAME"
fi

# =========================================================
# PASSWORD
# =========================================================

echo "$RDP_USERNAME:$RDP_PASSWORD" | chpasswd

# =========================================================
# SUDO
# =========================================================

usermod -aG sudo "$RDP_USERNAME" 2>/dev/null || true

# =========================================================
# GET REAL HOME DIRECTORY
# =========================================================

USER_HOME="$(getent passwd "$RDP_USERNAME" | cut -d: -f6)"

if [ -z "$USER_HOME" ]; then
    USER_HOME="/home/$RDP_USERNAME"
fi

mkdir -p "$USER_HOME"

# =========================================================
# XFCE SESSION
# =========================================================

cat > "$USER_HOME/.xsession" <<'XSESSION'
#!/bin/sh

unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

export LANG=C.UTF-8
export LANGUAGE=C.UTF-8
export LC_ALL=C.UTF-8

exec dbus-launch --exit-with-session startxfce4
XSESSION

chown "$RDP_USERNAME:$RDP_USERNAME" "$USER_HOME/.xsession"
chmod 755 "$USER_HOME/.xsession"

# =========================================================
# XFCE CONFIG DIRECTORY
# =========================================================

mkdir -p "$USER_HOME/.config"

chown -R "$RDP_USERNAME:$RDP_USERNAME" "$USER_HOME/.config"

# =========================================================
# XRDP RUNTIME
# =========================================================

mkdir -p /var/run/xrdp
mkdir -p /var/run/xrdp-sesman

chmod 755 /var/run/xrdp
chmod 755 /var/run/xrdp-sesman

# Remove stale PID files
rm -f /var/run/xrdp/xrdp.pid
rm -f /var/run/xrdp/xrdp-sesman.pid

# =========================================================
# START XRDP SESSION MANAGER
# =========================================================

echo "Starting xrdp-sesman..."

/usr/sbin/xrdp-sesman

sleep 2

# =========================================================
# START XRDP
# =========================================================

echo "Starting xrdp..."

/usr/sbin/xrdp

sleep 2

# =========================================================
# VERIFY
# =========================================================

echo
echo "========================================"
echo "          XRDP IS READY"
echo "========================================"
echo "USERNAME : $RDP_USERNAME"
echo "PASSWORD : $RDP_PASSWORD"
echo "PORT     : 3389"
echo "========================================"

if pgrep -x xrdp >/dev/null 2>&1; then
    echo "XRDP STATUS: RUNNING"
else
    echo "XRDP STATUS: FAILED"
fi

if pgrep -x xrdp-sesman >/dev/null 2>&1; then
    echo "SESMAN STATUS: RUNNING"
else
    echo "SESMAN STATUS: FAILED"
fi

echo "========================================"
echo

# =========================================================
# KEEP CONTAINER ALIVE
# =========================================================

while true; do
    sleep 3600
done
EOF

RUN chmod +x /usr/local/bin/start-desktop.sh

# =========================================================
# RDP PORT
# =========================================================

EXPOSE 3389

# =========================================================
# START
# =========================================================

CMD ["/usr/local/bin/start-desktop.sh"]