# GCP Cloud Run Xray Deployment Script (via Bash)

This script automates the deployment of a high-performance Xray server (supporting Vless-WS, Vless-gRPC, and Trojan) on Google Cloud Run. It handles the configuration, Git cloning, Docker image generation, and Cloud Run deployment.

## 🚀 Key Features

* **Protocol Support:** Vless (WebSocket), Vless (gRPC), and Trojan.
* **Customization:** Allows choosing region, CPU/Memory limits, service name, and UUID/Password.
* **Dependencies Avoided:** Does not rely on external tools like `bc` or `uuidgen`.
* **Telegram Sharing:** Option to share configuration links via Telegram Bot.

---

## 🛠️ Prerequisites

Before running the deployment script, ensure you have the following installed and configured on your local machine or cloud environment (e.g., Cloud Shell):

1.  **Google Cloud CLI (`gcloud`):** Must be installed and configured.
    * Authenticate: `gcloud auth login`
    * Set Project: `gcloud config set project YOUR_PROJECT_ID`
2.  **Docker:** Required for building the container image locally before pushing to Artifact Registry.
3.  **Git:** Required for cloning the repository containing the Xray configurations and Dockerfile.
4.  **Template Files:** The required configuration files (`.tmpl` files) and the `Dockerfile` must exist in the Git repository specified in the script (`https://github.com/ahlflk/GCP-XRAY.git`).

---

## 📂 Required Repository Files

The deployment script expects the following files to be present in the root directory of the cloned repository (`GCP-XRAY`):

| File Name | Description | Required For |
| :--- | :--- | :--- |
| **`Dockerfile`** | Defines the container image (downloads Xray, copies `config.json`, and sets the entry point). | All Protocols |
| **`config_vless_ws.json.tmpl`** | Template for Vless over WebSocket configuration. | Vless (WS) |
| **`config_vless_grpc.json.tmpl`** | Template for Vless over gRPC configuration. | Vless (gRPC) |
| **`config_trojan.json.tmpl`** | Template for Trojan configuration. | Trojan |

***Note:*** *The template files must use placeholders like `$USER_ID`, `$HOST_DOMAIN`, `$VLESS_PATH`, and `$GRPC_SERVICE_NAME` which the Bash script will automatically replace.*

---

## 📋 Configuration Summary

The script will guide you through the following setup steps:

1.  **Protocol Selection:** Choose Vless (WS), Vless (gRPC), or Trojan.
2.  **Region Selection:** Select the desired GCP Cloud Run region (e.g., `us-central1`, `asia-southeast1`).
3.  **Resource Limits:** Define **CPU Cores** (`1` to `16`) and **Memory** (`512Mi` to `32Gi`).
4.  **Service Name:** The name for the Cloud Run service (e.g., `gcp-ahlflk`).
5.  **Host Domain (SNI):** The fake domain used for TLS/SNI (e.g., `m.googleapis.com`).
6.  **User ID/Password:** Configure the UUID (Vless) or Password (Trojan).
7.  **Telegram Sharing:** Option to send the generated configuration link to a private chat, channel, group, or both.

---

## ⚙️ How to Run the Script

1.  **Save the Script:** Save the provided Bash code as a file named `deploy.sh`.
2.  **Give Execution Permission:**
    ```bash
    chmod +x gcp-xray.sh
    ```
3.  **Run the Deployment:**
    ```bash
    bash <(curl -Ls https://raw.githubusercontent.com/ahlflk/GCP-XRAY/refs/heads/main/gcp-xray.sh)
    ```

Follow the on-screen prompts to configure your Xray server. The script will handle the API enablement, Git cloning, configuration generation, Docker build, and final deployment to Google Cloud Run.
