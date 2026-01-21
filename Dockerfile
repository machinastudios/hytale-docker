FROM eclipse-temurin:25.0.1_8-jre-alpine-3.23

LABEL org.opencontainers.image.source=https://github.com/machinastudios/hytale-docker
LABEL org.opencontainers.image.description="Hytale Server Docker Image"
LABEL org.opencontainers.image.licenses=MIT
LABEL org.opencontainers.image.authors="Machina Studios"
LABEL org.opencontainers.image.vendor="Machina Studios"
LABEL org.opencontainers.image.version="1.0.1"
LABEL org.opencontainers.image.revision="1.0.1"
LABEL org.opencontainers.image.url="https://github.com/machinastudios/hytale-docker"
LABEL org.opencontainers.image.documentation="https://github.com/machinastudios/hytale-docker"

# Accept the volume
VOLUME /hytale

# Go to the hytale directory
WORKDIR /hytale
RUN cd /hytale

# Set the downloader URL
ENV DOWNLOADER_URL=https://downloader.hytale.com/hytale-downloader.zip

# Install unzip, wget, curl, and jq (for JSON manipulation)
RUN apt-get update && apt-get install -y --no-install-recommends \
    unzip \
    wget \
    curl \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Download the downloader
RUN wget -q -O hytale-downloader.zip $DOWNLOADER_URL

# Unzip the downloader
RUN unzip -q hytale-downloader.zip

# Rename the downloader to hytale-downloader
RUN mv hytale-downloader-linux-amd64 /bin/hytale-downloader

# Make it executable
RUN chmod +x /bin/hytale-downloader

# Delete the Windows downloader
RUN rm hytale-downloader-windows-amd64.exe

# Clean up
RUN rm hytale-downloader.zip

# Expose the ports
EXPOSE 5520
EXPOSE 5005

# Copy the entrypoint script
COPY entrypoint.sh /entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x /entrypoint.sh

# Run the server
CMD ["/bin/bash", "/entrypoint.sh"]
