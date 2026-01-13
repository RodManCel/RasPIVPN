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