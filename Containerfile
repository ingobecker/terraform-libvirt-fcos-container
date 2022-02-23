FROM fedora:35 as download

ARG TF_VERSION=1.1.6
ARG TF_DOWNLOAD_URL=https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}

RUN dnf -y --setopt=tsflags=nodocs install curl gpg unzip
RUN useradd -ms /bin/bash deploy
WORKDIR /home/deploy
USER deploy

COPY keys/hashicorp.asc .
RUN for FILE in linux_amd64.zip SHA256SUMS SHA256SUMS.sig ;\
    do \
      curl -s -O -L ${TF_DOWNLOAD_URL}_${FILE} ;\
    done
RUN GNUPGHOME=$(mktemp -d $HOME/.gnupgXXXXXX) && \
	export GNUPGHOME && \
	gpg --import hashicorp.asc && \
	gpg --verify terraform_${TF_VERSION}_SHA256SUMS.sig terraform_${TF_VERSION}_SHA256SUMS && \
	sha256sum -c terraform_${TF_VERSION}_SHA256SUMS 2>&1 | grep OK && \
	unzip terraform_${TF_VERSION}_linux_amd64.zip

USER root
RUN mv terraform /usr/local/bin/terraform

FROM fedora:35 as deploy

RUN dnf -y --setopt=tsflags=nodocs install ca-certificates \
      libvirt-libs \
      genisoimage \
      libvirt-client \
      fcct \
      jq \
      coreos-installer \
      bash-completion && \
    dnf clean all
COPY --from=download /usr/local/bin/terraform /usr/local/bin/

RUN useradd -ms /bin/bash deploy

WORKDIR /home/deploy
USER deploy

RUN terraform -install-autocomplete
WORKDIR /home/deploy/src
ENV LIBVIRT_DEFAULT_URI="qemu:///system"
LABEL SHELL="podman run \
  --rm \
  -it \
  --name=terraform-libvirt \
  --hostname=terraform-libvirt \
  --userns=keep-id \
  --net=slirp4netns:enable_ipv6=true \
  --security-opt label=type:terraform_libvirt_container.process \
  -v /var/run/libvirt/libvirt-sock:/var/run/libvirt/libvirt-sock \
  -v .:/home/deploy/src:Z \
  -e LANG=C.UTF-8 \
  IMAGE bash"
