#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  NativOS — Install XFCE Desktop Environment in Chroot
#
#  Run this inside the chroot Ubuntu filesystem to install
#  XFCE (traditional desktop) and all required dependencies.
#
#  Usage: chroot /path/to/rootfs /bin/bash /setup/install-xfce.sh
# ═══════════════════════════════════════════════════════════════

set -e

echo "╔══════════════════════════════════════════╗"
echo "║       NativOS — Installing XFCE          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

export DEBIAN_FRONTEND=noninteractive
export TZ=Etc/UTC

# ── Update package index ──
echo "[1/10] Updating package lists..."
apt-get update -y -q

# ── Core X11/Wayland dependencies ──
echo "[2/10] Installing display server dependencies..."
apt-get install -y --no-install-recommends \
    xwayland \
    weston \
    x11-utils \
    x11-xserver-utils \
    dbus-x11 \
    ca-certificates \
    locales \
    wget \
    curl \
    xserver-xorg-video-dummy \
    xserver-xorg-input-libinput

# ── Install XFCE ──
echo "[3/10] Installing XFCE desktop environment..."
apt-get install -y --no-install-recommends \
    xfce4 \
    xfce4-goodies \
    xfce4-terminal \
    xfce4-session \
    xfce4-panel \
    xfce4-settings \
    xfce4-power-manager \
    xfce4-whiskermenu-plugin \
    xfce4-pulseaudio-plugin \
    xfce4-notifyd \
    thunar \
    thunar-volman \
    thunar-archive-plugin \
    tumbler \
    gvfs \
    gvfs-backends \
    gvfs-fuse \
    mousepad \
    ristretto \
    xfburn \
    catfish \
    mugshot \
    lightdm-gtk-greeter \
    lightdm \
    --no-install-recommends

# ── Window manager & compositor ──
echo "[4/10] Installing window manager and compositor..."
apt-get install -y --no-install-recommends \
    xfwm4 \
    compton \
    picom \
    2>/dev/null || \
    apt-get install -y --no-install-recommends xfwm4 2>/dev/null || true

# ── Touch keyboard ──
echo "[5/10] Installing on-screen keyboard..."
apt-get install -y --no-install-recommends \
    onboard \
    maliit-keyboard \
    2>/dev/null || \
    echo "[!] On-screen keyboard packages may need manual install"

# ── Core applications ──
echo "[6/10] Installing core applications..."
apt-get install -y --no-install-recommends \
    firefox-esr \
    gnome-terminal \
    gnome-text-editor \
    gnome-calculator \
    gnome-clocks \
    nautilus \
    file-roller \
    evince \
    eog \
    vlc \
    2>/dev/null || {
    echo "[!] Some apps not available — installing alternatives..."
    apt-get install -y --no-install-recommends \
        firefox-esr \
        xfce4-terminal \
        mousepad \
        gnome-calculator \
        2>/dev/null || true
}

# ── Audio (PipeWire) ──
echo "[7/10] Installing audio stack..."
apt-get install -y --no-install-recommends \
    pipewire \
    pipewire-pulse \
    wireplumber \
    pavucontrol \
    2>/dev/null || \
    apt-get install -y --no-install-recommends pulseaudio pavucontrol 2>/dev/null || true

# ── Network manager ──
echo "[8/10] Installing network management..."
apt-get install -y --no-install-recommends \
    network-manager \
    network-manager-gnome \
    2>/dev/null || true

# ── PolicyKit for privilege escalation ──
echo "[9/10] Installing PolicyKit..."
apt-get install -y --no-install-recommends \
    policykit-1 \
    polkit-kde-agent-1 \
    2>/dev/null || \
    apt-get install -y --no-install-recommends policykit-1 2>/dev/null || true

# ── Cleanup ──
echo "[10/10] Cleaning up..."
apt-get clean
rm -rf /var/lib/apt/lists/*

# ── Create NativOS config directory ──
mkdir -p /etc/nativOS

# ── Create XFCE session starter ──
cat > /etc/nativOS/xfce-session.sh << 'EOF'
#!/bin/bash
# XFCE session launcher for NativOS
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export HOME=/root
export XDG_RUNTIME_DIR=/tmp/runtime-root
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce
export DESKTOP_SESSION=xfce
export DISPLAY=:0
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export GTK_A11Y=none

mkdir -p /tmp/runtime-root
chmod 0700 /tmp/runtime-root

# D-Bus system bus
mkdir -p /run/dbus
rm -f /run/dbus/pid /run/dbus/system_bus_socket
dbus-uuidgen --ensure
dbus-daemon --system --fork --nopidfile || true
[ -x /usr/lib/polkit-1/polkitd ] && /usr/lib/polkit-1/polkitd --no-debug &

# Start XFCE session
exec dbus-run-session -- startxfce4
EOF
chmod +x /etc/nativOS/xfce-session.sh

# ── Configure LightDM for auto-login ──
mkdir -p /etc/lightdm
cat > /etc/lightdm/lightdm.conf << 'EOF'
[Seat:*]
autologin-user=root
autologin-user-timeout=0
user-session=xfce
session-wrapper=/etc/nativOS/xfce-session.sh
greeter-session=lightdm-gtk-greeter
EOF

cat > /etc/lightdm/lightdm-gtk-greeter.conf << 'EOF'
[greeter]
background=/usr/share/backgrounds/xfce/xfce-blue.jpg
theme-name=Adwaita-dark
icon-theme-name=Adwaita
font-name=Sans 11
xft-antialias=true
xft-hintstyle=hintslight
xft-rgba=rgb
show-indicators=~language;~session;~power
show-clock=true
clock-format=%H:%M
keyboard=onboard
EOF

# ── XFCE panel configuration for desktop mode ──
mkdir -p /etc/xdg/xfce4/panel/default.xml
cat > /etc/xdg/xfce4/panel/default.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="size" type="uint" value="40"/>
      <property name="length-adjust" type="bool" value="true"/>
      <property name="span-monitors" type="bool" value="false"/>
      <property name="autohide-behavior" type="uint" value="0"/>
      <property name="background-style" type="uint" value="1"/>
      <property name="background-alpha" type="uint" value="100"/>
      <property name="enter-opacity" type="uint" value="100"/>
      <property name="leave-opacity" type="uint" value="100"/>
      <property name="items" type="array">
        <value type="string" value="whiskermenu"/>
        <value type="string" value="separator"/>
        <value type="string" value="tasklist"/>
        <value type="string" value="separator"/>
        <value type="string" value="systray"/>
        <value type="string" value="pulseaudio"/>
        <value type="string" value="notification-plugin"/>
        <value type="string" value="clock"/>
        <value type="string" value="action-buttons"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="array">
    <value type="string" value="whiskermenu"/>
    <value type="string" value="tasklist"/>
    <value type="string" value="systray"/>
    <value type="string" value="pulseaudio"/>
    <value type="string" value="notification-plugin"/>
    <value type="string" value="clock"/>
    <value type="string" value="action-buttons"/>
  </property>
</channel>
EOF

# ── XFCE settings for touch/desktop ──
mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml
cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Adwaita-dark"/>
    <property name="IconThemeName" type="string" value="Adwaita"/>
    <property name="FontName" type="string" value="Sans 11"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
    <property name="CursorThemeSize" type="int" value="24"/>
    <property name="SoundThemeName" type="string" value="freedesktop"/>
    <property name="EnableEventSounds" type="bool" value="true"/>
    <property name="EnableInputFeedbackSounds" type="bool" value="true"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Sans 11"/>
    <property name="ThemeName" type="string" value="Adwaita-dark"/>
    <property name="IconThemeName" type="string" value="Adwaita"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
    <property name="CursorThemeSize" type="int" value="24"/>
    <property name="ToolbarStyle" type="string" value="icons"/>
    <property name="ToolbarIconSize" type="string" value="large-toolbar"/>
    <property name="ButtonImages" type="bool" value="true"/>
    <property name="MenuImages" type="bool" value="true"/>
    <property name="EnableEventSounds" type="bool" value="true"/>
    <property name="EnableInputFeedbackSounds" type="bool" value="true"/>
    <property name="XftAntialias" type="int" value="1"/>
    <property name="XftHinting" type="int" value="1"/>
    <property name="XftHintStyle" type="string" value="hintslight"/>
    <property name="XftRgba" type="string" value="rgb"/>
  </property>
</channel>
EOF

cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Default"/>
    <property name="use_compositing" type="bool" value="true"/>
    <property name="workspace_count" type="int" value="4"/>
    <property name="wrap_workspaces" type="bool" value="true"/>
    <property name="wrap_windows" type="bool" value="true"/>
    <property name="focus_new" type="bool" value="true"/>
    <property name="focus_stealing_prevention" type="uint" value="1"/>
    <property name="click_to_focus" type="bool" value="false"/>
    <property name="raise_on_click" type="bool" value="true"/>
    <property name="raise_on_focus" type="bool" value="false"/>
    <property name="activate_action" type="string" value="switch_window_key"/>
    <property name="cycle_minimized" type="bool" value="true"/>
    <property name="cycle_preview" type="bool" value="true"/>
    <property name="cycle_raise" type="bool" value="true"/>
    <property name="cycle_tabwin_mode" type="bool" value="true"/>
    <property name="borderless_maximize" type="bool" value="true"/>
    <property name="maximized_offset" type="int" value="0"/>
    <property name="fullscreen_offset" type="int" value="0"/>
    <property name="placement_mode" type="string" value="mouse"/>
    <property name="placement_ratio" type="int" value="20"/>
    <property name="snap_to_border" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="true"/>
    <property name="wrap_resistance" type="uint" value="10"/>
    <property name="mousewheel_rollup" type="bool" value="false"/>
    <property name="invert_mousewheel_rollup" type="bool" value="false"/>
    <property name="tile_on_move" type="bool" value="true"/>
    <property name="tile_when_dragged_to_border" type="bool" value="true"/>
    <property name="double_click_action" type="string" value="maximize"/>
    <property name="double_click_distance" type="uint" value="5"/>
    <property name="double_click_time" type="uint" value="250"/>
    <property name="cycle_draw_frame" type="bool" value="true"/>
    <property name="cycle_hidden" type="bool" value="true"/>
    <property name="cycle_icons" type="bool" value="true"/>
    <property name="cycle_list" type="bool" value="true"/>
    <property name="cycle_preview" type="bool" value="true"/>
    <property name="cycle_raise" type="bool" value="true"/>
    <property name="cycle_tabwin_mode" type="bool" value="true"/>
  </property>
</channel>
EOF

cat > /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/keyboards.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="keyboards" version="1.0">
  <property name="Default" type="empty">
    <property name="Numlock" type="bool" value="true"/>
    <property name="RestoreNumlock" type="bool" value="true"/>
  </property>
</channel>
EOF

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       XFCE installation complete!        ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Next: run install-bridge.sh to set up the NativOS hardware bridge"