#!/usr/bin/env fish

set -l options (fish_opt --short a --long architecture --required-val)
set -a options (fish_opt --short m --long manifest --required-val)
set -a options (fish_opt --short n --long name --required-val)
set -a options (fish_opt --short h --long help)

argparse --max-args 0 $options -- $argv
or exit

if set -q _flag_help
    echo "build.fish [-a|--architecture] [-h|--help] [-m|--manifest] [-n|--name]"
    exit 0
end

set -l architecture (buildah info --format={{".host.arch"}})
if set -q _flag_architecture
    set architecture $_flag_architecture
end
echo "The image will be built for the $architecture architecture."

if set -q _flag_manifest
    set -l manifest $_flag_manifest
    echo "The image will be added to the $manifest manifest."
end

set -l name openssh-server
if set -q _flag_name
    set name $_flag_name
end

set -l container (buildah from --arch $architecture scratch)
set -l mountpoint (buildah mount $container)

podman run --rm --arch $architecture --volume $mountpoint:/mnt:Z registry.fedoraproject.org/fedora:latest \
    bash -c "dnf -y install --installroot /mnt --releasever 34 glibc-minimal-langpack openssh-server passwd shadow-utils --nodocs --setopt install_weak_deps=False"
or exit

podman run --rm --arch $architecture --volume $mountpoint:/mnt:Z registry.fedoraproject.org/fedora:latest \
    bash -c "dnf clean all -y --installroot /mnt --releasever 34"
or exit

# pam_loginuid wants to write to /proc/self/loginuid on new ssh session but can't.
# https://github.com/lxc/lxc/issues/661#issuecomment-222444916
# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=726661
podman run --rm --arch $architecture --volume $mountpoint:/mnt:Z registry.fedoraproject.org/fedora:latest \
    bash -c 'sed -i -e "/pam_loginuid\.so$/ s/required/optional/" /etc/pam.d/*'
or exit

# todo Is updating the locale necessary?
#   bash -c "localedef --quiet -c -i en_US -f UTF-8 en_US.UTF-8"

mkdir -p $mountpoint/run/sshd
or exit

ssh-keygen -A -f $mountpoint
or exit

set -l script_directory (dirname (status --current-filename))

cp $script_directory/99-sshd.conf $mountpoint/etc/ssh/sshd_config.d/99-sshd.conf
or exit

podman run --rm --arch $architecture --volume $mountpoint:/mnt:Z registry.fedoraproject.org/fedora:latest \
    bash -c "useradd --root /mnt user"
or exit

podman run --rm --arch $architecture --volume $mountpoint:/mnt:Z registry.fedoraproject.org/fedora:latest \
    bash -c "chpasswd --root /mnt user:password"
or exit

buildah unmount $container
or exit

buildah config --volume '["/etc/ssh", "/home/user/.ssh"]' $container
or exit

buildah config --port 22 $container
or exit

buildah config --cmd '["/usr/sbin/sshd", "-D", "-e"]' $container
or exit

buildah config --label io.containers.autoupdate=registry $container
or exit

buildah config --author jordan@jwillikers.com $container
or exit

buildah config --arch $architecture $container
or exit

if set -q manifest
    buildah commit --rm --squash --manifest $manifest $container $name
    or exit
else
    buildah commit --rm --squash $container $name
    or exit
end
