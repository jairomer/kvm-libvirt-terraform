# Guest Cloud-Init Specification

## Purpose

Define the first-boot guest configuration delivered via the NoCloud seed: user creation, SSH key injection, sshd hardening, and daemon startup.

## Requirements

### Requirement: NoCloud datasource

Cloud-init SHALL run in NoCloud mode, reading user-data, meta-data, and network-config from the cidata cdrom. No metadata service or network bootstrapping is required.

#### Scenario: First boot

- **WHEN** the VM boots with the seed attached
- **THEN** cloud-init applies the seed configuration without external services

### Requirement: Hostname

The guest hostname and FQDN SHALL be set from the hostname variable, with `/etc/hosts` managed accordingly.

#### Scenario: Custom hostname

- **WHEN** the hostname variable is changed and applied
- **THEN** the guest reports the new hostname after first boot

### Requirement: Login user

Cloud-init SHALL create the guest user (default `synk`) in the `wheel` group with `/bin/ash` as its shell.

#### Scenario: User provisioning

- **WHEN** first boot completes
- **THEN** the guest user exists, is a member of `wheel`, and logs in with ash

### Requirement: Unlocked account for pubkey auth

The guest account SHALL be left unlocked: `lock_passwd: false` plus an explicit `usermod -p '*'` on first boot. Alpine OpenSSH runs with `UsePAM no` and rejects shadow entries beginning with `!` even for public-key auth; the resulting `*` entry means "no password" while password login remains disabled by policy.

#### Scenario: Pubkey login accepted

- **WHEN** the guest user authenticates with the injected key
- **THEN** OpenSSH accepts the login because the account is not locked

#### Scenario: Password login still refused

- **WHEN** a password authentication is attempted
- **THEN** it is refused by sshd policy despite the account being unlocked

### Requirement: SSH key injection

The host's ed25519 public key (path configurable, default `~/.ssh/id_ed25519.pub`) SHALL be injected into the guest user's `authorized_keys`.

#### Scenario: Key present

- **WHEN** first boot completes
- **THEN** the authorized_keys file for the guest user contains the host public key

#### Scenario: Key rotation

- **WHEN** the public key path points at a new key and the stack is re-applied with a rebuilt root
- **THEN** the guest accepts the new key and rejects the old one

### Requirement: sshd hardening

Cloud-init SHALL write `/etc/ssh/sshd_config.d/60-cloud.conf` disabling password authentication, keyboard-interactive authentication, and root login, while keeping public-key authentication enabled. It SHALL ensure the main `sshd_config` includes the drop-in directory.

#### Scenario: Drop-in written

- **WHEN** first boot completes
- **THEN** the drop-in file exists with the intended directives and the main config includes `sshd_config.d/*.conf`

#### Scenario: No duplicate Include

- **WHEN** the Include line already exists in `sshd_config`
- **THEN** the bootstrap does not insert a second one

### Requirement: Root login disabled

Cloud-init SHALL set `disable_root` so no root account login path is created or enabled.

#### Scenario: Root SSH attempt

- **WHEN** an SSH login as root is attempted
- **THEN** it is refused

### Requirement: sshd enabled and started

The bootstrap SHALL add `sshd` to the default runlevel and restart it so the hardened configuration is in effect on first boot.

#### Scenario: Service state

- **WHEN** first boot completes
- **THEN** `sshd` is enabled at boot and running with the cloud-init configuration
