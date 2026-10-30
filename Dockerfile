FROM rocker/verse:4.4.1

LABEL maintainer="Raban Heller <raban.heller@outlook.com>"
LABEL description="Build environment for Scientometrics in R"

# System dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libgit2-dev \
    libpoppler-cpp-dev \
    libtesseract-dev \
    libleptonica-dev \
    libnetcdf-dev \
    libudunits2-dev \
    libgdal-dev \
    libfontconfig1-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libmagick++-dev \
    python3 \
    python3-venv \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Install Quarto
ARG QUARTO_VERSION=1.5.57
RUN curl -fsSL "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" -o quarto.deb \
    && dpkg -i quarto.deb \
    && rm quarto.deb

# Python venv for reticulate
RUN python3 -m venv /opt/scientometrics-py \
    && /opt/scientometrics-py/bin/pip install --no-cache-dir \
        sentence-transformers \
        bertopic \
        umap-learn \
        hdbscan

ENV RETICULATE_PYTHON=/opt/scientometrics-py/bin/python

# Copy project files
WORKDIR /book
COPY renv.lock renv.lock
COPY .Rprofile .Rprofile
COPY renv/ renv/

# Restore R packages
RUN R -e 'renv::restore(prompt = FALSE)'

# Copy remaining files
COPY . .

# Default command: render the book
CMD ["R", "-e", "bookdown::render_book(\"index.Rmd\", output_format = \"all\")"]
