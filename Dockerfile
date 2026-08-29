FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Basic packages + XFCE + VNC + RDP + noVNC
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

# Firefox
RUN add-apt-repository ppa:mozillateam/ppa -y && \
    printf 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
    > /etc/apt/preferences.d/mozilla-firefox && \
    apt-get update && \
    apt-get install -y firefox && \
    rm -rf /var/lib/apt/lists/*

# XRDP startup
RUN printf '%s\n' \
    '#!/bin/sh' \
    'if [ -r /etc/profile ]; then' \
    '    . /etc/profile' \
    'fi' \
    'startxfce4' \
    > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh

# Root X session
RUN printf '%s\n' 'startxfce4' > /root/.xsession && \
    touch /root/.Xauthority

# Create startup script
RUN cat > /usr/local/bin/start-desktop.sh <<'EOF'
#!/bin/bash
set -e

mkdir -p /var/run/xrdp
mkdir -p /var/run/xrdp-sesman
mkdir -p /tmp/.X11-unix

chmod 1777 /tmp/.X11-unix

# Create RDP user if it doesn't exist
if ! id rdpuser >/dev/null 2>&1; then
    useradd -m -s /bin/bash rdpuser
fi

# Generate a random password
PASS="$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9' | head -c 18)"

if [ -z "$PASS" ]; then
    PASS="Rdp$(date +%s)X9"
fi

echo "rdpuser:${PASS}" | chpasswd

# XFCE session
printf '%s\n' 'startxfce4' > /home/rdpuser/.xsession
chown rdpuser:rdpuser /home/rdpuser/.xsession
chmod 644 /home/rdpuser/.xsession

# Start VNC
rm -f /tmp/.X1-lock
rm -f /tmp/.X11-unix/X1

vncserver :1 \
    -localhost no \
    -SecurityTypes None \
    -geometry 1024x768 \
    -depth 24 \
    --I-KNOW-THIS-IS-INSECURE

# Generate self-signed certificate for noVNC
openssl req \
    -new \
    -x509 \
    -days 365 \
    -nodes \
    -subj "/C=IN/ST=WestBengal/L=Kolkata/O=Desktop/CN=localhost" \
    -out /root/self.pem \
    -keyout /root/self.pem

# Start noVNC/websockify
websockify \
    --web=/usr/share/novnc/ \
    --cert=/root/self.pem \
    6080 \
    localhost:5901 &

# Start XRDP
/usr/sbin/xrdp-sesman
/usr/sbin/xrdp

echo
echo "========================================"
echo "        DESKTOP STARTED"
echo "========================================"
echo "RDP USERNAME: rdpuser"
echo "RDP PASSWORD: ${PASS}"
echo "RDP PORT: 3389"
echo "VNC PORT: 5901"
echo "NOVNC PORT: 6080"
echo "========================================"
echo

# Keep container alive
tail -f /dev/null
EOF

RUN chmod +x /usr/local/bin/start-desktop.sh

EXPOSE 3389
EXPOSE 5901
EXPOSE 6080

CMD /usr/local/bin/start-desktop.sh
