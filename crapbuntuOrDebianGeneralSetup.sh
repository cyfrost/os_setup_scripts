#!/bin/env bash

function print() {
    printf "\n$1\n\n"
}

# WARNING: CONFIGURE VARS FIRST. reference script only
rootPWD=""
lat=""
long=""
gitUsername=""
gitEmail=""
gitPassword=""
exit 0

# Change root password.
echo "$rootPWD" | sudo passwd --stdin root

# Set NOPASSWD for current user.
grant_compgen="$USER ALL=(ALL) NOPASSWD:ALL" && echo "$grant_compgen" | sudo EDITOR='tee -a' visudo && echo -en "\n\nDone adding user to sudo visudo OK\n\n"

# Set plymouth to details by updating GRUB.
sudo sed -ie "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)quiet\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1\2\"/" /etc/default/grub
sudo sed -ie "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)splash\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1\2\"/" /etc/default/grub
sudo update-grub

# Improve GNOME defaults
gsettings set org.gnome.desktop.calendar show-weekdate true
gsettings set org.gnome.desktop.datetime automatic-timezone true
gsettings set org.gnome.desktop.interface clock-format '24h'
gsettings set org.gnome.desktop.interface clock-show-date true
gsettings set org.gnome.desktop.interface show-battery-percentage true
gsettings set org.gnome.desktop.peripherals.touchpad tap-to-click true
gsettings set org.gnome.desktop.peripherals.mouse speed 1
gsettings set org.gnome.desktop.peripherals.touchpad speed 1
gsettings set org.gnome.desktop.background picture-options 'stretched'
gsettings set org.gnome.desktop.background picture-uri ''
gsettings set org.gnome.desktop.background primary-color '#000000'
gsettings set org.gnome.desktop.screensaver primary-color '#000000'
gsettings set org.gnome.desktop.background color-shading-type 'solid'
gsettings set org.gnome.desktop.screensaver picture-uri ''
gsettings set org.gnome.desktop.screensaver color-shading-type 'solid'
gsettings set org.gtk.Settings.FileChooser show-hidden true
gsettings set org.gtk.Settings.FileChooser show-size-column true
gsettings set org.gtk.Settings.FileChooser sidebar-width 180
gsettings set org.gtk.Settings.FileChooser sort-column 'name'
gsettings set org.gtk.Settings.FileChooser sort-directories-first true
gsettings set org.gtk.Settings.FileChooser sort-order 'ascending'
gsettings set org.gnome.nautilus.icon-view default-zoom-level 'standard'
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'icon-view'
gsettings set org.gnome.nautilus.preferences executable-text-activation 'ask'
gsettings set org.gnome.nautilus.preferences search-filter-time-type 'last_modified'
gsettings set org.gnome.nautilus.preferences search-view 'list-view'
gsettings set org.gnome.nautilus.preferences show-create-link true
gsettings set org.gnome.nautilus.preferences show-delete-permanently true
gsettings set org.gnome.nautilus.preferences show-hidden-files true
gsettings set org.gnome.FileRoller.FileSelector show-hidden true
gsettings set org.gnome.nautilus.list-view use-tree-view true
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'
gsettings set org.gnome.mutter center-new-windows true
gsettings set org.gnome.desktop.wm.preferences resize-with-right-button true
gsettings set org.gnome.shell.overrides workspaces-only-on-primary false
gsettings set org.freedesktop.Tracker.Miner.Files index-on-battery false
gsettings set org.freedesktop.Tracker.Miner.Files index-on-battery-first-time false
gsettings set org.freedesktop.Tracker.Miner.Files throttle 15
gsettings set org.gnome.desktop.sound allow-volume-above-100-percent true
gsettings set org.gnome.settings-daemon.peripherals.keyboard numlock-state 'on'
gsettings set org.gnome.settings-daemon.plugins.xsettings antialiasing 'rgba'
gsettings set org.gnome.desktop.privacy report-technical-problems true
gsettings set org.gnome.settings-daemon.plugins.color night-light-temperature 4900
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
gsettings set org.gnome.eog.view background-color 'rgb(0,0,0)'
gsettings set org.gnome.eog.view use-background-color true
gsettings set org.gnome.eog.ui disable-close-confirmation true

# Update everything.
sudo apt autoremove -y;
sudo apt autoclean -y;
sudo apt update -y --fix-missing;
sudo apt upgrade -y;
sudo apt dist-upgrade -y;
sudo apt full-upgrade -y;
sudo apt autoremove -y;
sudo apt autoclean -y;
sudo apt update -y --fix-missing;

# Install important packages
sudo apt install -y gnupg ca-certificates lsb-release apt-transport-https git curl wget build-essential vlc nano vim openssh-server sshpass jq chrome-gnome-shell feh ffmpeg flameshot filezilla python3 python3-pip gnome-tweaks htop hwinfo gtkhash ncdu neofetch nmap qbittorrent remmina xkill tmux tilix guake testdisk thefuck transmission tuned unar unzip mpv gnome-mpv handbrake needrestart shellcheck

# Enable few services
sudo systemctl enable --now libvirtd
sudo systemctl enable --now apache2
sudo systemctl enable --now fstrim.timer
sudo systemctl enable --now ssh
sudo systemctl disable --now bluetooth

# Configure Git
git config --global user.name --replace-all "$gitUsername"
git config --global user.email "$gitEmail"
git config --global user.password "$gitPassword"
git config --global credential.helper store

# Install Docker
sudo apt remove --purge -y docker docker-engine docker.io containerd runc;
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update -y --fix-missing;
sudo apt install -y docker-ce docker-ce-cli containerd.io
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker
sudo systemctl enable --now docker.service
sudo systemctl enable --now docker.socket
sudo systemctl enable --now containerd.service
docker version

# Installing Docker compose
pip3 install --user docker-compose
docker-compose version

# Install Chrome
sudo apt install -y "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

# Update Snaps
sudo snap refresh

# Install Pipenv
pip3 install --user pipenv


# Install Sublime Text
wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | sudo apt-key add -
sudo apt install -y apt-transport-https
echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list
sudo apt update -y
sudo apt install sublime-text -y


# Installing Node
NVM_LATEST_VER=$(curl -s https://api.github.com/repos/nvm-sh/nvm/releases/latest | jq -r ".name") && \
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_LATEST_VER/install.sh | bash && \
NVM_SH_BASHRC_SOURCE='
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
' && \
echo "$NVM_SH_BASHRC_SOURCE" >> "$HOME/.bashrc" && \
source "$HOME/.bashrc" && \
export NVM_DIR="$HOME/.nvm" && \
\. "$NVM_DIR/nvm.sh" && \
nvm install lts/fermium && \
nvm install-latest-npm && \
nvm alias default lts/fermium && \
npm i -g yarn eslint jshint typescript @angular/cli tldr vue-cli fkill-cli npm-check-updates create-react-app eslint-config-standard eslint-config-standard-react eslint-config-standard-jsx eslint-plugin-react eslint-config-prettier eslint-plugin-prettier forever
