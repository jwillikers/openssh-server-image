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
   echo "Syntax: openssh-server-image-minimal.sh [-a|h]"
   echo "options:"
   echo "a     Build for the specified target architecture, i.e. amd64, arm, arm64."
   echo "h     Print this Help."
   echo
}

############################################################
############################################################
# Main program                                             #
############################################################
############################################################

# Set variables
ARCHITECTURE="$(podman info --format={{".Host.Arch"}})"

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

CONTAINER=$(buildah from --arch "$ARCHITECTURE" registry.fedoraproject.org/fedora-minimal:latest)
IMAGE="openssh-server"

buildah run "$CONTAINER" /bin/sh -c 'microdnf -y upgrade'

buildah run "$CONTAINER" /bin/sh -c 'microdnf -y reinstall shadow-utils'

buildah run "$CONTAINER" /bin/sh -c 'microdnf install -y glibc-locale-source openssh-server passwd shadow-utils --nodocs --setopt install_weak_deps=0'

buildah run "$CONTAINER" /bin/sh -c 'microdnf clean all -y'

buildah run "$CONTAINER" /bin/sh -c 'localedef --quiet -c -i en_US -f UTF-8 en_US.UTF-8'

buildah copy "$CONTAINER" 99-sshd.conf /etc/ssh/sshd_config.d/99-sshd.conf

# pam_loginuid wants to write to /proc/self/loginuid on new ssh session but can't.
# https://github.com/lxc/lxc/issues/661#issuecomment-222444916
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=726661
buildah run "$CONTAINER" /bin/sh -c '/usr/bin/sed -i -e "/pam_loginuid\.so$/ s/required/optional/" /etc/pam.d/*'

buildah run "$CONTAINER" /bin/sh -c 'mkdir /run/sshd'

buildah run "$CONTAINER" /bin/sh -c 'ssh-keygen -A'

buildah run "$CONTAINER" /bin/sh -c 'useradd user'

buildah run "$CONTAINER" /bin/sh -c 'chown user:user -R /home/user'

buildah run "$CONTAINER" /bin/sh -c 'echo password | passwd --stdin user'

buildah config --port 22 "$CONTAINER"

buildah config --cmd "/usr/sbin/sshd -D -e" "$CONTAINER"

buildah config --label "io.containers.autoupdate=registry" "$CONTAINER"

buildah config --author "jordan@jwillikers.com" "$CONTAINER"

buildah commit "$CONTAINER" "$IMAGE"

buildah rm "$CONTAINER"
