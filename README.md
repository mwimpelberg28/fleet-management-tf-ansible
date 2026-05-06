# Grafana Alloy + Fleet Management — Terraform & Ansible

Provisions [Grafana Alloy](https://grafana.com/docs/alloy/latest/) on Linux and
Windows hosts with [Fleet Management](https://grafana.com/docs/grafana-cloud/send-data/fleet-management/)
remote configuration. Terraform creates the Fleet Management pipelines in
Grafana Cloud; Ansible installs Alloy on each host and points it at Fleet
Management for its config.

```
.
├── terraform/
│   ├── main.tf                        # Grafana Cloud provider + access policy/token
│   ├── pipelines.tf                   # Fleet Management pipeline resources
│   ├── variables.tf
│   ├── terraform.tfvars.example       # Copy to terraform.tfvars and fill in
│   └── pipelines/
│       ├── linux_host.alloy.tftpl     # Alloy config served to Linux collectors
│       └── windows_host.alloy.tftpl   # Alloy config served to Windows collectors
└── ansible/
    ├── linux-alloy/
    │   ├── playbook.yml               # apt-installs Alloy on Linux
    │   ├── windows-playbook.yml       # alternative: NSIS-installer-based Windows install
    │   ├── inventory                  # Linux hosts (placeholder)
    │   ├── windows.ini                # Windows hosts (placeholder)
    │   ├── vars/
    │   │   ├── main.yml.example       # Copy to main.yml and fill in
    │   │   └── secrets.yml            # Vault-encrypted; holds the Alloy write token
    │   └── templates/
    │       ├── alloy.env.j2           # Renders /etc/alloy/alloy.env
    │       └── config.alloy.j2        # Renders the local remotecfg block
    └── windows-alloy/
        ├── windows-playbook.yml       # Uses Grafana Cloud's official Windows installer
        ├── windows.ini                # Windows hosts (placeholder)
        ├── vars/
        │   ├── main.yml.example
        │   └── secrets.yml
        └── templates/
            ├── alloy.env.j2
            └── config.alloy.j2
```

## How the pieces fit together

1. **Terraform** provisions a Fleet Management access policy and token in your
   Grafana Cloud stack, then creates two pipelines (`linux_host`, `windows_host`)
   that target collectors via matchers (`collector.os` + `env`). Pipeline
   contents come from the `.tftpl` templates and are served by Fleet Management
   to whichever Alloy collectors match.
2. **Ansible** installs Alloy on each managed host and writes a small local
   `config.alloy` whose only job is the `remotecfg` block — pointing Alloy at
   Fleet Management to fetch the real pipeline config. Hosts identify
   themselves with `env` and `host` attributes; pipelines select them via
   matchers.
3. The `GCLOUD_RW_API_KEY` env var holds the Alloy write token used by the
   pipelines for `prometheus.remote_write` / `loki.write`. Ansible deploys it
   via `alloy.env`; the pipelines reference it with `sys.env(...)`.

## Prerequisites

- A Grafana Cloud stack and a [Cloud Access Policy token](https://grafana.com/docs/grafana-cloud/account-management/authentication-and-permissions/access-policies/)
  with scopes `stacks:read`, `accesspolicies:read`, `accesspolicies:write`,
  `accesspolicies:delete`. This is used by Terraform to provision the Fleet
  Management token.
- A second token (an Alloy write token) covering metrics + logs push and
  fleet-management read/write. This is the value that goes into
  `vault_gcloud_rw_api_key` for Ansible.
- OpenTofu / Terraform ≥ 1.5
- Ansible (with `ansible.windows` collection if you're managing Windows hosts)
- WinRM enabled on Windows targets

## Setup

### 1. Terraform — provision Fleet Management pipelines

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars — set cloud_access_policy_token, stack_slug, environment

tofu init    # or: terraform init
tofu plan
tofu apply
```

After `apply`, two pipelines exist in your Grafana Cloud Fleet Management
instance and will be served to any Alloy collector reporting the matching
`collector.os` + `env` attributes.

### 2. Ansible — install Alloy on hosts

For each role you're using (`linux-alloy/` and/or `windows-alloy/`):

```bash
cd ansible/linux-alloy
cp vars/main.yml.example vars/main.yml
# edit vars/main.yml — set your Grafana Cloud metrics/logs/FM IDs and URLs

ansible-vault encrypt vars/secrets.yml
# or create it from scratch:
#   ansible-vault create vars/secrets.yml
# and add: vault_gcloud_rw_api_key: "<your-alloy-write-token>"
```

Find the per-stack IDs and URLs in **Grafana Cloud → Connections → details
page** for Prometheus, Loki, and Fleet Management.

Update the inventory file with your hosts:

```bash
# edit ansible/linux-alloy/inventory       (Linux hosts)
# edit ansible/<role>/windows.ini          (Windows hosts; fill IP, ansible_password)
```

For local-only edits you don't want to commit, use the gitignored variants
`inventory.local` / `windows.local.ini` and pass them via `-i`.

Then run:

```bash
# Linux
ansible-playbook -i inventory playbook.yml --ask-vault-pass

# Windows (NSIS installer approach)
ansible-playbook -i windows.ini windows-playbook.yml --ask-vault-pass

# Windows (Grafana Cloud installer script approach)
cd ../windows-alloy
ansible-playbook -i windows.ini windows-playbook.yml --ask-vault-pass
```

The two Windows playbooks are alternatives — pick whichever fits your
environment. Both end up with Alloy running as a service and configured for
remotecfg.

### 3. Verify

In Grafana Cloud → **Connections → Fleet Management → Collectors**, you should
see each host check in within `gcloud_fm_poll_frequency` (default 60s),
reporting attributes `env=<your env>`, `host=<hostname>`,
`collector.os=linux|windows`. The matching pipeline is then pushed to it.

## Sensitive files (never commit)

The `.gitignore` already excludes the obvious ones, but be aware of:

- `terraform/terraform.tfvars` — contains your cloud access policy token
- `terraform/terraform.tfstate*` — contains the provisioned token
- `ansible/*/vars/main.yml` — contains stack IDs/URLs
- `ansible/*/vars/secrets.yml` — vault-encrypted, but the unencrypted form
  contains the Alloy write token
- Any inventory file with real IPs/passwords — prefer the `.local` variants
  documented above

If you cloned this repo as a starting point, audit and rotate any secrets
before reusing them.
