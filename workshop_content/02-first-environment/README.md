# Setting Up Your First Development Environment

In this module, you'll learn how to create and connect to your first cloud development environment using Coder.

## Creating a Linux-based Development Environment

### Step 1: Log in to Coder

1. Open your web browser and navigate to the Coder URL provided by your workshop instructor.
2. Log in using the credentials provided to you.

### Step 2: Create a New Workspace

1. From the Coder dashboard, click on the "Create Workspace" button.
2. Select the "AWS Linux Base" template.
3. Configure your workspace with the following settings:
   - **Name**: Choose a name for your workspace (e.g., `my-dev-env`)
   - **AWS Region**: Select the AWS region closest to you
   - **Instance Type**: Choose `t3.medium` (2 vCPU, 4 GiB RAM)
   - **Disk Size**: Set to 30 GiB
4. Click "Create" to provision your workspace.

The provisioning process will take a few minutes. Coder is creating an EC2 instance, configuring security groups, and setting up the development environment with all the necessary tools.

### Step 3: Explore Your Workspace

Once your workspace is ready, you'll see it in the "Active" state on the dashboard. Click on it to view the workspace details.

On the workspace page, you'll see:
- Resource usage metrics (CPU, RAM, Disk)
- Connection options
- Installed applications
- Terminal access

## Connecting to Your Environment

Coder provides multiple ways to connect to your development environment:

### Option 1: Web-based VS Code

1. On your workspace page, click on the "VS Code" application icon.
2. This will open VS Code in your browser, connected to your cloud environment.
3. You can now start coding directly in the browser!

### Option 2: SSH Access

You can also connect to your environment using SSH:

1. On your workspace page, click on the "SSH" tab.
2. Follow the instructions to configure SSH access:
   - Download your SSH key
   - Add the SSH config to your local `~/.ssh/config` file
3. Connect using your terminal: `ssh coder.my-dev-env`

### Option 3: VS Code Remote SSH

For the best experience, you can use VS Code's Remote SSH extension:

1. Install the [Remote SSH extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-ssh) in VS Code.
2. Configure SSH access as described in Option 2.
3. In VS Code, press `F1` and select "Remote-SSH: Connect to Host..."
4. Select "coder.my-dev-env" from the list.
5. VS Code will connect to your cloud environment, giving you a fully-featured IDE experience.

## Installing and Configuring Development Tools

Your environment comes pre-installed with several development tools:

- Git
- Docker
- AWS CLI
- Node.js
- Python

Let's verify these tools are working correctly:

### Check Git Configuration

Open a terminal in your environment and run:

```bash
git --version
git config --global --list
```

Configure Git with your information:

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Verify AWS CLI

Check that the AWS CLI is installed and configured:

```bash
aws --version
aws sts get-caller-identity
```

You should see information about the AWS identity you're using.

### Test Docker

Verify that Docker is working:

```bash
docker --version
docker run hello-world
```

You should see a "Hello from Docker!" message, confirming Docker is working correctly.

## Exercise: Clone and Run a Sample Application

Let's put your new environment to use by cloning and running a sample application:

1. Open a terminal in your environment.
2. Clone the sample application:
   ```bash
   git clone https://github.com/aws-samples/aws-cdk-examples.git
   cd aws-cdk-examples/typescript/static-site
   ```
3. Install dependencies:
   ```bash
   npm install
   ```
4. Explore the code in VS Code to understand what it does.

## Next Steps

Congratulations! You've successfully created and connected to your first cloud development environment. In the next module, we'll explore how to [Work with AWS Services](../03-aws-services/README.md) from your development environment.
