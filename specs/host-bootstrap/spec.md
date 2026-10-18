# Host Bootstrap Specification

## Purpose

Define the behavior of the Day-0 host bootstrap (`tf/day0.sh`): preparing a bare Linux host so that OpenTofu can provision libvirt VMs against `qemu:///system` without manual steps.

## Requirements

### Requirement: Idempotent and re-runnable

The bootstrap SHALL be idempotent: running it any number of times on an already-configured host SHALL converge to the same state without errors and without duplicating configuration.

#### Scenario: First run on a fresh host

- **WHEN** `sudo ./day0.sh` is executed on a host without qemu/libvirt installed
- **THEN** packages are installed, daemons enabled, the invoking user is added to the `libvirt` group, and the `default` storage pool is defined and started

#### Scenario: Second run on a configured host

- **WHEN** `sudo ./day0.sh` is executed again on the same host
- **THEN** each step reports it is already satisfied and makes no changes

### Requirement: Invoking user context

The script SHALL re-exec itself under root via sudo when not already root, and SHALL capture the original invoking user from `SUDO_USER`. It SHALL fail with a clear error when run directly as root without a normal invoking user.

#### Scenario: Run without sudo

- **WHEN** the script is executed as a normal user and sudo is available
- **THEN** it re-executes itself as root, preserving the original user for group membership

#### Scenario: Run directly as root

- **WHEN** the script is executed as root with no `SUDO_USER`
- **THEN** it exits with an error instructing the user to run it via sudo as their normal user

### Requirement: Package installation across distributions

The script SHALL install the required host packages (qemu, libvirt, dnsmasq, virt-install) using the first available package manager among zypper, apt, and dnf. It SHALL abort with a clear error when none is present.

#### Scenario: openSUSE host

- **WHEN** zypper is available
- **THEN** qemu/libvirt/dnsmasq/virt-install packages are installed via zypper in non-interactive mode

#### Scenario: Install skipped

- **WHEN** the script is invoked with `--no-install`
- **THEN** package installation is skipped and the remaining steps still run

#### Scenario: Unsupported distribution

- **WHEN** none of zypper, apt, or dnf is available
- **THEN** the script exits with an error naming the missing package managers

### Requirement: libvirt daemon enablement

The script SHALL prefer modular libvirt daemons (`virtqemud`, `virtnetworkd`, `virtstoraged`, `virtlogd`, `virtlockd`) when their socket units exist, and SHALL fall back to enabling monolithic `libvirtd` otherwise. Daemons that cannot be enabled SHALL produce a warning, not a hard failure.

#### Scenario: Modular daemons present (openSUSE Tumbleweed)

- **WHEN** `virtqemud.socket` exists among the host's unit files
- **THEN** the five modular daemon sockets are enabled and started

#### Scenario: Monolithic host

- **WHEN** no modular daemon units exist
- **THEN** `libvirtd.socket` (or `libvirtd.service`) is enabled and started

### Requirement: libvirt group membership

The script SHALL ensure the `libvirt` group exists and that the invoking user is a member. A fresh membership change SHALL be reported as requiring a re-login.

#### Scenario: User not yet in group

- **WHEN** the invoking user is not a member of `libvirt`
- **THEN** the user is added and the script notes that a re-login (or `newgrp libvirt`) is required

### Requirement: Default storage pool

The script SHALL ensure a `default` storage pool (directory-backed, `/var/lib/libvirt/images`) exists, is built if needed, is started, and is set to autostart. A pool that already exists SHALL be left as-is aside from the start/autostart enforcement.

#### Scenario: Pool missing

- **WHEN** the `default` pool is not defined
- **THEN** it is defined as a directory pool, built, started, and configured to autostart

#### Scenario: Pool already defined

- **WHEN** the `default` pool already exists
- **THEN** no duplicate definition occurs; start and autostart are still enforced

### Requirement: KVM availability preflight

The script SHALL warn when `/dev/kvm` is absent, since KVM acceleration will be unavailable, without aborting the bootstrap.

#### Scenario: No KVM device

- **WHEN** `/dev/kvm` does not exist
- **THEN** a warning is printed and the script continues
