#!/bin/bash

# ===============================================
# 🛡️ Error Handling
# ===============================================
# Exit immediately if a command exits with a non-zero status.
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
AR_REPO="gcp-xray-repo" # Artifact Registry Repo Name
DEFAULT_SERVICE_NAME="gcp-ahlflk"
DEFAULT_HOST_DOMAIN="m.googleapis.com"

# ⚠️ အသုံးပြုသူ တောင်းဆိုထားသည့် Default တန်ဖိုးများ
DEFAULT_GRPC_SERVICE="ahlflk" 
DEFAULT_TROJAN_PASS="ahlflk"
DEFAULT_UUID="3675119c-14fc-46a4-b5f3-9a2c91a7d802"
DEFAULT_VLESS_PATH="/ahlflk" 
GRPC_SERVICE_NAME=$DEFAULT_GRPC_SERVICE # VLESS/gRPC တွင် VLESS_PATH အဖြစ် သုံးမည်။

GCP_PROJECT_ID=""
CPU_LIMIT=""
MEMORY_LIMIT=""
USER_ID=$DEFAULT_UUID
VLESS_PATH=$DEFAULT_VLESS_PATH # VLESS WS တွင် Path အဖြစ် သုံးမည်။

TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""
TELEGRAM_CHOICE="1" # Default: Do Not Send
SPINNER_PID="" # Global variable for spinner process ID
DEPLOY_INFO_FILE="deployment_info.txt"


# -----------------------------------------------
# 🖼️ Helper Functions
# -----------------------------------------------

# Function for Header Title
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

# UUID Generator using Bash (User requested to keep this)
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
error() { 
    echo -e "${RED}ERROR:${NC} $1" 1>&2; log "ERROR: $1"; 
    # Add pause before exit to view error
    read -rp "$(echo -e "${EMOJI_FAIL} ${RED}Press [Enter] to exit...${NC}")"
    exit 1; 
}
warn() { echo -e "${YELLOW}WARNING:${NC} $1"; log "WARNING: $1"; }
info() { echo -e "${BLUE}INFO:${NC} $1"; log "INFO: $1"; }
selected() { echo -e "${EMOJI_SUCCESS} ${GREEN}${BOLD}Selected:${NC} ${CYAN}${UNDERLINE}$1${NC}"; log "Selected: $1"; }

# Progress Bar (Spinner implementation)
start_spinner() {
    local delay=0.1
    local spin="⣾⣽⣻⢿⡿⣟⣯⣷"
    local i=0
    
    (
        while :; do
            echo -en "\r${EMOJI_WAIT} ${CYAN}Processing... ${NC}${spin:$i:1}"
            i=$(( (i+1) % ${#spin} ))
            sleep $delay
        done
    ) &
    SPINNER_PID=$!
    # Trap ensures spinner is killed if the script exits unexpectedly
    trap "kill $SPINNER_PID 2>/dev/null; exit 1" EXIT
}

# Stops the background spinner
stop_spinner() {
    if [ -n "$SPINNER_PID" ]; then
        kill $SPINNER_PID 2>/dev/null
        wait $SPINNER_PID 2>/dev/null
    fi
    # Clear the spinner line and print "Complete!"
    echo -e "\r${EMOJI_SUCCESS} ${GREEN}Complete!${NC}                            "
    SPINNER_PID=""
}

# Wrapper to run a command and show spinner until it finishes
start_and_wait() {
    local command_to_run="$1"
    
    # Run the command in the background, suppressing all output
    # We use a temp file to capture output in case of failure for debugging
    local TEMP_LOG=$(mktemp)
    eval "$command_to_run" > "$TEMP_LOG" 2>&1 &
    local command_pid=$!
    
    # Start the visual spinner
    start_spinner
    
    # Wait for the command to finish
    if ! wait $command_pid; then
        stop_spinner
        echo -e "\n${RED}--- COMMAND ERROR LOG ---${NC}"
        cat "$TEMP_LOG" 1>&2
        echo -e "${RED}-------------------------${NC}\n"
        rm -f "$TEMP_LOG"
        error "Command failed: $command_to_run"
    fi
    
    rm -f "$TEMP_LOG"
    # Stop the visual spinner
    stop_spinner
    return 0
}

# Simple Progress Bar for known wait times (only for API enablement)
progress_bar() {
    local duration=$1; local bar_length=20; local elapsed=0;
    echo -n "${EMOJI_WAIT} Processing..."
    while [ "$elapsed" -lt "$duration" ]; do
        local progress=$(( ($elapsed * $bar_length) / $duration )); local filled=$(printf '%.0s#' $(seq 1 $progress)); local empty=$(printf '%.0s-' $(seq 1 $(( $bar_length - $progress ))));
        printf "\r${EMOJI_WAIT} [${GREEN}${filled}${CYAN}${empty}${NC}] %3d%%" $(( ($elapsed * 100) / $duration ))
        sleep 1; elapsed=$(( $elapsed + 1 ))
    done
    printf "\r${EMOJI_WAIT} [${GREEN}$(printf '%.0s#' $(seq 1 $bar_length))${NC}] 100%% Complete! ${EMOJI_SUCCESS}\n"
}

# Validation functions
validate_uuid() { local uuid_pattern="^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"; if [[ ! "$1" =~ $uuid_pattern ]]; then error "Invalid UUID format: $1"; fi; return 0; }
validate_bot_token() { local token_pattern="^[0-9]{9,10}:[a-zA-Z0-9_-]{35}$"; if [[ ! "$1" =~ $token_pattern ]]; then error "Invalid Telegram Bot Token format"; fi; return 0; }
validate_channel_id() { if [[ ! "$1" =~ ^-?[0-9]+$ ]]; then error "Invalid Channel/Group ID format"; fi; return 0; }

# Function to send Telegram Notification (Markdown format)
send_telegram_notification() {
    local message="$1"
    local telegram_url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"

    # Send to main chat ID (Channel/Group/Private Bot Chat)
    if [[ -n "$TELEGRAM_CHAT_ID" ]]; then
        curl -s -X POST "$telegram_url" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="Markdown" >/dev/null || warn "Failed to send message to Chat ID: $TELEGRAM_CHAT_ID"
    fi

    # Send only to private bot chat (if choice 4 or 5 and chat_id is not set, or for choice 4 explicitly)
    if [[ "$TELEGRAM_CHOICE" == "4" && -z "$TELEGRAM_CHAT_ID" ]] || [[ "$TELEGRAM_CHOICE" == "5" && -z "$TELEGRAM_CHAT_ID" ]]; then
        local bot_owner_id=$(echo "$TELEGRAM_BOT_TOKEN" | cut -d ':' -f 1)
        curl -s -X POST "$telegram_url" \
            -d chat_id="$bot_owner_id" \
            -d text="$message" \
            -d parse_mode="Markdown" >/dev/null || warn "Failed to send message to Bot Private Chat"
    fi
}


# -----------------------------------------------
# 🛠️ Initial Cleanup
# -----------------------------------------------
rm -f deploy.log "$DEPLOY_INFO_FILE"

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
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1/2/3) [${VLESS_DEFAULT}]: ${NC}")" PROTOCOL_CHOICE
PROTOCOL_CHOICE=${PROTOCOL_CHOICE:-$VLESS_DEFAULT}

case "$PROTOCOL_CHOICE" in
    1) PROTOCOL=$VLESS_PROTOCOL; PROTOCOL_LOWER="vless"; VLESS_PATH=$DEFAULT_VLESS_PATH; TEMPLATE_FILE="config_vless_ws.json.tmpl";;
    2) PROTOCOL=$VLESS_GRPC_PROTOCOL; PROTOCOL_LOWER="vlessgrpc"; VLESS_PATH=$DEFAULT_GRPC_SERVICE; TEMPLATE_FILE="config_vless_grpc.json.tmpl";;
    3) PROTOCOL=$TROJAN_PROTOCOL; PROTOCOL_LOWER="trojan"; VLESS_PATH=$DEFAULT_TROJAN_PASS; TEMPLATE_FILE="config_trojan.json.tmpl";;
    *) error "Invalid choice. Exiting.";;
esac
selected "$PROTOCOL"


# 2. Region
header "CLOUD RUN REGION SELECTION" "$EMOJI_LOCATION"
REGIONS=(
    " 🇺🇸 us-central1 (Council Bluffs, Iowa, North America) ${GREEN}(Default)${NC}" 
    " 🇺🇸 us-east1 (Moncks Corner, South Carolina, North America)" 
    " 🇺🇸 us-south1 (Dallas, Texas, North America)" 
    " 🇺🇸 us-west1 (The Dalles, Oregon, North America)" 
    " 🇺🇸 us-west2 (Los Angeles, California, North America)" 
    " 🇨🇦 northamerica-northeast2 (Toronto, Ontario, North America)" 
    " 🇸🇬 asia-southeast1 (Jurong West, Singapore)" 
    " 🇯🇵 asia-northeast1 (Tokyo, Japan)" 
    " 🇹🇼 asia-east1 (Changhua County, Taiwan)" 
    "🇭🇰 asia-east2 (Hong Kong)" 
    "🇮🇳 asia-south1 (Mumbai, India)" 
    "🇮🇩 asia-southeast2 (Jakarta, Indonesia)" 
)
DEFAULT_REGION_INDEX=1 
for i in "${!REGIONS[@]}"; do
    echo -e "  $((i+1)). ${REGIONS[$i]}"
done
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1-${#REGIONS[@]}) or Enter [${DEFAULT_REGION_INDEX}]: ${NC}")" REGION_CHOICE
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
    "1  CPU Core (Low Cost)"
    "2  CPU Cores (Balance) ${GREEN}(Default)${NC}" 
    "4  CPU Cores (Performance)"
    "8  CPU Cores (High Perf)"
    "16 CPU Cores (Max Perf)"
)
CPUS=(1 2 4 8 16)
DEFAULT_CPU_INDEX=2
for i in "${!CPU_OPTIONS[@]}"; do
    echo -e "  $((i+1)). ${CPU_OPTIONS[$i]}"
done
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1-${#CPUS[@]}) or Enter [${DEFAULT_CPU_INDEX}]: ${NC}")" CPU_CHOICE
CPU_CHOICE=${CPU_CHOICE:-$DEFAULT_CPU_INDEX}
if [[ "$CPU_CHOICE" -ge 1 && "$CPU_CHOICE" -le ${#CPUS[@]} ]]; then
    CPU_LIMIT="${CPUS[$((CPU_CHOICE-1))]}"
else
    error "Invalid choice. Exiting."
fi
selected "${CPU_LIMIT} CPU Cores"


# 4. Memory
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
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1-${#MEMORIES[@]}) or Enter [${DEFAULT_MEMORY_INDEX}]: ${NC}")" MEMORY_CHOICE
MEMORY_CHOICE=${MEMORY_CHOICE:-$DEFAULT_MEMORY_INDEX}
if [[ "$MEMORY_CHOICE" -ge 1 && "$MEMORY_CHOICE" -le ${#MEMORIES[@]} ]]; then
    MEMORY_LIMIT="${MEMORIES[$((MEMORY_CHOICE-1))]}"
else
    error "Invalid choice. Exiting."
fi
selected "$MEMORY_LIMIT"


# 5. Service Name
header "CLOUD RUN SERVICE NAME" "$EMOJI_NAME"
echo -e "${EMOJI_INFO} Default Service Name: ${CYAN}${DEFAULT_SERVICE_NAME}${NC} ${GREEN}(Default)${NC}"
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter Custom Service Name or Enter [${DEFAULT_SERVICE_NAME}]: ${NC}")" CUSTOM_SERVICE_NAME
SERVICE_NAME=${CUSTOM_SERVICE_NAME:-$DEFAULT_SERVICE_NAME}
SERVICE_NAME=$(echo "$SERVICE_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd '[:alnum:]-')
if [[ -z "$SERVICE_NAME" ]]; then
    SERVICE_NAME=$DEFAULT_SERVICE_NAME
    info "Service Name was empty or invalid. Using default: ${CYAN}$SERVICE_NAME${NC}"
fi
selected "$SERVICE_NAME"


# 6. Host Domain (SNI)
header "HOST DOMAIN (SNI)" "$EMOJI_DOMAIN"
echo -e "${EMOJI_INFO} Default Host Domain: ${CYAN}${DEFAULT_HOST_DOMAIN}${NC} ${GREEN}(Default)${NC}"
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter Custom Host Domain or Enter [${DEFAULT_HOST_DOMAIN}]: ${NC}")" CUSTOM_HOST_DOMAIN
HOST_DOMAIN=${CUSTOM_HOST_DOMAIN:-$DEFAULT_HOST_DOMAIN}
selected "$HOST_DOMAIN"


# 7. UUID / Password / gRPC Service Name
if [[ "$PROTOCOL_LOWER" != "trojan" ]]; then
    # VLESS/VLESS gRPC - UUID
    header "VLESS USER ID (UUID)" "$EMOJI_CONFIG"
    echo -e "  1. ${CYAN}${DEFAULT_UUID}${NC} ${GREEN}(Default)${NC}"
    echo -e "  2. ${CYAN}Random UUID Generate (Internal Bash)${NC}"
    echo -e "  3. ${CYAN}Custom UUID${NC}"
    echo
    DEFAULT_UUID_CHOICE="1"
    read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1/2/3) or Enter [1]: ${NC}")" UUID_CHOICE
    UUID_CHOICE=${UUID_CHOICE:-$DEFAULT_UUID_CHOICE}
    
    case "$UUID_CHOICE" in
        1) USER_ID=$DEFAULT_UUID ;;
        2) USER_ID=$(generate_uuid); info "Generated UUID: ${CYAN}$USER_ID${NC}";;
        3) read -rp "$(echo -e "${EMOJI_PROMPT} Enter Custom UUID: ${NC}")" CUSTOM_UUID
           validate_uuid "$CUSTOM_UUID"
           USER_ID=$CUSTOM_UUID ;;
        *) warn "Invalid choice. Using Default UUID."; USER_ID=$DEFAULT_UUID ;;
    esac
    selected "$USER_ID"
    
    # VLESS gRPC - Service Name (Default: ahlflk)
    if [[ "$PROTOCOL_LOWER" == "vlessgrpc" ]]; then
        info "Using default gRPC Service Name: ${CYAN}$DEFAULT_GRPC_SERVICE${NC}"
        GRPC_SERVICE_NAME=$DEFAULT_GRPC_SERVICE
        VLESS_PATH="/${GRPC_SERVICE_NAME}" # VLESS_PATH is used as serviceName in template
        selected "$GRPC_SERVICE_NAME"
    fi
    
else # Trojan
    # Trojan Password (Default: ahlflk)
    header "TROJAN PASSWORD" "$EMOJI_CONFIG"
    info "Using default Trojan Password: ${CYAN}$DEFAULT_TROJAN_PASS${NC}"
    USER_ID=$DEFAULT_TROJAN_PASS # Trojan uses password as user ID
    selected "$USER_ID"
fi


# 8. Telegram Sharing Option
header "TELEGRAM SHARING OPTIONS" "$EMOJI_TELE"
TELEGRAM_OPTIONS=(
    "1. Do Not Send Telegram ${GREEN}(Default)${NC}"
    "2. Send to Channel Only"
    "3. Send to Group Only"
    "4. Send to Bot (Private Chat)"
    "5. Send to Bot & Channel/Group (Recommended)"
)
DEFAULT_TELEGRAM="1"
for opt in "${TELEGRAM_OPTIONS[@]}"; do
    echo -e "  ${CYAN}${opt}${NC}"
done
echo
read -rp "$(echo -e "${EMOJI_PROMPT} Enter your choice (1-5) or Enter [1]: ${NC}")" TELEGRAM_CHOICE
TELEGRAM_CHOICE=${TELEGRAM_CHOICE:-$DEFAULT_TELEGRAM}
TELEGRAM_MODE="${TELEGRAM_OPTIONS[$((TELEGRAM_CHOICE-1))]}"


if [[ "$TELEGRAM_CHOICE" -ge "2" && "$TELEGRAM_CHOICE" -le "5" ]]; then
    # Bot Token required for all sending modes (Silent input for security)
    echo
    read -rp "$(echo -e "${EMOJI_PROMPT} Enter Telegram Bot Token (Required): ${NC}")" -s CUSTOM_BOT_TOKEN
    echo # Newline after silent input
    validate_bot_token "$CUSTOM_BOT_TOKEN"
    TELEGRAM_BOT_TOKEN="$CUSTOM_BOT_TOKEN"

    # Chat ID is required for Channel/Group/Both
    if [[ "$TELEGRAM_CHOICE" -eq "2" || "$TELEGRAM_CHOICE" -eq "3" || "$TELEGRAM_CHOICE" -eq "5" ]]; then
    echo
        read -rp "$(echo -e "${EMOJI_PROMPT} Enter Telegram Chat ID (Channel/Group ID: -12345...): ${NC}")" CUSTOM_CHAT_ID
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
echo -e "${EMOJI_CONFIG} ${BLUE}Vless Path/gRPC Name:${NC} ${GREEN}$VLESS_PATH${NC}"
if [ "$TELEGRAM_CHOICE" -ne "1" ]; then
    echo -e "${EMOJI_CONFIG} ${BLUE}Telegram Mode:${NC}     ${GREEN}$TELEGRAM_MODE${NC}"
    echo -e "${EMOJI_CONFIG} ${BLUE}Telegram Chat ID:${NC}  ${GREEN}${TELEGRAM_CHAT_ID:-N/A}${NC}"
fi

# 3. Confirmation Step
echo -e "\n${YELLOW}${EMOJI_START} Configuration is complete.${NC}"
read -rp "$(echo -e "${EMOJI_PROMPT} Continue with deployment? (Y/n) [Y]: ${NC}")" CONFIRM_DEPLOY
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
command -v envsubst >/dev/null 2>&1 || warn "envsubst not found. Falling back to sed for config generation."

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

# Artifact Registry APIs ကို GCR အတွက် သုံးပါ
API_CMD="gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com --project=\"$GCP_PROJECT_ID\""

# start_and_wait ကို သုံးပြီး API enablement ကို စောင့်ပါ (ပိုမို စိတ်ချရသောနည်းလမ်း)
if ! start_and_wait "$API_CMD"; then
    error "GCP APIs could not be enabled. Please check permissions." 
fi

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

# ===============================================
# 🛠️ DOCKER BUILD & ARTIFACT REGISTRY PUSH
# ===============================================
header "DOCKER IMAGE BUILD & PUSH (USING AR)" "$EMOJI_START"

# 1. Image Tag Definition (Artifact Registry format ကို သုံးပါ)
AR_LOCATION="$REGION"
IMAGE_TAG="${AR_LOCATION}-docker.pkg.dev/$GCP_PROJECT_ID/$AR_REPO/$SERVICE_NAME:latest"

# 2. Artifact Registry Setup & Auth (Output Hidden)
info "Setting up Artifact Registry Repository: ${CYAN}$AR_REPO${NC} in ${CYAN}$AR_LOCATION${NC}"
gcloud artifacts repositories create "$AR_REPO" \
    --repository-format=docker \
    --location="$AR_LOCATION" \
    --description="Docker repository for XRAY services" \
    --project="$GCP_PROJECT_ID" --quiet 2>/dev/null || info "Repository already exists or created successfully."

info "Authenticating Docker for Artifact Registry..."
gcloud auth configure-docker "$AR_LOCATION-docker.pkg.dev" --quiet >/dev/null 2>&1 || error "Failed to authenticate Docker."
info "Authentication successful."


# -----------------------------------------------
# 3. Docker Build (Spinner + Log Capture)
# -----------------------------------------------
info "Building Docker Image: ${CYAN}$IMAGE_TAG${NC}..."
BUILD_CMD="docker build -t \"$IMAGE_TAG\" ."

# Run build in foreground to capture log if failed, but use start_and_wait for visual feedback
if ! start_and_wait "$BUILD_CMD"; then
    # Error message is already handled inside start_and_wait
    error "Docker build failed."
fi

info "Docker image built successfully."


# 4. Docker Push (Spinner)
info "Pushing Docker Image to Artifact Registry..."
PUSH_CMD="docker push \"$IMAGE_TAG\""
if ! start_and_wait "$PUSH_CMD"; then
    error "Docker push failed. Check your network or permissions."
fi
info "Image pushed successfully."


# ===============================================
# ☁️ CLOUD RUN SERVICE DEPLOY (With Spinner)
# ===============================================
header "CLOUD RUN SERVICE DEPLOYMENT" "$EMOJI_WAIT"

info "Deploying Cloud Run Service: ${CYAN}$SERVICE_NAME${NC} in ${CYAN}$REGION${NC}..."
info "Waiting for service to be ready... (Max timeout 5 minutes)"

DEPLOY_COMMAND="gcloud run deploy \"$SERVICE_NAME\" \
    --image=\"$IMAGE_TAG\" \
    --region=\"$REGION\" \
    --cpu=\"$CPU_LIMIT\" \
    --memory=\"$MEMORY_LIMIT\" \
    --min-instances=1 \
    --max-instances=1 \
    --allow-unauthenticated \
    --port=8080 \
    --quiet \
    --wait"

# Use start_and_wait (spinner) until deployment finishes
if ! start_and_wait "$DEPLOY_COMMAND"; then
    error "Cloud Run deployment failed. Check the GCP console for deployment logs."
fi

# The spinner is stopped by start_and_wait
info "Deployment successful! Service is now fully ready. ${EMOJI_SUCCESS}"


# ===============================================
# 🎉 FINAL CONFIGURATION LINK GENERATION & SHARING
# ===============================================
header "DEPLOYMENT SUCCESS & CONFIG LINK" "$EMOJI_SUCCESS"
echo -e "\n${GREEN}${BOLD}======================================================${NC}"
echo -e "${EMOJI_SUCCESS} ${GREEN}${BOLD}SERVICE DEPLOYED SUCCESSFULLY! SERVICE IS ACTIVE.${NC} ${EMOJI_SUCCESS}"
echo -e "${GREEN}${BOLD}======================================================${NC}\n"

# 1. Get Service URL
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
    --region="$REGION" \
    --format='value(status.url)' \
    --project="$GCP_PROJECT_ID" 2>/dev/null)

if [ -z "$SERVICE_URL" ]; then
    error "Failed to retrieve the Service URL after deployment. Service might be in a failed state."
fi

HOST_NAME=$(echo "$SERVICE_URL" | sed -E 's|https://||; s|/||')

# 2. Configuration Link Generation (URL Encoding Path)
# VLESS_PATH is either /ahlflk or ahlflk (for gRPC) or ahlflk (for Trojan password)
URL_PATH_ENCODED=$(echo "$VLESS_PATH" | sed 's/\//%2F/g') 
XRAY_LINK_LABEL="GCP-${PROTOCOL_LOWER^^}-${SERVICE_NAME}"
XRAY_LINK=""

if [[ "$PROTOCOL_LOWER" == "vless" ]]; then
    # VLESS WS link
    XRAY_LINK="vless://${USER_ID}@${HOST_DOMAIN}:443?encryption=none&security=tls&host=${HOST_NAME}&path=${URL_PATH_ENCODED}&type=ws&sni=${HOST_NAME}#${XRAY_LINK_LABEL}"
elif [[ "$PROTOCOL_LOWER" == "vlessgrpc" ]]; then
    # VLESS gRPC link (VLESS_PATH contains GRPC_SERVICE_NAME)
    XRAY_LINK="vless://${USER_ID}@${HOST_DOMAIN}:443?encryption=none&security=tls&type=grpc&serviceName=${VLESS_PATH}&sni=${HOST_NAME}#${XRAY_LINK_LABEL}"
elif [[ "$PROTOCOL_LOWER" == "trojan" ]]; then
    # Trojan link (USER_ID contains the password)
    XRAY_LINK="trojan://${USER_ID}@${HOST_DOMAIN}:443?security=tls&sni=${HOST_NAME}#${XRAY_LINK_LABEL}"
fi


# 3. Save Deployment Info to File
echo -e "\n${EMOJI_INFO} Saving deployment information to ${CYAN}${DEPLOY_INFO_FILE}${NC}..."

{
    echo "======================================================"
    echo "  GCP CLOUD RUN XRAY DEPLOYMENT INFO"
    echo "  Deployment Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "======================================================"
    echo "Project ID:          $GCP_PROJECT_ID"
    echo "Service Name:        $SERVICE_NAME"
    echo "Region:              $REGION"
    echo "Protocol:            $PROTOCOL"
    echo "Host Domain/SNI:     $HOST_DOMAIN"
    echo "Cloud Run URL:       $SERVICE_URL"
    echo "------------------------------------------------------"
    echo "UUID/Password:       $USER_ID"
    if [[ "$PROTOCOL_LOWER" == "vless" ]]; then
        echo "Vless Path:          $VLESS_PATH"
    elif [[ "$PROTOCOL_LOWER" == "vlessgrpc" ]]; then
        echo "gRPC Service Name:   $VLESS_PATH"
    fi
    echo "------------------------------------------------------"
    echo "XRAY Configuration Link:"
    echo "$XRAY_LINK"
    echo "======================================================"
} > "../$DEPLOY_INFO_FILE" # Go back one level to save in the initial directory

info "Deployment details saved successfully to ${CYAN}$DEPLOY_INFO_FILE${NC}"


# 4. Display Links
echo -e "${EMOJI_LINK} ${BLUE}Cloud Run URL:${NC}           ${CYAN}${SERVICE_URL}${NC}"
echo -e "${EMOJI_LINK} ${BLUE}XRAY Configuration Link:${NC}"
echo -e "${GREEN}${BOLD}${XRAY_LINK}${NC}"


# 5. Telegram Notification
if [ "$TELEGRAM_CHOICE" -ne "1" ]; then
    info "Preparing Telegram notification..."
    MESSAGE_BODY=$(cat <<EOF
*GCP XRAY Deployment Success!* ${EMOJI_SUCCESS}

*Protocol:* ${PROTOCOL}
*Region:* ${REGION}
*Service Name:* \`${SERVICE_NAME}\`
*Host/SNI:* \`${HOST_DOMAIN}\`

*XRAY Configuration Link:*
\`\`\`
${XRAY_LINK}
\`\`\`

*Note:* Tap on the link block to copy the full configuration link.
EOF
)
    send_telegram_notification "$MESSAGE_BODY"
fi

echo -e "\n${EMOJI_TITLE} ${GREEN}${BOLD}Deployment Complete! Your Service is now running.${NC} ${EMOJI_TITLE}"
cd ..
rm -rf "$REPO_DIR" # Cleanup cloned directory

# 6. Final Pause (Keeps the terminal open)
echo
# Clear the EXIT trap before the final read
trap - EXIT
read -rp "$(echo -e "${EMOJI_PROMPT} ${CYAN}Deployment Finished. Press [Enter] to close this window...${NC}")"
exit 0
