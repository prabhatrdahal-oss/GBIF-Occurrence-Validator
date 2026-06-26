# =========================================================
# Dockerfile for GBIF Validator
# =========================================================

FROM rocker/shiny:latest

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgdal-dev \
    libgeos-dev \
    libproj-dev \
    libudunits2-dev \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment and install Python packages
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

RUN pip install --no-cache-dir \
    earthengine-api \
    numpy \
    pandas

# Set Python path for reticulate
ENV RETICULATE_PYTHON=/opt/venv/bin/python3

# Install R packages
RUN R -e "install.packages(c(\
    'shiny', 'shinydashboard', 'shinythemes', 'shinyWidgets', \
    'shinycssloaders', 'waiter', 'ggplot2', 'plotly', 'DT', \
    'leaflet', 'dplyr', 'tidyr', 'tibble', 'sf', 'viridis', \
    'rgbif', 'CoordinateCleaner', 'rredlist', 'biomod2', \
    'geodata', 'terra', 'isotree', 'purrr', \
    'remotes', 'reticulate' \
), repos='https://cloud.r-project.org/')" && \
R -e "remotes::install_github('r-spatial/rgee')"

# Create directory for Earth Engine credentials
RUN mkdir -p /root/.config/earthengine

# Copy the app files - CHANGE THIS LINE
COPY app_full.R /srv/shiny-server/app.R

# Set permissions
RUN chown -R shiny:shiny /srv/shiny-server

# Expose Shiny port
EXPOSE 3838

# Start Shiny Server
CMD ["/usr/bin/shiny-server"]