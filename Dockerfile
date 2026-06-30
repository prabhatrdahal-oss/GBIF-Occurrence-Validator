# =========================================================
# Dockerfile for OccurScan — GBIF Occurrence Validator
# =========================================================

# rocker/geospatial includes sf, terra, leaflet, sp, tidyverse pre-built
FROM rocker/geospatial:4.4.1

# ── Install shiny-server + system deps ───────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv python3-dev \
    libnlopt-dev gdebi-core wget \
    && wget -q https://download3.rstudio.org/ubuntu-18.04/x86_64/shiny-server-1.5.23.1020-amd64.deb \
    && gdebi -n shiny-server-1.5.23.1020-amd64.deb \
    && rm shiny-server-1.5.23.1020-amd64.deb \
    && rm -rf /var/lib/apt/lists/*

# ── Python virtualenv ─────────────────────────────────────
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
ENV RETICULATE_PYTHON=/opt/venv/bin/python3
RUN pip install --no-cache-dir earthengine-api numpy pandas

# ── R packages not in rocker/geospatial ──────────────────
RUN R -e "install.packages(c(\
    'shinydashboard','shinythemes','shinyWidgets','shinycssloaders','waiter',\
    'DT','plotly','viridis','leaflet','geodata'\
  ), repos='https://cloud.r-project.org/', Ncpus=4)"

RUN R -e "install.packages(c(\
    'rgbif','rredlist','CoordinateCleaner'\
  ), repos='https://cloud.r-project.org/', Ncpus=4)"

RUN R -e "install.packages(c(\
    'nloptr','lme4','mda','gam','earth','maxnet','randomForest','xgboost','gbm','cito'\
  ), repos='https://cloud.r-project.org/', Ncpus=4)"

RUN R -e "install.packages(c('biomod2','isotree'), repos='https://cloud.r-project.org/', Ncpus=4)"

RUN R -e "install.packages(c('reticulate','rgee','geojsonio','R.utils'), repos='https://cloud.r-project.org/')"

# ── Validate ─────────────────────────────────────────────
RUN R -e "pkgs <- c('shiny','shinydashboard','shinyWidgets','shinycssloaders','waiter','DT','leaflet','plotly','ggplot2','viridis','dplyr','tidyr','tibble','purrr','stringr','jsonlite','sf','terra','geodata','sp','rgbif','CoordinateCleaner','rredlist','biomod2','isotree','reticulate','rgee'); for(l in pkgs){ok<-requireNamespace(l,quietly=TRUE);message(l,if(ok)' OK' else ' MISSING');if(!ok)stop(paste('MISSING:',l))}"

# ── Create shiny user and directories ────────────────────
RUN useradd -m -s /bin/bash shiny || true \
    && mkdir -p /srv/shiny-server /srv/logs /srv/climate_cache \
    && mkdir -p /home/shiny/.config/earthengine \
    && chown -R shiny:shiny /srv/logs /srv/climate_cache /home/shiny

# ── App ───────────────────────────────────────────────────
COPY app_full.R /srv/shiny-server/app.R
RUN chown shiny:shiny /srv/shiny-server/app.R

# ── Shiny server config ───────────────────────────────────
RUN mkdir -p /etc/shiny-server && \
    printf 'run_as shiny;\nserver {\n  listen 3838;\n  location / {\n    site_dir /srv/shiny-server;\n    log_dir /srv/logs;\n    directory_index off;\n    app_idle_timeout 0;\n    app_init_timeout 120;\n  }\n}\n' \
    > /etc/shiny-server/shiny-server.conf

EXPOSE 3838
CMD ["/usr/bin/shiny-server"]
