FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update -y && apt install --no-install-recommends -y \
    xfce4 \
    xfce4-goodies \
    tigervnc-standalone-server \
    sudo \
    xterm \
    init \
    systemd \
    snapd \
    vim \
    net-tools \
    curl \
    wget \
    git \
    tzdata \
    xrdp \
    xorgxrdp \
    dbus-x11 \
    x11-utils \
    x11-xserver-utils \
    x11-apps \
    openssl

RUN apt install -y software-properties-common

RUN add-apt-repository ppa:mozillateam/ppa -y

RUN echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Unattended-Upgrade::Allowed-Origins:: "LP-PPA-mozillateam:jammy";' \
    | tee /etc/apt/apt.conf.d/51unattended-upgrades-firefox

RUN apt update -y && apt install -y firefox

RUN apt update -y && apt install -y xubuntu-icon-theme

RUN touch /root/.Xauthority

# =========================================================
# YOUR RDP LOGIN
# =========================================================
# Change ONLY these two lines.
# Password can contain special characters.

ENV RDP_USER="desktop"
ENV RDP_PASS='Desktop2026'

# =========================================================
# XRDP XFCE SESSION
# =========================================================

RUN printf '%s\n' \
    '#!/bin/sh' \
    'unset DBUS_SESSION_BUS_ADDRESS' \
    'unset XDG_RUNTIME_DIR' \
    'export LANG=C.UTF-8' \
    'export LANGUAGE=C.UTF-8' \
    'export LC_ALL=C.UTF-8' \
    'exec dbus-launch --exit-with-session startxfce4' \
    > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh

# =========================================================
# START RDP
# =========================================================

RUN printf '%s\n' \
    '#!/bin/bash' \
    'set -e' \
    'echo "========================================"' \
    'echo "       XFCE + WINDOWS RDP"' \
    'echo "========================================"' \
    'echo "Creating RDP user..."' \
    'if ! id "$RDP_USER" >/dev/null 2>&1; then useradd -m -s /bin/bash "$RDP_USER"; fi' \
    'printf "%s:%s\n" "$RDP_USER" "$RDP_PASS" | chpasswd' \
    'usermod -aG sudo "$RDP_USER" 2>/dev/null || true' \
    'USER_HOME="$(getent passwd "$RDP_USER" | cut -d: -f6)"' \
    'mkdir -p "$USER_HOME"' \
    'printf "%s\n" "#!/bin/sh" "unset DBUS_SESSION_BUS_ADDRESS" "unset XDG_RUNTIME_DIR" "exec dbus-launch --exit-with-session startxfce4" > "$USER_HOME/.xsession"' \
    'chown "$RDP_USER:$RDP_USER" "$USER_HOME/.xsession"' \
    'chmod 755 "$USER_HOME/.xsession"' \
    'mkdir -p /var/run/xrdp /var/run/xrdp-sesman' \
    'rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp/xrdp-sesman.pid' \
    'echo "Starting XRDP session manager..."' \
    '/usr/sbin/xrdp-sesman' \
    'sleep 2' \
    'echo "Starting XRDP..."' \
    '/usr/sbin/xrdp' \
    'sleep 2' \
    'echo "========================================"' \
    'echo "          RDP SERVER READY"' \
    'echo "========================================"' \
    'echo "USERNAME : $RDP_USER"' \
    'echo "PASSWORD : configured"' \
    'echo "PORT     : 3389"' \
    'echo "========================================"' \
    'while true; do sleep 3600; done' \
    > /usr/local/bin/start-rdp.sh && \
    chmod +x /usr/local/bin/start-rdp.sh

# Windows Remote Desktop
EXPOSE 3389

CMD ["/usr/local/bin/start-rdp.sh"]