FROM registry.fedoraproject.org/fedora-minimal:latest

RUN microdnf install -y openssh-server passwd shadow-utils --nodocs --setopt install_weak_deps=0
RUN microdnf clean all -y
RUN echo "LogLevel DEBUG2" > /etc/ssh/sshd_config.d/99-clion.conf
RUN echo "PermitRootLogin yes" >> /etc/ssh/sshd_config.d/99-clion.conf
RUN echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config.d/99-clion.conf
RUN echo "PermitEmptyPasswords yes" >> /etc/ssh/sshd_config.d/99-clion.conf
# RUN echo "Subsystem sftp /usr/lib/openssh/sftp-server" >> /etc/ssh/sshd_config.d/99-clion.conf
RUN mkdir /run/sshd
RUN ssh-keygen -A
RUN useradd -ms /bin/bash user
RUN echo password | passwd --stdin user

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]
