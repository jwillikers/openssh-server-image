#!/usr/bin/env bash
set -o errexit

# Create a container
CONTAINER=$(buildah from scratch)

# Mount the container filesystem
MOUNTPOINT=$(buildah mount "$CONTAINER")

# glibc-minimal-langpack?
dnf install -y --installroot "$MOUNTPOINT" --releasever 34 bash coreutils openssh-server passwd shadow-utils --nodocs --setopt install_weak_deps=False

dnf clean all -y --installroot "$MOUNTPOINT" --releasever 34

buildah unmount "$CONTAINER"

buildah run "$CONTAINER" /bin/sh -c 'echo "LogLevel DEBUG2" > /etc/ssh/sshd_config.d/99-clion.conf'

buildah run "$CONTAINER" /bin/sh -c 'echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/99-clion.conf'
buildah run "$CONTAINER" /bin/sh -c 'echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/99-clion.conf'
buildah run "$CONTAINER" /bin/sh -c 'echo "PermitEmptyPasswords yes" >> /etc/ssh/sshd_config.d/99-clion.conf'
# buildah run "$CONTAINER" /bin/sh -c 'echo "Subsystem sftp /usr/lib/openssh/sftp-server" >> /etc/ssh/sshd_config.d/99-clion.conf'
buildah run "$CONTAINER" /bin/sh -c 'mkdir /run/sshd'

buildah run "$CONTAINER" /bin/sh -c 'ssh-keygen -A'

buildah run "$CONTAINER" /bin/sh -c 'useradd -ms /bin/bash user'

buildah run "$CONTAINER" /bin/sh -c 'echo password | passwd --stdin user'

# Expose Port 22/tcp
buildah config --port 22 "$CONTAINER"

# Start sshd
buildah config --cmd "/usr/sbin/sshd -D -e" "$CONTAINER"

buildah tag "$CONTAINER" latest 34

# Save the container to an image
buildah commit --squash "$CONTAINER" openssh-server

buildah rm "$CONTAINER"

