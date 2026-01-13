# Raspberry Pi 3B WireGuard VPN with AWS Route 53 (DDNS)

This project allows you to set up a professional-grade VPN home server using a Raspberry Pi 3B. It solves the "Dynamic IP" problem by using **Amazon Route 53** as a Dynamic DNS (DDNS) provider.

## Project Structure
* `aws/CloudFormationTemplates/createDomainAndUser.yml`: AWS infrastructure as code.
* `scripts/setup_vpn.sh`: Main automation script for the Raspberry Pi.

---

## Step 1: AWS Infrastructure Deployment

Before touching the Raspberry Pi, you need to prepare the AWS environment using the provided CloudFormation template.

1.  **Log in** to your AWS Management Console.
2.  Navigate to **CloudFormation** > **Create stack** (with new resources).
3.  Upload the file: `aws/CloudFormationTemplates/createDomainAndUser.yml`.
4.  **Fill in the Parameters**:
    * `HostedZoneId`: Your Route 53 Hosted Zone ID (e.g., `Z0123456789ABC`).
    * `DomainName`: The full domain you want for your VPN (e.g., `vpn.yourdomain.es`).
5.  **Important**: Once the stack is created, go to the **Outputs** tab. Copy the `AccessKeyId` and `SecretAccessKey`. **You will need these for Step 3.**

---

## Step 2: Raspberry Pi Automation

Log into your Raspberry Pi via SSH and follow these steps to deploy the local environment.

### 1. Create the Setup Script
```bash
nano setup_vpn.sh
```
Paste the content of the `scripts/setup_vpn.sh` file from this repository.

### 2. Update Script Parameters
Edit the header of `setup_vpn.sh` with your specific data:

* **MY_DOMAIN**: Your VPN subdomain (e.g., `vpn.yourdomain.es`).
* **MY_ZONE_ID**: Your AWS Zone ID.
* **MY_LOCAL_IP**: The static IP of your Raspberry Pi (e.g., `192.168.1.50`).
* **MY_ROUTER_GW**: Your router's IP (usually `192.168.1.1`).

### 3. Execute the Script
```bash
chmod +x setup_vpn.sh
./setup_vpn.sh
```
The script will automatically create `~/scripts/update_route53.sh`, configure the Cron job (every 5 mins), and start the PiVPN installation.

---

## Step 3: Final Configuration

### AWS CLI Credentials
The update script needs permission to talk to AWS. Run the following command and enter the keys you got from the CloudFormation Outputs:

```bash
aws configure
```
* **AWS Access Key ID**: `[Your Access Key]`
* **AWS Secret Access Key**: `[Your Secret Key]`
* **Default region name**: `us-east-1` (or your preferred region)
* **Default output format**: `json`

### Router Port Forwarding
You must tell your router to send VPN traffic to the Raspberry Pi:

* **Protocol**: `UDP`
* **Port**: `51820`
* **Destination IP**: Your Raspberry Pi's local IP.

---
## Step 4: Adding VPN Clients
Now that the server is running, you can add devices (phones, laptops).

### To add a new device:
```bash
pivpn add
```
Follow the prompts to give the client a name.

### To connect a mobile phone (QR Code):
```bash
pivpn -qr [client_name]
```
Scan the generated QR code with the **WireGuard app** (available on iOS and Android).

### To list or remove clients:
* **List**: `pivpn list`
* **Remove**: `pivpn -d [client_name]`

---

## How it works (The Tech Stack)
* **Route 53**: Acts as your DNS server.
* **Cron Job**: Every 5 minutes, `update_route53.sh` checks your home's public IP.
* **AWS CLI**: If the IP has changed, the script sends an `UPSERT` request to AWS to update your domain.