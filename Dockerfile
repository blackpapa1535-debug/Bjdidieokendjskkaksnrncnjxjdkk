FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# =========================================================
# INSTALL LIGHTWEIGHT XFCE + XRDP + FIREFOX
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
        xdg-utils \
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
# COPY KALI WALLPAPER
# =========================================================

COPY kali-wallpaper.jpg /usr/share/backgrounds/kali-wallpaper.jpg

RUN chmod 644 /usr/share/backgrounds/kali-wallpaper.jpg

# =========================================================
# DEFAULT BROWSER
# =========================================================

RUN update-alternatives --install \
        /usr/bin/x-www-browser \
        x-www-browser \
        /usr/bin/firefox \
        100 && \
    update-alternatives --set \
        x-www-browser \
        /usr/bin/firefox

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
# KALI WALLPAPER AUTOSTART
# =========================================================

RUN cat > /usr/local/bin/set-kali-wallpaper.sh <<'EOF'
#!/bin/bash

WALLPAPER="/usr/share/backgrounds/kali-wallpaper.jpg"

sleep 2

if command -v xfconf-query >/dev/null 2>&1; then

    xfconf-query \
        -c xfce4-desktop \
        -p /backdrop/screen0/monitor0/workspace0/last-image \
        -n \
        -t string \
        -s "$WALLPAPER" \
        2>/dev/null || \
    xfconf-query \
        -c xfce4-desktop \
        -p /backdrop/screen0/monitor0/workspace0/last-image \
        -s "$WALLPAPER" \
        2>/dev/null || true

    xfconf-query \
        -c xfce4-desktop \
        -p /backdrop/screen0/monitor0/workspace0/image-style \
        -n \
        -t int \
        -s 5 \
        2>/dev/null || \
    xfconf-query \
        -c xfce4-desktop \
        -p /backdrop/screen0/monitor0/workspace0/image-style \
        -s 5 \
        2>/dev/null || true

    xfdesktop --reload 2>/dev/null || true
fi
EOF

RUN chmod +x /usr/local/bin/set-kali-wallpaper.sh

# =========================================================
# XFCE AUTOSTART
# =========================================================

RUN mkdir -p /etc/xdg/autostart && \
    cat > /etc/xdg/autostart/kali-wallpaper.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Kali Wallpaper
Comment=Set Kali Linux wallpaper
Exec=/usr/local/bin/set-kali-wallpaper.sh
Terminal=false
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
EOF

# =========================================================
# START SCRIPT
# =========================================================

RUN cat > /usr/local/bin/start-desktop.sh <<'EOF'
#!/bin/bash

set -u

echo "========================================"
echo "     LIGHTWEIGHT XFCE + XRDP"
echo "========================================"

# =========================================================
# USERNAME / PASSWORD
# =========================================================

RDP_USERNAME="desktop"
RDP_PASSWORD="Desktop2026"

# =========================================================
# SAFETY FALLBACK
# =========================================================

if [ -z "$RDP_USERNAME" ] || [ "$RDP_USERNAME" = "root" ]; then
    RDP_USERNAME="desktop"
fi

if [ -z "$RDP_PASSWORD" ]; then
    RDP_PASSWORD="Desktop2026"
fi

echo "Creating user: $RDP_USERNAME"

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

usermod -aG sudo "$RDP_USERNAME" 2>/dev/null || true

# =========================================================
# USER HOME
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
# XFCE CONFIG
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

rm -f /var/run/xrdp/xrdp.pid
rm -f /var/run/xrdp/xrdp-sesman.pid

# =========================================================
# START XRDP
# =========================================================

echo "Starting xrdp-sesman..."

/usr/sbin/xrdp-sesman

sleep 2

echo "Starting xrdp..."

/usr/sbin/xrdp

sleep 2

# =========================================================
# STATUS
# =========================================================

echo
echo "========================================"
echo "          XRDP IS READY"
echo "========================================"
echo "USERNAME : $RDP_USERNAME"
echo "PASSWORD : $RDP_PASSWORD"
echo "PORT     : 3389"
echo "BROWSER  : Firefox"
echo "WALLPAPER: Kali"
echo "========================================"

if pgrep -x xrdp >/dev/null 2>&1; then
    echo "XRDP     : RUNNING"
else
    echo "XRDP     : FAILED"
fi

if pgrep -x xrdp-sesman >/dev/null 2>&1; then
    echo "SESMAN   : RUNNING"
else
    echo "SESMAN   : FAILED"
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