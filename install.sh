#!/bin/bash

set -e  # Exit on any error

echo "========================================="
echo "ROS2 Docker Template Installation Script"
echo "========================================="
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Get container name from folder name (sanitize for docker: lowercase, no spaces)
CONTAINER_NAME=$(basename "$SCRIPT_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
echo "Container name: $CONTAINER_NAME"

# Parse command line arguments
USE_GPU=""
for arg in "$@"; do
    case $arg in
        --gpu)
            USE_GPU="true"
            shift
            ;;
        --no-gpu)
            USE_GPU="false"
            shift
            ;;
        *)
            ;;
    esac
done

# Auto-detect NVIDIA GPU if not specified
if [ -z "$USE_GPU" ]; then
    echo "Detecting NVIDIA GPU..."
    if command -v nvidia-smi &> /dev/null && nvidia-smi &> /dev/null; then
        USE_GPU="true"
        echo "✓ NVIDIA GPU detected"
    else
        USE_GPU="false"
        echo "✓ No NVIDIA GPU detected (or driver not installed)"
    fi
else
    if [ "$USE_GPU" = "true" ]; then
        echo "GPU support enabled via --gpu flag"
    else
        echo "GPU support disabled via --no-gpu flag"
    fi
fi

# Change to the container directory
echo "Changing to directory: $SCRIPT_DIR"
cd "$SCRIPT_DIR" || exit 1

# Build the Docker image
echo ""
echo "Building Docker image with docker compose..."
if [ "$USE_GPU" = "true" ]; then
    docker compose -f docker-compose.yaml -f docker-compose.nvidia.yaml build
else
    docker compose build
fi

if [ $? -eq 0 ]; then
    echo "✓ Docker image built successfully"
else
    echo "✗ Docker build failed"
    exit 1
fi

# Create applications directory if it doesn't exist
APPS_DIR="$HOME/.local/share/applications/$SCRIPT_DIR"
echo ""
echo "Ensuring applications directory exists: $APPS_DIR"
if [ -d "$APPS_DIR" ]; then
    rm -rf "$APPS_DIR"
fi
mkdir -p "$APPS_DIR"

# Update .env file with CONTAINER_NAME and USE_GPU
ENV_FILE=".env"
if [ -f "$SCRIPT_DIR/$ENV_FILE" ]; then
    # Update CONTAINER_NAME
    if grep -q "^CONTAINER_NAME=" "$SCRIPT_DIR/$ENV_FILE"; then
        sed -i "s/^CONTAINER_NAME=.*/CONTAINER_NAME=$CONTAINER_NAME/" "$SCRIPT_DIR/$ENV_FILE"
    else
        echo "CONTAINER_NAME=$CONTAINER_NAME" >> "$SCRIPT_DIR/$ENV_FILE"
    fi
    # Update USE_GPU
    if grep -q "^USE_GPU=" "$SCRIPT_DIR/$ENV_FILE"; then
        sed -i "s/^USE_GPU=.*/USE_GPU=$USE_GPU/" "$SCRIPT_DIR/$ENV_FILE"
    else
        echo "USE_GPU=$USE_GPU" >> "$SCRIPT_DIR/$ENV_FILE"
    fi
    # Copy .env file to apps directory
    echo "Copying .env file to $APPS_DIR..."
    cp "$SCRIPT_DIR/$ENV_FILE" "$APPS_DIR/"
    echo "✓ .env file installed (CONTAINER_NAME=$CONTAINER_NAME, USE_GPU=$USE_GPU)"
else
    echo "✗ .env file not found: $SCRIPT_DIR/$ENV_FILE"
    exit 1
fi

# Copy docker-compose files
echo "Copying docker-compose files to $APPS_DIR..."
cp "$SCRIPT_DIR/docker-compose.yaml" "$APPS_DIR/"
if [ -f "$SCRIPT_DIR/docker-compose.nvidia.yaml" ]; then
    cp "$SCRIPT_DIR/docker-compose.nvidia.yaml" "$APPS_DIR/"
fi
echo "✓ Docker compose files installed"

# Copy main script
MAIN_SCRIPT="launch_container.sh"
if [ -f "$SCRIPT_DIR/$MAIN_SCRIPT" ]; then
    echo "Copying main script to $APPS_DIR..."
    cp "$SCRIPT_DIR/$MAIN_SCRIPT" "$APPS_DIR/"
    chmod +x "$APPS_DIR/$MAIN_SCRIPT"
    echo "✓ Main script installed"
else
    echo "✗ Main script not found: $SCRIPT_DIR/$MAIN_SCRIPT"
    exit 1
fi

# Copy assets
ASSETS_DIR="$APPS_DIR/assets"
echo ""
echo "Ensuring assets directory exists: $ASSETS_DIR"
mkdir -p "$ASSETS_DIR"

# Copy asset files
for asset in "$SCRIPT_DIR/assets/"*; do
    if [ -f "$asset" ]; then
        echo "Copying asset file to $ASSETS_DIR..."
        cp "$asset" "$ASSETS_DIR/"
    fi
done

# Copy desktop file
BRINGUP_DESKTOP_FILE="bringup.desktop"
if [ -f "$SCRIPT_DIR/$BRINGUP_DESKTOP_FILE" ]; then
    echo "Copying bringup desktop file to $APPS_DIR..."
    cp "$SCRIPT_DIR/$BRINGUP_DESKTOP_FILE" "$APPS_DIR/"
    chmod +x "$APPS_DIR/$BRINGUP_DESKTOP_FILE"
    echo "✓ Bringup desktop file installed"
    echo "Icon=$ASSETS_DIR/bringup_icon.png" >> "$APPS_DIR/$BRINGUP_DESKTOP_FILE"
    echo "Creating bringup desktop shortcut..."
    # Remove existing shortcut if it exists
    rm -f "$HOME/Desktop/$BRINGUP_DESKTOP_FILE"
    ln -s "$APPS_DIR/$BRINGUP_DESKTOP_FILE" "$HOME/Desktop/"
    echo "✓ Desktop shortcut created"
else
    echo "✗ Bringup desktop file not found: $SCRIPT_DIR/$BRINGUP_DESKTOP_FILE"
    exit 1
fi
# Copy devel desktop file
DEVEL_DESKTOP_FILE="devel.desktop"
if [ -f "$SCRIPT_DIR/$DEVEL_DESKTOP_FILE" ]; then
    echo "Copying devel desktop file to $APPS_DIR..."
    cp "$SCRIPT_DIR/$DEVEL_DESKTOP_FILE" "$APPS_DIR/"
    chmod +x "$APPS_DIR/$DEVEL_DESKTOP_FILE"
    echo "✓ Devel desktop file installed"
    echo "Icon=$ASSETS_DIR/devel_icon.png" >> "$APPS_DIR/$DEVEL_DESKTOP_FILE"
    echo "Creating devel desktop shortcut..."
    # Remove existing shortcut if it exists
    rm -f "$HOME/Desktop/$DEVEL_DESKTOP_FILE"
    ln -s "$APPS_DIR/$DEVEL_DESKTOP_FILE" "$HOME/Desktop/"
    echo "✓ Desktop shortcut created"
else
    echo "✗ Devel desktop file not found: $SCRIPT_DIR/$DEVEL_DESKTOP_FILE"
    exit 1
fi

# Make the main scripts executable
MAIN_SCRIPT="launch_container.sh"
if [ -f "$SCRIPT_DIR/$MAIN_SCRIPT" ]; then
    echo "Making main script executable..."
    chmod +x "$SCRIPT_DIR/$MAIN_SCRIPT"
    echo "✓ Main script is executable"
else
    echo "✗ Main script not found: $SCRIPT_DIR/$MAIN_SCRIPT"
    exit 1
fi

# Make run.sh executable
RUN_SCRIPT="run.sh"
if [ -f "$SCRIPT_DIR/$RUN_SCRIPT" ]; then
    echo "Making run script executable..."
    chmod +x "$SCRIPT_DIR/$RUN_SCRIPT"
    echo "✓ Run script is executable"
else
    echo "✗ Run script not found: $SCRIPT_DIR/$RUN_SCRIPT"
    exit 1
fi

# Update desktop database (optional, helps with immediate icon visibility)
if command -v update-desktop-database &> /dev/null; then
    echo ""
    echo "Updating desktop database..."
    update-desktop-database "$APPS_DIR"
    echo "✓ Desktop database updated"
    echo ""
fi

# Install vcstool if not installed
if ! command -v vcs &> /dev/null; then
    echo ""
    echo "vcstool not found. Installing vcstool..."
    sudo apt update
    sudo apt install -y python3-vcstool
    echo "✓ vcstool installed"
else
    echo ""
    echo "✓ vcstool is already installed"
fi

# Import dependencies into shared_ws directory
SHARED_WS="$SCRIPT_DIR/shared_ws"
# If src folder doesn't exist
if [ ! -d "$SHARED_WS/src" ]; then
    echo "Creating src directory: $SHARED_WS/src"
    mkdir -p "$SHARED_WS/src"
    cd "$SHARED_WS/src"
    echo "Importing dependencies..."
    vcs import < ../shared.repos
    echo "✓ Dependencies imported"
else
    echo "✓ Src directory already exists: $SHARED_WS/src"
fi

# Install vcstool if not installed                                                               
if ! command -v vcs &> /dev/null; then                                                           
    echo ""                                                                                      
    echo "vcstool not found. Installing vcstool..."                                              
    sudo apt install -y pipx                                                                     
    pipx install vcstool                                                                         
    pipx ensurepath                                                                              
    export PATH="$PATH:$HOME/.local/bin"                                                         
    echo "✓ vcstool installed"                                                                   
else                                                                                             
    echo ""                                                                                      
    echo "✓ vcstool is already installed"                                                        
fi

# If git-lfs is not installed, Install git-lfs
if ! command -v git-lfs &> /dev/null; then
    echo ""
    echo "Git LFS not found. Installing Git LFS..."
    curl -s https://packagecloud.io/install/repositories/github/git-lfs/script.deb.sh | sudo bash
    sudo apt-get install git-lfs
    git lfs install
    echo "✓ Git LFS installed"
else
    echo ""
    echo "✓ Git LFS is already installed"
fi

# Import data repos into data directory
DATA_DIR="$SCRIPT_DIR/data"
cd "$DATA_DIR"
echo "Importing data repositories..."
vcs import < ./data.repos
# Enter each folder under DATA_DIR
for dir in "$DATA_DIR"/*/; do
    if [ -d "$dir/.git" ]; then
        cd "$dir"
        git lfs install
        git lfs pull
        git lfs fetch --all
        echo "✓ Data repository updated: $dir"
        cd "$DATA_DIR"
    fi
done

# Set kernel socket buffer limit (permanent)
if ! grep -q "net.core.rmem_max=26214400" /etc/sysctl.conf; then
    echo "net.core.rmem_max=26214400" | sudo tee -a /etc/sysctl.conf
fi
if ! grep -q "net.core.wmem_max=26214400" /etc/sysctl.conf; then
    echo "net.core.wmem_max=26214400" | sudo tee -a /etc/sysctl.conf
fi
sudo sysctl -p

# Build shared_ws inside the container
echo ""
echo "Building shared_ws..."
cd "$SCRIPT_DIR"
./launch_container.sh colcon build 
echo "✓ shared_ws built"

# Install arduino-cli if not installed
# If arduino directory doesn't exist, create it and install arduino-cli there to avoid polluting user PATH with arduino-cli
ARDUINO_DIR="$SCRIPT_DIR/arduino"
ARDUINO_CLI="$ARDUINO_DIR/bin/arduino-cli"
ARDUINO_CONFIG="$ARDUINO_DIR/arduino-cli.yaml"

if [ ! -x "$ARDUINO_CLI" ]; then
    echo ""
    echo "Arduino CLI not found. Installing Arduino CLI..."
    mkdir -p "$ARDUINO_DIR"
    cd "$ARDUINO_DIR"
    curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
    cd "$SCRIPT_DIR"
    echo "✓ Arduino CLI installed"
else
    echo ""
    echo "✓ Arduino CLI is already installed"
fi

# Install Arduino board cores and libraries using local config
cd "$ARDUINO_DIR"
echo ""
echo "Updating Arduino core index..."
"$ARDUINO_CLI" --config-file "$ARDUINO_CONFIG" core update-index
echo "Installing RP2040 board core..."
"$ARDUINO_CLI" --config-file "$ARDUINO_CONFIG" core install rp2040:rp2040
echo "✓ RP2040 board core installed"

echo "Installing Arduino libraries..."
"$ARDUINO_CLI" --config-file "$ARDUINO_CONFIG" lib install "TMCStepper"
"$ARDUINO_CLI" --config-file "$ARDUINO_CONFIG" lib install "Adafruit NeoPixel"
echo "✓ Arduino libraries installed"

echo ""
echo "Compiling stepper-neopixel-controller firmware..."
FIRMWARE_DIR="$SCRIPT_DIR/shared_ws/src/inspection_eoat/firmware/stepper-neopixel-controller"
"$ARDUINO_CLI" --config-file "$ARDUINO_CONFIG" compile --fqbn rp2040:rp2040:adafruit_qtpy "$FIRMWARE_DIR"
echo "✓ Firmware compiled"

# Helper: find and mount RPI-RP2 bootloader drive, returns path via RPI_DRIVE
find_rpi_drive() {
    RPI_DRIVE=""
    # Check if already mounted
    RPI_DRIVE=$(mount | grep -i "RPI-RP2" | awk '{print $3}')
    if [ -n "$RPI_DRIVE" ]; then
        return 0
    fi
    # Check for unmounted RP2040 block device and mount it
    RPI_DEV=$(lsblk -o NAME,LABEL -rn 2>/dev/null | grep -i "RPI-RP2" | awk '{print $1}')
    if [ -n "$RPI_DEV" ]; then
        RPI_DRIVE="/mnt/rpi-rp2"
        sudo mkdir -p "$RPI_DRIVE"
        sudo mount "/dev/$RPI_DEV" "$RPI_DRIVE"
        echo "Mounted /dev/$RPI_DEV at $RPI_DRIVE"
        return 0
    fi
    return 1
}

# Helper: copy UF2 to mounted RPI-RP2 drive
upload_uf2() {
    local drive="$1"
    UF2_FILE=$(find "$HOME/.cache/arduino/sketches" -name "stepper-neopixel-controller.ino.uf2" 2>/dev/null | head -n 1)
    if [ -z "$UF2_FILE" ]; then
        UF2_FILE=$(find "$FIRMWARE_DIR" -name "*.uf2" 2>/dev/null | head -n 1)
    fi
    if [ -n "$UF2_FILE" ]; then
        echo "Copying $UF2_FILE to $drive..."
        sudo cp "$UF2_FILE" "$drive/"
        sync
        echo "✓ Firmware uploaded successfully"
        return 0
    else
        echo "WARNING: Could not find compiled .uf2 file. Try running compile step again."
        return 1
    fi
}

# Upload firmware
# First check if the board is already in bootloader mode (RPI-RP2 drive present)
echo ""
echo "Checking for RP2040 microcontroller..."
if find_rpi_drive; then
    echo "Board already in bootloader mode (RPI-RP2 drive found at $RPI_DRIVE)"
    upload_uf2 "$RPI_DRIVE"
    if [ "$RPI_DRIVE" = "/mnt/rpi-rp2" ]; then
        sudo umount "$RPI_DRIVE" 2>/dev/null || true
    fi
else
    # Board not in bootloader — check for serial port and reset into bootloader
    ACM_PORT=$(ls /dev/ttyACM* 2>/dev/null | head -n 1)
    if [ -n "$ACM_PORT" ]; then
        echo "Microcontroller detected on $ACM_PORT. Resetting into bootloader..."

        # Trigger 1200 baud reset to enter bootloader
        # Must actually open and close the port at 1200 baud (not just configure it)
        python3 -c "
import serial, time
s = serial.Serial('$ACM_PORT', 1200)
time.sleep(0.1)
s.close()
" 2>/dev/null || {
            # Fallback: open/close port via bash file descriptor
            sudo stty -F "$ACM_PORT" 1200
            exec 3<>"$ACM_PORT"
            sleep 0.1
            exec 3>&-
        }
        sleep 2

        # Wait for RPI-RP2 drive to appear
        echo "Waiting for RPI-RP2 bootloader drive..."
        FOUND=false
        for i in $(seq 1 30); do
            if find_rpi_drive; then
                FOUND=true
                break
            fi
            sleep 1
        done

        if [ "$FOUND" = true ]; then
            upload_uf2 "$RPI_DRIVE"
            if [ "$RPI_DRIVE" = "/mnt/rpi-rp2" ]; then
                sudo umount "$RPI_DRIVE" 2>/dev/null || true
            fi
        else
            echo "WARNING: RPI-RP2 drive did not appear after reset."
            echo "  Try holding BOOTSEL while plugging in, then re-run this script."
        fi
    else
        echo "WARNING: No microcontroller detected (no serial port or RPI-RP2 drive)."
        echo "  Connect the microcontroller and re-run this script."
    fi
fi
cd "$SCRIPT_DIR"

# Set up systemd service for auto-start on boot
echo ""
echo "Setting up systemd service for auto-start..."
SERVICE_NAME="inspection-eoat"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

# Create the systemd service file
sudo tee "$SERVICE_FILE" > /dev/null << EOF
[Unit]
Description=Inspection EOAT ROS2 Docker Container
After=docker.service network-online.target
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
User=$USER
WorkingDirectory=$SCRIPT_DIR
ExecStart=$SCRIPT_DIR/run.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd daemon and enable the service
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME.service"
echo "✓ Systemd service '$SERVICE_NAME' created and enabled"

# Restart the service to apply changes
echo "Restarting service to apply changes..."
sudo systemctl restart "$SERVICE_NAME.service"
echo "✓ Service restarted"
echo ""
echo "  To check status: sudo systemctl status $SERVICE_NAME"
echo "  To view logs: sudo journalctl -u $SERVICE_NAME -f"
echo "  To disable auto-start: sudo systemctl disable $SERVICE_NAME"

echo ""
echo "========================================="
echo "Installation complete!"
echo "========================================="
echo ""
echo "Container name: $CONTAINER_NAME"
echo "GPU support: $USE_GPU"
echo ""
echo "You can now launch the container by running: ./launch_container.sh"
echo "The container will also auto-start on boot via systemd."
echo ""
