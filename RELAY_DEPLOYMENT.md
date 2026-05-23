# Relay Deployment

Pet Y Relay is a small Node.js service. The current implementation keeps runtime state in memory, which is enough for early friend testing.

## Requirements

- Linux server
- Node.js 18 or newer
- TCP port `8787` open to users who should connect

## Manual Run

```bash
HOST=0.0.0.0 PORT=8787 npm start
```

Health check:

```bash
curl http://your-relay-host:8787/api/health
```

## systemd Example

Assume the project is deployed to `/opt/pet-y`.

Create `/etc/systemd/system/pet-y-relay.service`:

```ini
[Unit]
Description=Pet Y Relay
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/pet-y
Environment=HOST=0.0.0.0
Environment=PORT=8787
ExecStart=/usr/bin/node /opt/pet-y/server.js
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now pet-y-relay
sudo systemctl status pet-y-relay --no-pager -l
```

## Notes

- This Relay does not persist accounts, friendships, profiles, or active visits yet.
- Pet memories are stored locally by the owner's Runtime.
- Put the Relay behind HTTPS before treating it as a production service.
