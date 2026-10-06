# Connect IQ toolchain on Ubuntu 22.04.
#
# Reason: the SDK Manager AND the simulator are linked against webkit2gtk-4.0
# and libsoup2. Ubuntu 24.04 only ships webkit2gtk-4.1 with libsoup3, and
# those two cannot run together in one process. 22.04 still has the right stack.
#
# The SDK and the downloaded devices live on the host in ~/.Garmin, so the
# container stays disposable.
FROM ubuntu:22.04

ARG UID=1000
ARG GID=1000
ARG USER=dev
# Must be equal to $HOME on the host: monkeyc reads Java's user.home, which
# comes from /etc/passwd - not from the HOME environment variable. If it's
# wrong, the compiler looks for devices in the wrong directory and you get
# "Invalid device id specified".
ARG HOME_DIR=/home/dev

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        libwebkit2gtk-4.0-37 \
        libjavascriptcoregtk-4.0-18 \
        libsoup2.4-1 \
        libgtk-3-0 \
        libgl1 libglx-mesa0 libegl1 \
        libasound2 \
        libnss3 libxss1 \
        libsecret-1-0 \
        libusb-1.0-0 \
        libsm6 libice6 \
        openjdk-17-jre-headless \
        fonts-liberation fonts-dejavu-core \
        ca-certificates curl unzip python3 \
        xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Same UID/GID as the host, so files in ~/.Garmin and the project stay yours
# and not root's.
RUN groupadd -g "${GID}" "${USER}" 2>/dev/null || true \
 && useradd -u "${UID}" -g "${GID}" -d "${HOME_DIR}" -M -s /bin/bash "${USER}" 2>/dev/null || true \
 && mkdir -p "${HOME_DIR}" && chown "${UID}:${GID}" "${HOME_DIR}"

# Trust our own CA, so the simulator accepts the HTTPS mock.
COPY --chown=root:root tls/ca.crt /usr/local/share/ca-certificates/ciq-probe-mock.crt
RUN update-ca-certificates

USER ${UID}:${GID}
ENV HOME=${HOME_DIR}
WORKDIR /work
CMD ["/bin/bash"]
