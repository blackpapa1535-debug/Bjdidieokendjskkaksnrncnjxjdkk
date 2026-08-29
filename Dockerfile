FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# =========================================================
# CHANGE ONLY THESE TWO
# =========================================================
ENV RDP_USERNAME=root
ENV RDP_PASSWORD=root

# =========================================================
# INSTALL
# =========================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies \
    xubuntu-icon-theme \
    tigervnc-standalone-server \
    novnc \
    websockify \
    xrdp \
    sudo \
    xterm \
    dbus \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps \
    openssl \
    curl \
    wget \
    git \
    vim \
    net-tools \
    ca-certificates \
    tzdata \
    software-properties-common \
    gpg-agent \
    && rm -rf /var/lib/apt/lists/*

# =========================================================
# FIREFOX
# =========================================================
RUN add-apt-repository ppa:mozillateam/ppa -y && \
    printf '%s\n' \
    'Package: *' \
    'Pin: release o=LP-PPA-mozillateam' \
    'Pin-Priority: 1001' \
    > /etc/apt/preferences.d/mozilla-firefox && \
    apt-get update && \
    apt-get install -y firefox && \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# XRDP STARTUP
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

if [ -r "$HOME/.profile" ]; then
    . "$HOME/.profile"
fi

exec dbus-launch --exit-with-session startxfce4
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# =========================================================
# DESKTOP START SCRIPT
# =========================================================
RUN cat > /usr/local/bin/start-desktop.sh <<'EOF'
#!/bin/bash

set -e

echo "========================================"
echo " Starting Linux Desktop"
echo "========================================"

# ---------------------------------------------------------
# Validate username
# ---------------------------------------------------------
if [ -z "${RDP_USERNAME}" ]; then
    RDP_USERNAME="myuser"
fi

if [ -z "${RDP_PASSWORD}" ]; then
    RDP_PASSWORD="MyPassword123"
fi

# ---------------------------------------------------------
# Create user safely
# ---------------------------------------------------------
if [ "${RDP_USERNAME}" = "root" ]; then
    USER_HOME="/root"
else

    if ! id "${RDP_USERNAME}" >/dev/null 2>&1; then
        useradd \
            -m \
            -s /bin/bash \
            "${RDP_USERNAME}"
    fi

    USER_HOME="$(getent passwd "${RDP_USERNAME}" | cut -d: -f6)"

    if [ -z "${USER_HOME}" ]; then
        USER_HOME="/home/${RDP_USERNAME}"
    fi

    mkdir -p "${USER_HOME}"
fi

# ---------------------------------------------------------
# Set password
# ---------------------------------------------------------
echo "${RDP_USERNAME}:${RDP_PASSWORD}" | chpasswd

# ---------------------------------------------------------
# Give sudo access for non-root users
# ---------------------------------------------------------
if [ "${RDP_USERNAME}" != "root" ]; then
    usermod -aG sudo "${RDP_USERNAME}" || true
fi

# ---------------------------------------------------------
# Create XFCE session
# ---------------------------------------------------------
cat > "${USER_HOME}/.xsession" <<'XEOF'
#!/bin/sh

unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

export LANG=C.UTF-8
export LANGUAGE=C.UTF-8
export LC_ALL=C.UTF-8

exec dbus-launch --exit-with-session startxfce4
XEOF

chown "${RDP_USERNAME}:${RDP_USERNAME}" "${USER_HOME}/.xsession" 2>/dev/null || true
chmod 700 "${USER_HOME}/.xsession"

# ---------------------------------------------------------
# Runtime directories
# ---------------------------------------------------------
mkdir -p /var/run/xrdp
mkdir -p /var/run/xrdp-sesman
mkdir -p /tmp/.X11-unix

chmod 1777 /tmp/.X11-unix

# ---------------------------------------------------------
# Clean old sessions
# ---------------------------------------------------------
vncserver -kill :1 >/dev/null 2>&1 || true

rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1
rm -f /var/run/xrdp/xrdp.pid
rm -f /var/run/xrdp/xrdp-sesman.pid

# ---------------------------------------------------------
# Start VNC
# ---------------------------------------------------------
echo "Starting VNC..."

vncserver :1 \
    -localhost no \
    -SecurityTypes None \
    -geometry 1024x768 \
    -depth 24 \
    --I-KNOW-THIS-IS-INSECURE

# ---------------------------------------------------------
# SSL certificate
# ---------------------------------------------------------
echo "Creating SSL certificate..."

openssl req \
    -new \
    -x509 \
    -days 365 \
    -nodes \
    -subj "/C=IN/ST=WestBengal/L=Kolkata/O=Desktop/CN=localhost" \
    -out /root/self.pem \
    -keyout /root/self.pem \
    >/dev/null 2>&1

# ---------------------------------------------------------
# Start noVNC
# ---------------------------------------------------------
echo "Starting noVNC..."

websockify \
    --web=/usr/share/novnc/ \
    --cert=/root/self.pem \
    6080 \
    127.0.0.1:5901 &

# ---------------------------------------------------------
# Start XRDP
# ---------------------------------------------------------
echo "Starting XRDP..."

/usr/sbin/xrdp-sesman

/usr/sbin/xrdp

# ---------------------------------------------------------
# INFO
# ---------------------------------------------------------
echo
echo "========================================"
echo "        DESKTOP IS READY"
echo "========================================"
echo "USERNAME : ${RDP_USERNAME}"
echo "PASSWORD : ${RDP_PASSWORD}"
echo "RDP      : 3389"
echo "VNC      : 5901"
echo "NOVNC    : 6080"
echo "HOME     : ${USER_HOME}"
echo "========================================"
echo

# Keep container alive
tail -f /dev/null
EOF

RUN chmod +x /usr/local/bin/start-desktop.sh

# =========================================================
# PORTS
# =========================================================
EXPOSE 3389
EXPOSE 5901
EXPOSE 6080

# =========================================================
# START
# =========================================================
CMD /usr/local/bin/start-desktop.sh