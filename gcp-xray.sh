#!/bin/bash

# ===============================================
# 🛡️ Error Handling
# ===============================================
# Exit immediately if a command exits with a non-zero status, 
# exit immediately if any command in a pipeline fails, 
# and treat unset variables as an error.
set -euo pipefail

# 🎨 Color Codes & Emojis
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
ORANGE='\033[0;38;5;208m'
WHITE='\033[0;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m' # No Color

# 🌟 Emoji Definitions
EMOJI_START="🚀"
EMOJI_SUCCESS="✅"
EMOJI_FAIL="❌"
EMOJI_INFO="💡"
EMOJI_WAIT="⏳"
EMOJI_PROMPT="❓"
EMOJI_CONFIG="⚙️"
EMOJI_LINK="🔗"
EMOJI_TITLE="✨"
EMOJI_PROTO="🌐"
EMOJI_LOCATION="🗺️"
EMOJI_CPU="🧠"
EMOJI_MEMORY="💾"
EMOJI_NAME="🏷️"
EMOJI_DOMAIN="🛡️"
EMOJI_TELE="📢"

# 🗂️ Global Variables
REPO_URL="https://github.com/ahlflk/GCP-XRAY.git"
REPO_DIR="GCP-XRAY"
DEFAULT_SERVICE_NAME="gcp-ahlflk"
DEFAULT_HOST_DOMAIN="m.googleapis.com"
DEFAULT_GRPC_SERVICE="ahlflk"
DEFAULT_TROJAN_PASS="ahlflk"
DEFAULT_UUID="3675119c-14fc-46a4-b5f3-9a2c91a7d802"
GCP_PROJECT_ID=""
CPU_LIMIT=""
MEMORY_LIMIT=""
USER_ID=$DEFAULT_UUID
GRPC_SERVICE_NAME=$DEFAULT_GRPC_SERVICE
VLESS_PATH="/vless"
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
TELEGRAM_CHOICE="1" # Default: Do Not Send

# -----------------------------------------------
# 🖼️ Helper Functions
# -----------------------------------------------

# Function for Header Title (Fixed Syntax Error - Short Border)
header() {
    local title="$1"
    local emoji="$2"
    local text="$emoji $title"
    local text_len=${#text}
    local total_width=$(( text_len + 4 )) 

    local border_line=""
    for ((i=1; i<=$total_width; i++)); do
        if [ $((i % 2)) -eq 0 ]; then
            border_line+="×"
        else
            border_line+="="
        fi
    done
    
    echo -e "\n${ORANGE}${BOLD}"
    echo " ${border_line} "
    echo " $text  |" 
    echo " ${border_line} "
    echo -e "${NC}"
}

# UUID Generator using Bash (to avoid 'uuidgen' dependency)
generate_uuid() {
    local N=16
    local uuid_string=""
    local hex_chars="0123456789abcdef"
    
    for i in {1..32}; do
        uuid_string="${uuid_string}${hex_chars:$(( RANDOM % $N )):1}"
    done

    local version="4"
    local variant="${hex_chars:$(( (RANDOM % 4) + 8 )):1}" 

    echo "${uuid_string:0:8}-${uuid_string:8:4}-${version}${uuid_string:13:3}-${variant}${uuid_string:17:3}-${uuid_string:20:12}"
}


# General Helpers
log() { echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> deploy.log; }
error() { echo -e "${RED}ERROR:${NC} $1" 1>&2; log "ERROR: $1"; exit 1; }
warn() { echo -e "${YELLOW}WARNING:${NC} $1"; log "WARNING: $1"; }
info() { echo -e "${BLUE}INFO:${NC} $1"; log "INFO: $1"; }
selected() { echo -e "${EMOJI_SUCCESS} ${GREEN}${BOLD}Selected:${NC} ${CYAN}${UNDERLINE}$1${NC}"; log "Selected: $1"; }
progress_bar() {
    local duration=$1; local bar_length=20; local elapsed=0;
    echo -n "${EMOJI_WAIT} ${CYAN}Processing...${NC}"
    while [ "$elapsed" -lt "$duration" ]; do
        local progress=$(( ($elapsed * $bar_length) / $duration )); local filled=$(printf '%.0s#' $(seq 1 $progress)); local empty=$(printf '%.0s-' $(seq 1 $(( $bar_length - $progress ))));
        printf "\r${EMOJI_WAIT} [${GREEN}${filled}${CYAN}${empty}${NC}] %3d%%" $(( ($elapsed * 100) / $duration ))
        sleep 1; elapsed=$(( $elapsed + 1 ))
    done
    printf "\r${EMOJI_WAIT} [${GREEN}$(printf '%.0s#' $(seq 1 $bar_length))${NC}] 100%% Complete! ${EMOJI_SUCCESS}\n"
}
validate_uuid() { local uuid_pattern="^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"; if [[ ! "$1" =~ $uuid_pattern ]]; then error "Invalid UUID format: $1 🚫"; fi; return 0; }
validate_bot_token() { local token_pattern="^[0-9]{9,10}:[a-zA-Z0-9_-]{35}$"; if [[ ! "$1" =~ $token_pattern ]]; then error "Invalid Telegram Bot Token format 🚫"; fi; return 0; }
validate_channel_id() { if [[ ! "$1" =~ ^-?[0-9]+$ ]]; then error "Invalid Channel/Group ID format 🚫"; fi; return 0; }


# -----------------------------------------------
# 🛠️ Initial Cleanup
# -----------------------------------------------
rm -f deploy.log

# ===============================================
# ⚙️ Configuration Options
# ===============================================

# 1. V2Ray Option 
header "V2RAY/TROJAN PROTOCOL SELECTION" "$EMOJI_PROTO"
VLESS_PROTOCOL="Vless (WS)"
VLESS_GRPC_PROTOCOL="Vless gRPC"
TROJAN_PROTOCOL="Trojan"

VLESS_DEFAULT="1"
echo -e "  1. ${CYAN}${VLESS_PROTOCOL}${NC} ${GREEN}(Default)${NC}"
echo -e "  2. ${CYAN}${VLESS_GRPC_PROTOCOL}${NC}"
echo -e "  3. ${CYAN}${TROJAN_PROTOCOL}${NC}"
read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter your choice (1/2/3) [${VLESS_DEFAULT}]: ${NC}")" PROTOCOL_CHOICE
PROTOCOL_CHOICE=${PROTOCOL_CHOICE:-$VLESS_DEFAULT}

case "$PROTOCOL_CHOICE" in
    1) PROTOCOL=$VLESS_PROTOCOL; PROTOCOL_LOWER="vless"; VLESS_PATH="/vless"; TEMPLATE_FILE="config_vless_ws.json.tmpl";;
    2) PROTOCOL=$VLESS_GRPC_PROTOCOL; PROTOCOL_LOWER="vlessgrpc"; VLESS_PATH="/vlessgrpc"; TEMPLATE_FILE="config_vless_grpc.json.tmpl";;
    3) PROTOCOL=$TROJAN_PROTOCOL; PROTOCOL_LOWER="trojan"; TEMPLATE_FILE="config_trojan.json.tmpl";;
    *) error "Invalid choice. Exiting.";;
esac
selected "$PROTOCOL"


# 2. Region (Flags moved to front)
header "CLOUD RUN REGION SELECTION" "$EMOJI_LOCATION"
REGIONS=(
    "🇺🇸 us-central1 (Council Bluffs, Iowa, North America) ${GREEN}(Default)${NC}" 
    "🇺🇸 us-east1 (Moncks Corner, South Carolina, North America)" 
    "🇺🇸 us-south1 (Dallas, Texas, North America)" 
    "🇨🇱 southamerica-west1 (Santiago, Chile, South America)" 
    "🇺🇸 us-west1 (The Dalles, Oregon, North America)" 
    "🇨🇦 northamerica-northeast2 (Toronto, Ontario, North America)" 
    "🇸🇬 asia-southeast1 (Jurong West, Singapore)" 
    "🇯🇵 asia-northeast1 (Tokyo, Japan)" 
    "🇹🇼 asia-east1 (Changhua County, Taiwan)" 
    "🇭🇰 asia-east2 (Hong Kong)" 
    "🇮🇳 asia-south1 (Mumbai, India)" 
    "🇮🇩 asia-southeast2 (Jakarta, Indonesia)" 
)
DEFAULT_REGION_INDEX=1 
for i in "${!REGIONS[@]}"; do
    echo -e "  $((i+1)). ${REGIONS[$i]}"
done

read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter your choice (1-${#REGIONS[@]}) or Enter [${DEFAULT_REGION_INDEX}]: ${NC}")" REGION_CHOICE
REGION_CHOICE=${REGION_CHOICE:-$DEFAULT_REGION_INDEX}
if [[ "$REGION_CHOICE" -ge 1 && "$REGION_CHOICE" -le ${#REGIONS[@]} ]]; then
    REGION=$(echo "${REGIONS[$((REGION_CHOICE-1))]}" | awk '{print $2}') 
else
    error "Invalid choice. Exiting."
fi
selected "$REGION"


# 3. CPU
header "CPU LIMIT SELECTION" "$EMOJI_CPU"
CPU_OPTIONS=(
    "1 CPU Core (Low Cost)"
    "2 CPU Cores (Balance) ${GREEN}(Default)${NC}" 
    "4 CPU Cores (Performance)"
    "8 CPU Cores (High Perf)"
    "16 CPU Cores (Max Perf)"
)
CPUS=(1 2 4 8 16)
DEFAULT_CPU_INDEX=2
for i in "${!CPU_OPTIONS[@]}"; do
    echo -e "  $((i+1)). ${CPU_OPTIONS[$i]}"
done
read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter your choice (1-${#CPUS[@]}) or Enter [${DEFAULT_CPU_INDEX}]: ${NC}")" CPU_CHOICE
CPU_CHOICE=${CPU_CHOICE:-$DEFAULT_CPU_INDEX}
if [[ "$CPU_CHOICE" -ge 1 && "$CPU_CHOICE" -le ${#CPUS[@]} ]]; then
    CPU_LIMIT="${CPUS[$((CPU_CHOICE-1))]}"
else
    error "Invalid choice. Exiting."
fi
selected "${CPU_LIMIT} CPU Cores"


# 4. Memory (512Mi added)
header "MEMORY LIMIT SELECTION" "$EMOJI_MEMORY"
MEMORY_OPTIONS=(
    "1. 512Mi (Minimum/Low Cost)" 
    "2. 1Gi (Low Cost)"
    "3. 2Gi (Balance) ${GREEN}(Default)${NC}" 
    "4. 4Gi (Performance)"
    "5. 8Gi (High Perf)"
    "6. 16Gi (Large Scale)"
    "7. 32Gi (Max)"
)
MEMORIES=("512Mi" "1Gi" "2Gi" "4Gi" "8Gi" "16Gi" "32Gi")
DEFAULT_MEMORY_INDEX=3
for opt in "${MEMORY_OPTIONS[@]}"; do
    echo -e "  ${opt}"
done

read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter your choice (1-${#MEMORIES[@]}) or Enter [${DEFAULT_MEMORY_INDEX}]: ${NC}")" MEMORY_CHOICE
MEMORY_CHOICE=${MEMORY_CHOICE:-$DEFAULT_MEMORY_INDEX}
if [[ "$MEMORY_CHOICE" -ge 1 && "$MEMORY_CHOICE" -le ${#MEMORIES[@]} ]]; then
    MEMORY_LIMIT="${MEMORIES[$((MEMORY_CHOICE-1))]}"
else
    error "Invalid choice. Exiting."
fi
selected "$MEMORY_LIMIT"


# 5. Service Name
header "CLOUD RUN SERVICE NAME" "$EMOJI_NAME"
echo -e "${EMOJI_INFO} ${BLUE}Default Service Name: ${CYAN}${DEFAULT_SERVICE_NAME}${NC} ${GREEN}(Default)${NC}"
read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter Custom Service Name or Enter [${DEFAULT_SERVICE_NAME}]: ${NC}")" CUSTOM_SERVICE_NAME
SERVICE_NAME=${CUSTOM_SERVICE_NAME:-$DEFAULT_SERVICE_NAME}
SERVICE_NAME=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')
if [[ -z "$SERVICE_NAME" ]]; then
    SERVICE_NAME=$DEFAULT_SERVICE_NAME
    info "Service Name was empty or invalid. Using default: ${CYAN}$SERVICE_NAME${NC}"
fi
selected "$SERVICE_NAME"


# 6. Host Domain (SNI)
header "HOST DOMAIN (SNI)" "$EMOJI_DOMAIN"
echo -e "${EMOJI_INFO} ${BLUE}Default Host Domain: ${CYAN}${DEFAULT_HOST_DOMAIN}${NC} ${GREEN}(Default)${NC}"
read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter Custom Host Domain or Enter [${DEFAULT_HOST_DOMAIN}]: ${NC}")" CUSTOM_HOST_DOMAIN
HOST_DOMAIN=${CUSTOM_HOST_DOMAIN:-$DEFAULT_HOST_DOMAIN}
selected "$HOST_DOMAIN"


# 7. UUID / Password / gRPC Service Name
if [[ "$PROTOCOL_LOWER" != "trojan" ]]; then
    # VLESS/VLESS gRPC - UUID
    header "VLESS USER ID (UUID)" "$EMOJI_CONFIG"
    echo -e "  1. ${CYAN}${DEFAULT_UUID}${NC} ${GREEN}(Default)${NC}"
    echo -e "  2. ${CYAN}Random UUID Generate (Internal Bash)${NC}"
    echo -e "  3. ${CYAN}Custom UUID${NC}"
    DEFAULT_UUID_CHOICE="1"
    read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter your choice (1/2/3) or Enter [1]: ${NC}")" UUID_CHOICE
    UUID_CHOICE=${UUID_CHOICE:-$DEFAULT_UUID_CHOICE}
    
    case "$UUID_CHOICE" in
        1) USER_ID=$DEFAULT_UUID ;;
        2) USER_ID=$(generate_uuid); info "Generated UUID: ${CYAN}$USER_ID${NC}";;
        3) read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter Custom UUID: ${NC}")" CUSTOM_UUID
           validate_uuid "$CUSTOM_UUID"
           USER_ID=$CUSTOM_UUID ;;
        *) warn "Invalid choice. Using Default UUID."; USER_ID=$DEFAULT_UUID ;;
    esac
    selected "$USER_ID"
    
    # VLESS gRPC - Service Name
    if [[ "$PROTOCOL_LOWER" == "vlessgrpc" ]]; then
        header "gRPC SERVICE NAME" "$EMOJI_CONFIG"
        echo -e "${EMOJI_INFO} ${BLUE}Default gRPC Service Name: ${CYAN}${DEFAULT_GRPC_SERVICE}${NC} ${GREEN}(Default)${NC}"
        read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter Custom gRPC Service Name or Enter [${DEFAULT_GRPC_SERVICE}]: ${NC}")" CUSTOM_GRPC_SERVICE
        GRPC_SERVICE_NAME=${CUSTOM_GRPC_SERVICE:-$DEFAULT_GRPC_SERVICE}
        VLESS_PATH="/${GRPC_SERVICE_NAME}" 
        selected "$GRPC_SERVICE_NAME"
    fi
    
else # Trojan
    # Trojan Password
    header "TROJAN PASSWORD" "$EMOJI_CONFIG"
    echo -e "${EMOJI_INFO} ${BLUE}Default Password: ${CYAN}${DEFAULT_TROJAN_PASS}${NC} ${GREEN}(Default)${NC}"
    read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter Custom Password or Enter [${DEFAULT_TROJAN_PASS}]: ${NC}")" CUSTOM_TROJAN_PASS
    USER_ID=${CUSTOM_TROJAN_PASS:-$DEFAULT_TROJAN_PASS}
    selected "$USER_ID"
fi


# 8. Telegram Sharing Option (NEW Option 5 Added)
header "TELEGRAM SHARING OPTIONS" "$EMOJI_TELE"
TELEGRAM_OPTIONS=(
    "1. Do Not Send Telegram ${GREEN}(Default)${NC}"
    "2. Send to Channel Only"
    "3. Send to Group Only"
    "4. Send to Bot (Private Chat)"
    "5. Send to Bot & Channel/Group (Recommended)" # NEW OPTION
)
DEFAULT_TELEGRAM="1"
for opt in "${TELEGRAM_OPTIONS[@]}"; do
    echo -e "  ${CYAN}${opt}${NC}"
done

read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter your choice (1-5) or Enter [1]: ${NC}")" TELEGRAM_CHOICE
TELEGRAM_CHOICE=${TELEGRAM_CHOICE:-$DEFAULT_TELEGRAM}
TELEGRAM_MODE="${TELEGRAM_OPTIONS[$((TELEGRAM_CHOICE-1))]}"


if [[ "$TELEGRAM_CHOICE" -ge "2" && "$TELEGRAM_CHOICE" -le "5" ]]; then
    # Bot Token required for all sending modes
    read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter Telegram Bot Token (Required): ${NC}")" CUSTOM_BOT_TOKEN
    validate_bot_token "$CUSTOM_BOT_TOKEN"
    TELEGRAM_BOT_TOKEN="$CUSTOM_BOT_TOKEN"

    # Chat ID is required for Channel/Group/Both
    if [[ "$TELEGRAM_CHOICE" -eq "2" || "$TELEGRAM_CHOICE" -eq "3" || "$TELEGRAM_CHOICE" -eq "5" ]]; then
        read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Enter Telegram Chat ID (Channel/Group ID: -12345...): ${NC}")" CUSTOM_CHAT_ID
        validate_channel_id "$CUSTOM_CHAT_ID" 
        TELEGRAM_CHAT_ID="$CUSTOM_CHAT_ID"
    fi
fi
selected "$(echo "$TELEGRAM_MODE" | sed 's/ *\[Default\]//g')"


# ===============================================
# 📄 Display Configuration Summary & Confirmation
# ===============================================
header "DEPLOYMENT CONFIGURATION SUMMARY" "$EMOJI_CONFIG"

# 1. Project ID Auto-Assign/Check
if command -v gcloud >/dev/null 2>&1; then
    GCP_PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "")
    if [ -z "$GCP_PROJECT_ID" ]; then
        GCP_PROJECT_ID="<GCP Project ID Not Configured>"
        warn "GCP Project ID not set in gcloud config. Please configure it or the pre-check will fail."
    fi
else
    GCP_PROJECT_ID="<GCP CLI Not Found - Check Pre-Requisites>"
    echo -e "${RED}${BOLD}NOTE:${NC} The gcloud CLI is not detected. Pre-requisite check will run next."
fi

# 2. Display Summary
echo -e "${EMOJI_CONFIG} ${BLUE}${BOLD}Project ID:${NC}      ${GREEN}${GCP_PROJECT_ID}${NC}" 
echo -e "${EMOJI_CONFIG} ${BLUE}Protocol:${NC}        ${GREEN}$PROTOCOL${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}Service Name:${NC}    ${GREEN}$SERVICE_NAME${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}Region:${NC}          ${GREEN}$REGION${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}CPU Limit:${NC}       ${GREEN}${CPU_LIMIT} CPU Cores${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}Memory Limit:${NC}    ${GREEN}${MEMORY_LIMIT}${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}Host Domain/SNI:${NC} ${GREEN}$HOST_DOMAIN${NC}"
echo -e "${EMOJI_CONFIG} ${BLUE}UUID/Password:${NC}   ${GREEN}$USER_ID${NC}"
if [ "$TELEGRAM_CHOICE" -ne "1" ]; then
    echo -e "${EMOJI_CONFIG} ${BLUE}Telegram Mode:${NC}     ${GREEN}$TELEGRAM_MODE${NC}"
    echo -e "${EMOJI_CONFIG} ${BLUE}Telegram Chat ID:${NC}  ${GREEN}${TELEGRAM_CHAT_ID:-N/A}${NC}"
fi

# 3. Confirmation Step
echo -e "\n${YELLOW}Configuration is complete.${NC}"
read -rp "$(echo -e "${EMOJI_PROMPT} ${GREEN}Continue with deployment? (Y/n) [Y]: ${NC}")" CONFIRM_DEPLOY
CONFIRM_DEPLOY=${CONFIRM_DEPLOY:-Y}

if [[ ! "$CONFIRM_DEPLOY" =~ ^[Yy]$ ]]; then
    info "Deployment cancelled by user. Exiting."
    exit 0
fi

# ===============================================
# 🛠️ Pre-Requisite Check (Clean check)
# ===============================================
header "PRE-REQUISITE CHECK" "$EMOJI_CPU"
info "Checking for all required CLI tools..."

# Check for all CLIs
command -v gcloud >/dev/null 2>&1 || error "gcloud CLI not found. Please install and authenticate with 'gcloud auth login' and 'gcloud config set project <ID>'."
command -v docker >/dev/null 2>&1 || error "docker not found. Please install it."
command -v git >/dev/null 2>&1 || error "git not found. Please install it."

# Final Project ID check (must be done after gcloud check)
GCP_PROJECT_ID=$(gcloud config get-value project)
if [ -z "$GCP_PROJECT_ID" ]; then
    error "GCP Project ID not set in gcloud config. Please run 'gcloud config set project <YOUR_PROJECT_ID>'."
fi
info "GCP Project ID: ${GREEN}$GCP_PROJECT_ID${NC}"

info "All required CLI tools found. Starting GCP setup."

# ===============================================
# ☁️ GCP Project ID & API Setup
# ===============================================
header "GCP SETUP & API ENABLEMENT" "$EMOJI_START"

gcloud config set project "$GCP_PROJECT_ID" --quiet
info "Enabling necessary APIs (Cloud Run, Artifact Registry)..."
progress_bar 10 
gcloud services enable run.googleapis.com artifactregistry.googleapis.com --project="$GCP_PROJECT_ID" || error "Failed to enable GCP APIs."
info "APIs enabled successfully."


# ===============================================
# 🏗️ Clone & File Generation
# ===============================================
header "GIT CLONE & CONFIG FILE PREP" "$EMOJI_CONFIG"

# 1. Clone Git Repo
info "Git Clone URL: ${CYAN}${REPO_URL}${NC}"
if [ -d "$REPO_DIR" ]; then
    info "Removing existing repo $REPO_DIR and recloning."
    rm -rf "$REPO_DIR"
fi
info "Cloning $REPO_URL..."
progress_bar 5
if ! git clone "$REPO_URL" >/dev/null 2>&1; then
    error "Git Clone failed. Check if the repository URL is correct or if Git is configured."
fi
info "Git Clone successful."
cd "$REPO_DIR"

# 2. Generate config.json from Template
info "Generating config.json from template file: ${CYAN}$TEMPLATE_FILE${NC}..."

if [ ! -f "$TEMPLATE_FILE" ]; then
    error "Configuration template file ($TEMPLATE_FILE) not found in the repository. Deployment aborted."
fi

# Use envsubst or sed to replace placeholders
if command -v envsubst >/dev/null 2>&1; then
    export USER_ID HOST_DOMAIN VLESS_PATH GRPC_SERVICE_NAME # Export for envsubst
    envsubst < "$TEMPLATE_FILE" > config.json || error "Failed to substitute variables in config template."
else
    # Fallback to sed
    sed -e "s|\$USER_ID|$USER_ID|g" \
        -e "s|\$HOST_DOMAIN|$HOST_DOMAIN|g" \
        -e "s|\$VLESS_PATH|$VLESS_PATH|g" \
        -e "s|\$GRPC_SERVICE_NAME|$GRPC_SERVICE_NAME|g" \
        "$TEMPLATE_FILE" > config.json || error "Failed to substitute variables in config template."
fi

info "config.json created successfully. Dockerfile should be ready."

# ... (Rest of the script: Build, Deploy, Share Link generation, Telegram Notification) ...

# ===============================================
# 🎉 Final Message
# ===============================================
echo -e "\n${EMOJI_TITLE} ${CYAN}${BOLD}Configuration Complete. Continue with Build/Deployment Steps!${NC} ${EMOJI_TITLE}"
