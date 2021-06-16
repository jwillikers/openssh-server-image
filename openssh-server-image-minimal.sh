#!/usr/bin/env bash
set -o errexit

# Create a container
CONTAINER=$(buildah from --arch amd64 registry.fedoraproject.org/fedora-minimal:latest)

buildah run "$CONTAINER" /bin/sh -c 'microdnf install -y openssh-server passwd shadow-utils --nodocs --setopt install_weak_deps=0'

buildah run "$CONTAINER" /bin/sh -c 'microdnf clean all -y'

buildah run "$CONTAINER" /bin/sh -c 'echo "LogLevel DEBUG2" > /etc/ssh/sshd_config.d/99-clion.conf'

buildah run "$CONTAINER" /bin/sh -c 'echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/99-clion.conf'
buildah run "$CONTAINER" /bin/sh -c 'echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/99-clion.conf'
buildah run "$CONTAINER" /bin/sh -c 'echo "PermitEmptyPasswords yes" >> /etc/ssh/sshd_config.d/99-clion.conf'
# buildah run "$CONTAINER" /bin/sh -c 'echo "Subsystem sftp /usr/lib/openssh/sftp-server" >> /etc/ssh/sshd_config.d/99-clion.conf'
buildah run "$CONTAINER" /bin/sh -c 'mkdir /run/sshd'

buildah run "$CONTAINER" /bin/sh -c 'ssh-keygen -A'

buildah run "$CONTAINER" /bin/sh -c 'useradd -ms /bin/bash user'

buildah run "$CONTAINER" /bin/sh -c 'echo password | passwd --stdin user'

buildah config --port 22 "$CONTAINER"

buildah config --cmd "/usr/sbin/sshd -D -e" "$CONTAINER"

buildah tag "$CONTAINER" latest 34

buildah commit "$CONTAINER" openssh-server

buildah rm "$CONTAINER"

