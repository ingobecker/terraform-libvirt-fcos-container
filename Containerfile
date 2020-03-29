FROM fedora:31 as download

ARG TF_VERSION=0.12.24
ARG TF_DOWNLOAD_URL=https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}

ARG TF_LIBVIR_VERSION=0.6.1
ARG TF_LIBVIR_URL=https://github.com/dmacvicar/terraform-provider-libvirt/releases/download/v${TF_LIBVIR_VERSION}
ARG TF_LIBVIRT_COMMIT=1578064534.db13b678

ARG TF_CT_VERSION=v0.4.0
ARG TF_CT_URL=https://github.com/poseidon/terraform-provider-ct/releases/download/${TF_CT_VERSION}/terraform-provider-ct-${TF_CT_VERSION}-linux-amd64.tar.gz

RUN dnf -y --setopt=tsflags=nodocs install curl gpg unzip
RUN useradd -ms /bin/bash deploy
WORKDIR /home/deploy
USER deploy

COPY keys/hashicorp.asc keys/dmacvicar.asc keys/dghubble.asc .
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

RUN curl -s -O -L ${TF_LIBVIR_URL}/terraform-provider-libvirt-${TF_LIBVIR_VERSION}+git.${TF_LIBVIRT_COMMIT}.Ubuntu_18.04.amd64.tar.gz
RUN curl -s -O -L ${TF_LIBVIR_URL}/terraform-provider-libvirt-${TF_LIBVIR_VERSION}.sha256.asc
RUN GNUPGHOME=$(mktemp -d $HOME/.gnupgXXXXXX) && \
	export GNUPGHOME && \
	gpg --import dmacvicar.asc && \
	gpg --output tflv.sha256 --decrypt terraform-provider*.sha256.asc && \
	sha256sum -c tflv.sha256 2>&1 | grep OK

RUN tar xfz *.tar.gz

RUN curl -s -O -L ${TF_CT_URL} && curl -s -O -L ${TF_CT_URL}.asc
RUN GNUPGHOME=$(mktemp -d $HOME/.gnupgXXXXXX) && \
        export GNUPGHOME && \
        gpg --import dghubble.asc && \
        gpg --verify terraform-provider-ct-${TF_CT_VERSION}-linux-amd64.tar.gz.asc terraform-provider-ct-${TF_CT_VERSION}-linux-amd64.tar.gz && \
        tar xfz terraform-provider-ct-*.tar.gz && \
	mv terraform-provider-ct-${TF_CT_VERSION}-linux-amd64/terraform-provider-ct .

USER root
RUN mv terraform /usr/local/bin/terraform

FROM fedora:31 as deploy


RUN dnf -y --setopt=tsflags=nodocs install ca-certificates \
      libvirt-libs \
      genisoimage \
      libvirt-client \
      coreos-installer && \
    dnf clean all
COPY --from=download /usr/local/bin/terraform /usr/local/bin/

RUN useradd -ms /bin/bash deploy

WORKDIR /home/deploy
USER deploy

RUN mkdir -p .terraform.d/plugins
COPY --from=download /home/deploy/terraform-provider-libvirt .terraform.d/plugins/
COPY --from=download /home/deploy/terraform-provider-ct .terraform.d/plugins/

WORKDIR /home/deploy/src
ENV LIBVIRT_DEFAULT_URI="qemu:///system"
LABEL SHELL="podman run \
  --rm \
  -it \
  --name=terraform-libvirt \
  --hostname=terraform-libvirt \
  --userns=keep-id \
  --security-opt label=type:terraform_libvirt_container.process \
  -v /var/run/libvirt/libvirt-sock:/var/run/libvirt/libvirt-sock \
  -v .:/home/deploy/src:Z \
  -e LANG=C.UTF-8 \
  IMAGE bash"
