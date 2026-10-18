# State Specification

## Purpose

Define where OpenTofu state lives and how it is protected from accidental publication.

## Requirements

### Requirement: Local state

State SHALL be local, at `tf/terraform.tfstate` alongside the configuration. No remote backend is used.

#### Scenario: Standard workflow

- **WHEN** `tofu init`, `plan`, or `apply` runs in `tf/`
- **THEN** state is read from and written to `tf/terraform.tfstate`

### Requirement: State excluded from version control

State files (`*.tfstate` and `*.tfstate.*`) SHALL be gitignored. State contains the cloud-init seed including the SSH public key and network details, and SHALL NOT be committed.

#### Scenario: Git status after apply

- **WHEN** apply writes state and `git status` is run
- **THEN** no state file appears as untracked or modified

#### Scenario: Attempted commit of state

- **WHEN** someone attempts to `git add` a state file
- **THEN** gitignore rules prevent it from being staged

### Requirement: Recoverable by re-apply

Loss of state SHALL be recoverable by re-applying the stack. No import workflow or remote state restore is required; destroying and recreating the VM is an acceptable outcome of state loss.

#### Scenario: State deleted

- **WHEN** `terraform.tfstate` is removed and the stack is re-applied
- **THEN** the infrastructure is recreated from configuration, with the guest rebuilt from the pristine base image
