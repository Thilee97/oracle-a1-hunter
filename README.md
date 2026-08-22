# Oracle A1 Hunter — 2 OCPU / 12 GB + Telegram

GitHub Actions workflow that tries to create exactly one Oracle Cloud
`VM.Standard.A1.Flex` instance with:

- 2 OCPU
- 12 GB RAM
- Singapore: `ap-singapore-1`
- Retry every 5 minutes
- Duplicate protection by instance name
- Telegram notification after successful creation
- Telegram sends:
  - a compact VPS summary
  - `vps_details.json` containing detailed instance/network/image/boot-volume information
- Workflow disables itself after an instance exists or is created

## Required GitHub repository secrets

Create these under:

`Settings → Secrets and variables → Actions → New repository secret`

### Oracle

| Secret | Value |
|---|---|
| `OCI_TENANCY_OCID` | Oracle tenancy OCID |
| `OCI_USER_OCID` | Oracle user OCID |
| `OCI_FINGERPRINT` | API key fingerprint |
| `OCI_PRIVATE_KEY` | Full PEM private key |
| `OCI_REGION` | `ap-singapore-1` |
| `OCI_COMPARTMENT_OCID` | Compartment containing the instance |
| `OCI_SUBNET_OCID` | Existing subnet OCID |
| `OCI_IMAGE_OCID` | ARM/aarch64 image OCID |
| `OCI_SSH_PUBLIC_KEY` | SSH public key |

### Telegram

| Secret | Value |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Token from BotFather |
| `TELEGRAM_CHAT_ID` | Your Telegram user/group chat ID |

## Telegram message after success

The text message includes:

- Instance name and state
- Region
- Availability Domain
- Fault Domain
- Shape
- CPU / RAM
- Public IP / Private IP
- Hostname / FQDN
- Image
- Boot volume size
- Creation time
- Instance OCID
- VNIC OCID
- Subnet OCID
- Boot Volume OCID
- Recommended SSH username
- Ready-to-copy SSH command, for example:
  `ssh -i ~/.ssh/oracle_a1 ubuntu@PUBLIC_IP`

A JSON document is also attached with more structured details such as:

- Shape configuration
- Image OS/version/architecture
- VNIC MAC address and NSGs
- Boot volume state, VPU/GB and hydration state
- Tags
- Launch mode

For safety, the JSON intentionally does NOT contain:

- OCI private API key
- GitHub secrets
- Telegram bot token
- Instance metadata / SSH authorized keys

## First test

After adding all secrets:

`Actions → Oracle A1 Hunter → Run workflow`

If Oracle returns an ordinary A1 capacity error, the setup is working and the
scheduled run will try again five minutes later.


## SSH key reminder

Before enabling the hunter, create your SSH key on your Linux PC:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/oracle_a1
```

Put only the contents of:

```bash
cat ~/.ssh/oracle_a1.pub
```

into the GitHub secret `OCI_SSH_PUBLIC_KEY`.

Keep `~/.ssh/oracle_a1` private on your own computer. The workflow never sends
or uploads this SSH private key.

After success, Telegram includes the appropriate login command. For a Canonical
Ubuntu image it will normally look like:

```bash
ssh -i ~/.ssh/oracle_a1 ubuntu@PUBLIC_IP
```
