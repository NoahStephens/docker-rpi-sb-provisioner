# docker-rpi-sb-provisioner

Docker image packaging repository for [raspberrypi/rpi-sb-provisioner](https://github.com/raspberrypi/rpi-sb-provisioner), using a structure inspired by [docker-library/postgres](https://github.com/docker-library/postgres).

## What this repo does

- Tracks upstream `rpi-sb-provisioner` releases in `versions.json`
- Generates versioned Dockerfiles from `Dockerfile.template`
- Builds and publishes images to:
  - `docker.io/noahstephens/rpi-sb-provisioner`
  - `ghcr.io/noahstephens/rpi-sb-provisioner`

## Layout

- `versions.sh`: resolves upstream tags/commits and updates `versions.json`
- `apply-templates.sh`: renders generated Dockerfiles into `<version>/<variant>/`
- `update.sh`: runs both scripts above
- `.github/workflows/ci.yml`: build + push workflow
- `.github/workflows/verify-templating.yml`: checks generated files are up to date

## Update flow

```bash
./update.sh
```

To update a specific series:

```bash
./update.sh 2.2
```

## Publish prerequisites

Set repository secrets/variables:

- Secret: `DOCKERHUB_TOKEN`
- Variable (optional): `DOCKERHUB_USERNAME` (defaults to `noahstephens`)

The workflow uses `GITHUB_TOKEN` for GHCR pushes.
