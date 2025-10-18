# Remna Nginx & SSL Automation Script

![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)
![GitHub issues](https://img.shields.io/github/issues/ARES11430/remna-nginx-ssl)
![GitHub forks](https://img.shields.io/github/forks/ARES11430/remna-nginx-ssl)
![GitHub stars](https://img.shields.io/github/stars/ARES11430/remna-nginx-ssl)

An interactive shell script to completely automate the setup of **Nginx** as a reverse proxy with a free **Let's Encrypt SSL certificate**. Ideal for services like Remnawave or any other application running in a Docker container.

This script handles everything from installing dependencies to configuring Nginx and managing your SSL certificates, turning a complex process into a few simple prompts.

## ✨ Features

- **🚀 One-Liner Install:** Get started immediately with a single command.
- **🤖 Fully Automated:** Installs Docker, Docker Compose, and `acme.sh` if they are not found.
- **🔒 SSL Made Easy:** Automatically issues and configures a free Let's Encrypt SSL/TLS certificate.
- **MENU Menu-Driven:** A simple, numbered menu guides you through the process. No complex commands to remember.
- **🔄 Renewal Support:** Easily renew your certificates with the same script, which handles stopping and restarting Nginx for you.
- **🌐 Multi-Domain Support:** Secure one or multiple domains/subdomains with a single certificate.

---

## ⚡ Quick Start: One-Liner Installation & Run

This command will download and execute the setup script. It's the fastest way to get started. Run it as root or with `sudo`.

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ARES11430/remna-nginx-ssl/master/setup_nginx.sh)
```

---

## 🛠️ Usage

After running the one-liner, the script will guide you through a series of simple, numbered prompts.

1.  **Prerequisite Check:** The script will first check for `Docker` and `acme.sh`. If either is missing, it will ask for your permission to install it automatically.
2.  **Enter Your Email:** Provide an email address for your Let's Encrypt account registration.
3.  **Configure Domains:**
    - Choose **[1]** for a single domain or **[2]** for multiple domains.
    - Enter your domain name(s) when prompted.
4.  **Choose Action:**
    - **[1] First Time Setup:** Select this if you are running the script for the first time on your server. It will issue a new certificate.
    - **[2] Renew Existing Certificate:** Select this to renew a certificate that is about to expire. The script will use the `--force` flag with `acme.sh`.

Once you've answered the prompts, the script will handle everything else. It will issue the certificate and automatically start the Nginx container.

### 📁 What It Creates

The script will create the following files and directories on your host machine:

- `/opt/remnawave/nginx/`
  - `docker-compose.yml`: The configuration for the Nginx service.
  - `nginx.conf`: The Nginx reverse proxy configuration.
  - `privkey.key`: Your certificate's private key.
  - `fullchain.pem`: Your full certificate chain from Let's Encrypt.

## 🔄 Renewing Your Certificate

Let's Encrypt certificates are valid for 90 days. To renew your certificate, simply run the installation script again.

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ARES11430/remna-nginx-ssl/master/setup_nginx.sh)
```

When prompted, choose the **[2] Renew Existing Certificate** option. The script will automatically:

1.  Stop the running Nginx container to free up the necessary ports.
2.  Force a renewal with Let's Encrypt.
3.  Restart the Nginx container with the renewed certificate.

## 🤝 Contributing

Contributions are welcome! If you have an idea for an improvement or find a bug, please feel free to:

1.  Open an issue to discuss the change.
2.  Fork the repository and submit a pull request.

## 📜 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
