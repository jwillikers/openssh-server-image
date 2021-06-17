#!/usr/bin/env bash
set -o errexit

############################################################
# Help                                                     #
############################################################
Help()
{
   # Display Help
   echo "Generate a container image using an OpenSSH server with Buildah."
   echo
   echo "Syntax: openssh-server-image.sh [-a|h]"
   echo "options:"
   echo "a     Build for the specified target architecture, i.e. aarch64, arm, i686, ppc64le, s390x, or x86_64."
   echo "h     Print this Help."
   echo
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

# Set variables
ARCH="x86_64"

############################################################
# Process the input options. Add options as needed.        #
############################################################
while getopts ":a:h" option; do
   case $option in
      h) # display Help
         Help
         exit;;
      a) # Enter a target architecture
         ARCHITECTURE=$OPTARG;;
     \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
   esac
done

CONTAINER=$(buildah from --arch "$ARCHITECTURE" scratch)
IMAGE="openssh-server"

# Mount the container filesystem
MOUNTPOINT=$(buildah mount "$CONTAINER")

# glibc-minimal-langpack?
dnf install -y --installroot "$MOUNTPOINT" --releasever 34 bash coreutils openssh-server passwd shadow-utils --nodocs --setopt install_weak_deps=False

dnf clean all -y --installroot "$MOUNTPOINT" --releasever 34

buildah unmount "$CONTAINER"

buildah copy "$CONTAINER" 99-sshd.conf /etc/ssh/sshd_config.d/99-sshd.conf

buildah run "$CONTAINER" /bin/sh -c 'mkdir /run/sshd'

buildah run "$CONTAINER" /bin/sh -c 'ssh-keygen -A'

buildah run "$CONTAINER" /bin/sh -c 'useradd -ms /bin/bash user'

buildah run "$CONTAINER" /bin/sh -c 'echo password | passwd --stdin user'

buildah config --port 22 "$CONTAINER"

buildah config --cmd "/usr/sbin/sshd -D -e" "$CONTAINER"

buildah config --author "jordan@jwillikers.com" "$CONTAINER"

buildah config --comment "An OpenSSH server" "$CONTAINER"

buildah commit "$CONTAINER" "$IMAGE"

buildah rm "$CONTAINER"
