# OS Setup Scripts & Helpers

**Disclaimer: these are yet another useless scripts that I use sometimes, they're not really meant to be used by anyone other than me.**

Most of the scripts/helpers should be idempotent and not push you to broken installs unless you do woefully wrong or are horribly careless running shit.

depending on the scripts in-here, supported architectures are `arm`. `arm64`, `x86/amd64`, `mips`

### Ubuntus: `crapbuntuOrDebianSetup.sh`
This sets up some basic stuff for an ubuntu 16.04/+ system. assumes you have a gnome install, uncomment the section where virtualisation is enabled if your CPU has Intel VTd or AMD SVM/V.

i hate ubuntus with passion but am required to set it up for friends or colleagues and on some servers (not headless necessarily), it's when i try to copy-pasta from this script. will keep this updated with newer crapbuntu releases.
