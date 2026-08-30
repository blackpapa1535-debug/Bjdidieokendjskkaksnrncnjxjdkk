FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# =========================================================
# ORIGINAL PACKAGES - NOTHING REMOVED
# =========================================================

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

ENV RDP_USER="desktop"
ENV RDP_PASS='Desktop2026'

# =========================================================
# XRDP PERFORMANCE
# =========================================================

RUN python3 - <<'PY'
from pathlib import Path

p = Path("/etc/xrdp/xrdp.ini")
s = p.read_text()

def set_value(text, key, value):
    import re
    pattern = rf"(?m)^{re.escape(key)}=.*$"
    if re.search(pattern, text):
        return re.sub(pattern, f"{key}={value}", text)
    return text

for key, value in [
    ("max_bpp", "16"),
    ("xserverbpp", "16"),
    ("bitmap_compression", "true"),
    ("bulk_compression", "true"),
    ("tcp_nodelay", "true"),
    ("tcp_keepalive", "true"),
    ("use_fastpath", "both"),
]:
    s = set_value(s, key, value)

p.write_text(s)
PY

# =========================================================
# XRDP SESSION SETTINGS
# =========================================================

RUN python3 - <<'PY'
from pathlib import Path
import re

p = Path("/etc/xrdp/sesman.ini")
s = p.read_text()

for key, value in [
    ("KillDisconnected", "false"),
    ("DisconnectedTimeLimit", "0"),
]:
    pattern = rf"(?m)^{re.escape(key)}=.*$"
    if re.search(pattern, s):
        s = re.sub(pattern, f"{key}={value}", s)
    else:
        marker = "[Sessions]"
        if marker in s:
            s = s.replace(
                marker,
                marker + f"\n{key}={value}",
                1
            )

p.write_text(s)
PY

# =========================================================
# XFCE SESSION
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
    'mkdir -p "$USER_HOME/.config/xfce4/xfconf/xfce-perchannel-xml"' \
    'echo "Optimizing XFCE..."' \
    'su - "$RDP_USER" -c "xfconf-query -c xfwm4 -p /general/use_compositing -s false" 2>/dev/null || true' \
    'su - "$RDP_USER" -c "xfconf-query -c xfwm4 -p /general/box_move -s false" 2>/dev/null || true' \
    'su - "$RDP_USER" -c "xfconf-query -c xfwm4 -p /general/box_resize -s false" 2>/dev/null || true' \
    'su - "$RDP_USER" -c "xfconf-query -c xfce4-session -p /general/SaveOnExit -s false" 2>/dev/null || true' \
    'mkdir -p /var/run/xrdp /var/run/xrdp-sesman' \
    'rm -f /var/run/xrdp/xrdp.pid /var/run/xrdp/xrdp-sesman.pid' \
    'echo "Starting XRDP session manager..."' \
    '/usr/sbin/xrdp-sesman' \
    'echo "Starting XRDP..."' \
    '/usr/sbin/xrdp' \
    'echo "========================================"' \
    'echo "          RDP SERVER READY"' \
    'echo "========================================"' \
    'echo "USERNAME : $RDP_USER"' \
    'echo "PASSWORD : configured"' \
    'echo "PORT     : 3389"' \
    'echo "COLOR    : 16-bit"' \
    'echo "FASTPATH : enabled"' \
    'echo "COMPRESSION: enabled"' \
    'echo "SESSION  : persistent"' \
    'echo "========================================"' \
    'while true; do sleep 3600; done' \
    > /usr/local/bin/start-rdp.sh && \
    chmod +x /usr/local/bin/start-rdp.sh

# =========================================================
# RAILWAY
# =========================================================

EXPOSE 3389

CMD ["/usr/local/bin/start-rdp.sh"]