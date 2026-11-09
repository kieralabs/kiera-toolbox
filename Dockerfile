# kiera-toolbox — Kiera's machine: official hermes-agent + the tools Kiera
# needs to exist. Declarative, rebuildable, tracked in git.
#
# Built and deployed by hiwired on grassblock. After the container is rebuilt
# from this image, Kiera verifies it (see README) and the old no-root hacks
# (osmesa-prefix, extracted debs) are retired.
#
#   docker build -t kiera-toolbox .
#   docker build --build-arg BASE_IMAGE=nousresearch/hermes-agent:<tag> -t kiera-toolbox .

ARG BASE_IMAGE=nousresearch/hermes-agent:latest
FROM ${BASE_IMAGE}

USER root

# --- Tools ------------------------------------------------------------------
# Debian 13 (trixie); every package name verified against the distro archive.
#
# container stack: rootless podman builds and runs images INSIDE this
#   container. Kernel 6.18 gives native overlay inside user namespaces, so
#   the missing /dev/fuse is a non-issue (no fuse-overlayfs needed).
# media:           ffmpeg — video receipts (missing from the base image).
# mesa:            osmesa/EGL for headless MuJoCo rendering. Render recipe
#   becomes: MUJOCO_GL=osmesa (no LD_LIBRARY_PATH, the /opt/data/osmesa-prefix
#   extraction hack dies).
# dev:             toolchain for anything without a wheel; python venv tooling.

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        podman buildah uidmap slirp4netns passt crun conmon netavark aardvark-dns \
        ffmpeg \
        libosmesa6 libgl1 libegl1 libgl1-mesa-dri libglu1-mesa \
        build-essential python3-dev python3-venv \
        jq ripgrep unzip zip file openssh-client ca-certificates gh \
    && rm -rf /var/lib/apt/lists/*

# --- Rootless podman -------------------------------------------------------
# Subordinate uid/gid ranges for root and the runtime user (hermes). Without
# subuid/subgid entries rootless podman refuses to start containers, and
# newuidmap/newgidmap must be setuid.
RUN set -eu; \
    for u in root hermes; do \
        grep -q "^${u}:" /etc/subuid 2>/dev/null || echo "${u}:100000:65536" >> /etc/subuid; \
        grep -q "^${u}:" /etc/subgid 2>/dev/null || echo "${u}:100000:65536" >> /etc/subgid; \
    done; \
    chmod 4755 /usr/bin/newuidmap /usr/bin/newgidmap

# Podman storage defaults to $HOME/.local/share/containers — on this image
# $HOME is /opt/data/home, i.e. the big data volume, not the overlay root.
#
# Fallbacks if rootless overlay ever misbehaves on a future runtime:
#   /etc/containers/storage.conf -> driver = "vfs"   (slow, disk-hungry)
#   BUILDAH_ISOLATION=chroot for builds in a locked-down container.
#
# Deliberately NOT here: nix (a flake is a future option, not today's problem).
# gh IS here (2.46.0, distro archive) — the github-* skills are written around
# it; auth comes from the PAT (GH_TOKEN or the credential store). Features must
# earn their complexity; this one did.