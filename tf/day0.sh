#!/usr/bin/env bash
# Day 0: minimal host bootstrap so OpenTofu can run against qemu:///system.
# Idempotent. Usage: sudo ./day0.sh [--no-install]
set -euo pipefail

POOL="${POOL:-default}"
POOL_DIR="${POOL_DIR:-/var/lib/libvirt/images}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

DO_INSTALL=1
for a in "$@"; do
  case "$a" in
    --no-install) DO_INSTALL=0 ;;
    -h|--help)    grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)            die "unknown argument: $a" ;;
  esac
done

# Become root but remember the invoking user.
if [[ ${EUID} -ne 0 ]]; then
  command -v sudo >/dev/null || die "must run as root"
  exec sudo -E -- "$0" "$@"
fi
TARGET_USER="${SUDO_USER:-}"
[[ -n "$TARGET_USER" && "$TARGET_USER" != "root" ]] || die "run via sudo as your normal user (e.g. sudo ./day0.sh)"

preflight() {
  [[ -e /dev/kvm ]] || warn "/dev/kvm missing — KVM may be unavailable"
}

install_packages() {
  if [[ $DO_INSTALL -eq 0 ]]; then
    log "skipping package install (--no-install)"
    return
  fi
  if command -v zypper >/dev/null; then
    log "installing host packages via zypper"
    zypper --non-interactive --quiet install --no-recommends \
      qemu-x86 qemu-img qemu-tools libvirt-client libvirt-daemon-qemu \
      libvirt-daemon-config-network virt-install dnsmasq \
      || warn "zypper reported issues; continuing"
  elif command -v apt-get >/dev/null; then
    log "installing host packages via apt"
    DEBIAN_FRONTEND=noninteractive apt-get update -y
    DEBIAN_FRONTEND=noninteractive apt-get install -y \
      qemu-kvm libvirt-daemon-system libvirt-clients virtinst qemu-utils dnsmasq-base
  elif command -v dnf >/dev/null; then
    log "installing host packages via dnf"
    dnf install -y qemu-kvm qemu-img libvirt libvirt-client libvirt-daemon-kvm virt-install dnsmasq
  else
    die "no supported package manager (zypper/apt/dnf) found"
  fi
}

enable_daemons() {
  local unit
  if systemctl list-unit-files 2>/dev/null | grep -q '^virtqemud\.socket'; then
    log "enabling modular libvirt daemons"
    for unit in virtqemud.socket virtnetworkd.socket virtstoraged.socket virtlogd.socket virtlockd.socket; do
      if systemctl list-unit-files "$unit" 2>/dev/null | grep -q "^${unit}"; then
        systemctl enable --now "$unit" || warn "could not enable $unit"
      fi
    done
  else
    log "enabling monolithic libvirtd"
    systemctl enable --now libvirtd.socket 2>/dev/null || systemctl enable --now libvirtd.service
  fi
}

add_user_to_libvirt() {
  getent group libvirt >/dev/null || groupadd --system libvirt
  if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -qx libvirt; then
    log "$TARGET_USER already in 'libvirt'"
  else
    log "adding $TARGET_USER to 'libvirt' (re-login required)"
    usermod -aG libvirt "$TARGET_USER"
  fi
}

ensure_pool() {
  if virsh -c qemu:///system pool-info "$POOL" >/dev/null 2>&1; then
    log "storage pool '$POOL' already defined"
  else
    log "defining storage pool '$POOL' at $POOL_DIR"
    virsh -c qemu:///system pool-define-as --name "$POOL" --type dir --target "$POOL_DIR"
  fi
  virsh -c qemu:///system pool-build     "$POOL" >/dev/null 2>&1 || true
  virsh -c qemu:///system pool-start     "$POOL" >/dev/null 2>&1 || true
  virsh -c qemu:///system pool-autostart "$POOL" >/dev/null 2>&1 || true
}

main() {
  log "Day 0 bootstrap (target user: $TARGET_USER)"
  preflight
  install_packages
  enable_daemons
  add_user_to_libvirt
  ensure_pool
  cat <<EOF

Done. Next:
  1) re-login, or:  newgrp libvirt
  2) cd ${SCRIPT_DIR} && tofu init && tofu plan && tofu apply
EOF
}

main "$@"
