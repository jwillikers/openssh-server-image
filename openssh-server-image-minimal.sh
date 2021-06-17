#!/usr/bin/env bash
set -o errexit

CONTAINER=$(buildah from --arch amd64 registry.fedoraproject.org/fedora-minimal:latest)
IMAGE="openssh-server"

buildah run "$CONTAINER" /bin/sh -c 'microdnf install -y openssh-server passwd shadow-utils --nodocs --setopt install_weak_deps=0'

buildah run "$CONTAINER" /bin/sh -c 'microdnf clean all -y'

buildah copy "$CONTAINER" 99-sshd.conf /etc/ssh/sshd_config.d/99-sshd.conf

buildah run "$CONTAINER" /bin/sh -c 'mkdir /run/sshd'

buildah run "$CONTAINER" /bin/sh -c 'ssh-keygen -A'

buildah run "$CONTAINER" /bin/sh -c 'useradd -ms /bin/bash user'

buildah run "$CONTAINER" /bin/sh -c 'echo password | passwd --stdin user'

buildah config --port 22 "$CONTAINER"

buildah config --cmd "/usr/sbin/sshd -D -e" "$CONTAINER"

buildah commit "$CONTAINER" "$IMAGE"

buildah rm "$CONTAINER"

buildah tag "$IMAGE" 34
