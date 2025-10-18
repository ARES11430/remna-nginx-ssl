# Remna Nginx & SSL Automation Script

![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)
![GitHub issues](https://img.shields.io/github/issues/ARES11430/remna-nginx-ssl)
![GitHub forks](https://img.shields.io/github/forks/ARES11430/remna-nginx-ssl)
![GitHub stars](https://img.shields.io/github/stars/ARES11430/remna-nginx-ssl)

An interactive shell script to completely automate the setup of **Nginx** as a reverse proxy with a free **Let's Encrypt SSL certificate**. It's expertly designed for services like the **Remnawave Panel** and can seamlessly handle both single-service and multi-service (e.g., Panel + Subscription Page) deployments.

This script manages everything from installing dependencies to generating complex Nginx configurations and managing your SSL certificates, turning a difficult process into a few simple prompts.

## ✨ Features

- **🚀 One-Liner Install:** Get started immediately with a single command.
- **🤖 Fully Automated:** Installs Docker, Docker Compose, and `acme.sh` if they are not found.
- **🔒 SSL Made Easy:** Automatically issues a free Let's Encrypt SSL/TLS certificate for all your domains.
- **MENU Menu-Driven:** A simple, interactive menu guides you through the process. No complex commands to remember.
- **🔄 Renewal & Re-configuration:** Easily renew your certificates. You can also change your entire setup (e.g., add a new service) during the renewal process, and the script will automatically generate the correct new Nginx configuration.
- **🌐 Multi-Domain & Multi-Service Support:**
  - Secure one or multiple domains for a single application.
  - Effortlessly configure Nginx for a multi-service setup (like a panel and a subscription page), each on its own domain, using a single shared SSL certificate.

---

## ⚡ Quick Start: One-Liner Installation & Run

This command will download and execute the setup script. It's the fastest way to get started. Run it as root or with `sudo`.

```bash
bash <(curl -Ls https://raw.githubusercontent.com/ARES11430/remna-nginx-ssl/master/setup_nginx.sh)
```

---

## 🛠️ Usage

After running the one-liner, the script will guide you through a series of simple, numbered prompts.

1.  **Prerequisite Check:** The script first checks for Docker and `acme.sh`. If either is missing, it will ask for your permission to install it automatically.

2.  **Choose Action (New or Renew):**

    - **[1] First Time Setup:** Select this if you are running the script for the first time. It will create configuration files and issue a new certificate.
    - **[2] Renew Existing Certificate:** Select this to renew a certificate that is about to expire.

3.  **Enter Your Email:** Provide an email address for your Let's Encrypt account registration.

4.  **Specify Your Setup:** The script will ask if you need to configure a Subscription Page in addition to the main panel.

5.  **Configure Domains:** The prompts will adapt based on your previous answer:

    - If you answered **'y'** (Panel + Subscription Page), it will ask you to enter the Panel Domain and the Subscription Page Domain separately.
    - If you answered **'n'** (Panel Only), it will ask for your primary domain and any additional domains for the panel.

6.  **Automation Takes Over:** Once you've answered the prompts, the script handles everything else. It will generate the correct `nginx.conf`, issue a certificate for all your specified domains, and start the Nginx container.

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
