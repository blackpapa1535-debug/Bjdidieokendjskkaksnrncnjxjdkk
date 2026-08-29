FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && apt-get install --no-install-recommends -y \
    xfce4 xfce4-goodies xubuntu-icon-theme \
    tigervnc-standalone-server novnc websockify \
    xrdp dbus-x11 x11-utils x11-xserver-utils x11-apps \
    sudo xterm openssl init systemd vim net-tools curl wget git tzdata \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

RUN add-apt-repository ppa:mozillateam/ppa -y && \
    echo 'Package: *' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin: release o=LP-PPA-mozillateam' >> /etc/apt/preferences.d/mozilla-firefox && \
    echo 'Pin-Priority: 1001' >> /etc/apt/preferences.d/mozilla-firefox && \
    apt-get update -y && apt-get install -y firefox && \
    rm -rf /var/lib/apt/lists/*

# xrdp uses an XFCE session for RDP logins.
RUN printf '%s\n' '#!/bin/sh' 'startxfce4' > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh && \
    touch /root/.Xauthority

# Keep the existing browser/VNC port and add the RDP port.
EXPOSE 6080
EXPOSE 3389

CMD bash -c '\
set -e; \
mkdir -p /var/run/xrdp /var/run/xrdp-sesman; \
chmod 755 /var/run/xrdp /var/run/xrdp-sesman; \
\
# Existing noVNC service on 6080. \
vncserver -localhost no -SecurityTypes None -geometry 1024x768 --I-KNOW-THIS-IS-INSECURE; \
openssl req -new -subj "/C=JP" -x509 -days 365 -nodes -out self.pem -keyout self.pem; \
websockify -D --web=/usr/share/novnc/ --cert=self.pem 6080 localhost:5901; \
\
# Create a dedicated RDP user with a random password at container startup. \
if ! id rdpuser >/dev/null 2>&1; then useradd -m -s /bin/bash rdpuser; fi; \
PASS=$$(openssl rand -base64 24 | tr -dc "A-Za-z0-9" | head -c 18); \
echo "rdpuser:$$PASS" | chpasswd; \
printf "%s\n" "startxfce4" > /home/rdpuser/.xsession; \
chown rdpuser:rdpuser /home/rdpuser/.xsession; \
\
# Start xrdp directly; Railway containers normally do not run systemd as PID 1. \
/usr/sbin/xrdp-sesman; \
/usr/sbin/xrdp; \
\
echo "================================"; \
echo "RDP USERNAME: rdpuser"; \
echo "RDP PASSWORD: $$PASS"; \
echo "RDP PORT: 3389"; \
echo "================================"; \
tail -f /dev/null'
