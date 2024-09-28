# syntax=docker/dockerfile:1.6.0
# usage: `docker build -t cuda-pytorch-ai:23.12.240904 --no-cache --progress=plain . &> build.log`

### Base stage for dependencies and environment setup ###
FROM nvcr.io/nvidia/pytorch:23.12-py3
# release https://docs.nvidia.com/deeplearning/frameworks/pytorch-release-notes/rel-23-12.html

# Expose ports for applications
#EXPOSE 22

# Accept build arguments for user, UID, and GID
ARG USERNAME=transcribe-ui
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Set environment variables to reduce interaction during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Set environment variables
ENV LANG=en_US.UTF-8 \
    NVIDIA_VISIBLE_DEVICES=all \
    NVIDIA_DRIVER_CAPABILITIES=compute,utility \
    TORCH_EXTENSIONS_DIR=/opt/torch_extensions \
    TZ=America/New_York \
    PYTHONUNBUFFERED=1
    
# configure as root
SHELL ["/usr/bin/bash", "--login", "-c"]


#COPY /home/bruce/_code/_pods/_support/_scripts/harden_debian.conf /etc/harden_debian.conf
#COPY /home/bruce/_code/_pods/_support/_scripts/harden_debian.sh /root/_scripts/harden_debian.sh 
#RUN chmod -x /root/_scripts/harden_debian.sh


# Install dependencies
RUN mv /root/.cache/torch_extensions /opt/torch_extensions \
        && apt-get update --fix-missing \
        && apt-get install --no-install-recommends --yes \
            aria2 bash-completion build-essential cython3 debconf-utils dnsutils dstat ffmpeg \
            file fonts-dejavu-core google-perftools htop iproute2 pkg-config moreutils net-tools \
            openssh-server python3-dev python3-opencv python3.10-venv ripgrep shellcheck ssh \
            sudo tmux tree tzdata zip \
        && apt-get autoremove --yes \
        && apt-get clean \
        && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
        && pip3 install --no-input --upgrade pip \
        && pip3 install --no-input --upgrade bpytop cookiecutter ffmpeg-python pipdeptree setuptools \
        thefuck tldr typing_extensions


COPY ./test.wav /test.wav

# INSTALL: https://github.com/MahmoudAshraf97/whisper-diarization
WORKDIR /whisper-diarization
COPY ./whisper-diarization /whisper-diarization
RUN pip install huggingface-hub==0.23.2 \
        && pip install -r requirements.txt 


# INSTALL: https://github.com/meilisearch/meilisearch
# req for calls to ts-meilisearch
RUN pip install meilisearch

# create user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash -g $USERNAME -G sudo $USERNAME \
    && echo $USERNAME ALL=\(ALL\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME


# Add this to your Dockerfile in `ts-gpu` directory
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Use the entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
