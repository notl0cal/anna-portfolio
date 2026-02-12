# Anna's Portfolio

A warm, minimal portfolio website for Anna, a graphic designer.

## Structure

```
anna-portfolio/
├── index.html       # Main page: Work → About → Blog Preview → Contact
├── services.html    # Services → Clients → Testimonials → Contact
├── blog.html        # Full blog with all articles
└── .github/
    └── scripts/
        ├── system-hardening.sh  # Server security setup
        └── deploy.sh            # Deployment automation
```

## Tech Stack

- Pure HTML/CSS (no frameworks)
- Responsive design
- Smooth animations
- Minimal, organic aesthetic

## Local Development

```bash
# Start local server
python3 -m http.server 8000

# View at http://localhost:8000
```

## Deployment

### Prerequisites

- Fresh Linux server (Ubuntu 20.04+ recommended)
- SSH access with sudo privileges

### Quick Deploy

1. **Run system hardening:**
   ```bash
   scp .github/scripts/system-hardening.sh deploy@your-server:/tmp/
   ssh deploy@your-server "sudo bash /tmp/system-hardening.sh"
   ```

2. **Deploy the site:**
   ```bash
   scp -r . deploy@your-server:/tmp/anna-portfolio
   ssh deploy@your-server "cd /tmp/anna-portfolio && ./.github/scripts/deploy.sh your-domain.com prod"
   ```

### Manual Deployment

```bash
# On the server:
git clone https://github.com/notl0cal/anna-portfolio.git /var/www/anna-portfolio
cd /var/www/anna-portfolio

# Start simple HTTP server on port 8000
nohup python3 -m http.server 8000 > /var/log/anna-portfolio.log 2>&1 &

# Or use Caddy for HTTPS:
# 1. Install Caddy: curl https://getcaddy.com | bash
# 2. Create Caddyfile with reverse proxy
# 3. sudo systemctl enable caddy
```

## Customization

### Colors

Edit CSS variables in each HTML file:
```css
:root {
    --bg: #fdf8f5;       /* Background */
    --text: #2d2a26;     /* Text color */
    --accent: #e07a5f;   /* Accent color */
    --muted: #8b8178;    /* Muted text */
    --card: #ffffff;     /* Card background */
}
```

### Content

- **Projects:** Edit `index.html` project cards
- **Services:** Edit `services.html` service cards
- **Clients:** Edit `services.html` client logos
- **Testimonials:** Edit `services.html` testimonial cards
- **Blog:** Edit `blog.html` article cards

## Scripts

### system-hardening.sh

Secures a fresh Linux server:
- Creates non-root user with sudo
- Configures SSH key-only authentication
- Sets up UFW firewall
- Installs Fail2Ban
- Configures automatic security updates
- Hardens kernel parameters

**Usage:**
```bash
sudo ./system-hardening.sh [hostname]
```

### deploy.sh

Automates deployment to production:
- Clones/updates from GitHub
- Starts web service (Python HTTP or Node.js)
- Configures Caddy reverse proxy with HTTPS
- Verifies deployment

**Usage:**
```bash
./deploy.sh <command> [server] [environment]

Commands:
  deploy     Full deployment
  start      Start service
  stop       Stop service
  restart    Restart service
  status     Show status
  rollback   Revert to previous version
  verify     Check deployment health
```

## HTTPS/SSL

The deployment script automatically configures HTTPS using Caddy:

```bash
./deploy.sh deploy your-domain.com prod
```

Caddy will:
- Obtain SSL certificates automatically via Let's Encrypt
- Redirect HTTP to HTTPS
- Serve your site with modern TLS

## License

Copyright © 2026 Anna. All rights reserved.

## Author

Created with care by Lumi ✨
