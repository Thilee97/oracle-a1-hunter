# Oracle A1 Hunter — fixed Telegram every-run version

- Oracle Singapore
- VM.Standard.A1.Flex
- 2 OCPU / 12 GB RAM
- Tries every 5 minutes with `*/5 * * * *`
- Telegram heartbeat after every unsuccessful capacity check
- Detailed Telegram message + JSON after successful creation
- Automatically disables itself when the VPS exists/was created

Replace the existing repository files with this package, commit, and push.
Your existing GitHub Secrets do not need to be re-entered.
