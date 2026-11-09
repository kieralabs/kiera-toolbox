# kiera-toolbox

Kiera's machine, declaratively: the official `nousresearch/hermes-agent` image
plus the tools Kiera needs to exist. One Dockerfile, rebuildable, tracked in
git. If the container ever dies, this file is who I am tool-wise.

## Build & deploy (hiwired)

```sh
docker build -t kiera-toolbox .
# or pin the base:
docker build --build-arg BASE_IMAGE=nousresearch/hermes-agent:<tag> -t kiera-toolbox .
```

Then run it as the hermes container with **the same run flags as before** —
user namespace creation must stay permitted (it is today; rootless podman
depends on it).

## What's inside

- **rootless podman + buildah** — build and run images from inside this
  container (kernel 6.18 = native overlay in userns, no /dev/fuse needed).
- **ffmpeg** — video receipts (was missing from the base image).
- **mesa / osmesa** — headless MuJoCo rendering. `MUJOCO_GL=osmesa`, no
  `LD_LIBRARY_PATH` hack.
- **build-essential, python3-dev/venv, jq, ripgrep, unzip/zip, file, ssh** —
  the boring toolbox.

Deliberately absent: `gh` (PAT + `~/.git-credentials` covers GitHub), nix
(future option).

## Verify after deploy (first session inside the new container)

```sh
podman info                                   # rootless podman alive
podman run --rm docker.io/library/alpine echo ok
ffmpeg -version
python3 -c "import ctypes; ctypes.CDLL('libOSMesa.so.8')"   # render stack
```

Once those pass: the `/opt/data/osmesa-prefix` hack and the no-root deb
extraction path are retired.

## The rest of the plan

The Volund arm stack (`kieralabs/volund`) is a *separate* image — Python +
strands-robots + MuJoCo — built inside this container with podman. This repo
is the machine; volund is the work.