ARG TF_LIBVIR_VERSION=0.6.3

FROM fedora:33 as download

ARG TF_VERSION=0.14.7
ARG TF_DOWNLOAD_URL=https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}

ARG TF_LIBVIR_VERSION
ARG TF_LIBVIR_URL=https://github.com/dmacvicar/terraform-provider-libvirt/releases/download/v${TF_LIBVIR_VERSION}
ARG TF_LIBVIRT_COMMIT=1604843676.67f4f2aa

RUN dnf -y --setopt=tsflags=nodocs install curl gpg unzip
RUN useradd -ms /bin/bash deploy
WORKDIR /home/deploy
USER deploy

COPY keys/hashicorp.asc keys/dmacvicar.asc .
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

RUN curl -s -O -L ${TF_LIBVIR_URL}/terraform-provider-libvirt-${TF_LIBVIR_VERSION}+git.${TF_LIBVIRT_COMMIT}.Ubuntu_20.04.amd64.tar.gz
RUN curl -s -O -L ${TF_LIBVIR_URL}/terraform-provider-libvirt-${TF_LIBVIR_VERSION}.sha256.asc
RUN GNUPGHOME=$(mktemp -d $HOME/.gnupgXXXXXX) && \
	export GNUPGHOME && \
	gpg --import dmacvicar.asc && \
	gpg --output tflv.sha256 --decrypt terraform-provider*.sha256.asc && \
	sha256sum -c tflv.sha256 2>&1 | grep OK

RUN tar xfz *.tar.gz

USER root
RUN mv terraform /usr/local/bin/terraform

FROM fedora:33 as deploy

ARG TF_LIBVIR_VERSION

RUN dnf -y --setopt=tsflags=nodocs install ca-certificates \
      libvirt-libs \
      genisoimage \
      libvirt-client \
      fcct \
      jq \
      coreos-installer && \
    dnf clean all
COPY --from=download /usr/local/bin/terraform /usr/local/bin/

RUN useradd -ms /bin/bash deploy

WORKDIR /home/deploy
USER deploy

RUN mkdir -p .terraform.d/plugins
COPY --from=download /home/deploy/terraform-provider-libvirt .terraform.d/plugins/registry.terraform.io/dmacvicar/libvirt/${TF_LIBVIR_VERSION}/linux_amd64/terraform-provider-libvirt_${TF_LIBVIR_VERSION}

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
