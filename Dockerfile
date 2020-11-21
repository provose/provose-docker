FROM ubuntu:focal-20201008

ARG DEBIAN_FRONTEND=noninteractive

WORKDIR /mnt

RUN apt-get update \
    && apt-get install -y \
        ca-certificates \
        openssh-client \
        unzip \
        wget \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN addgroup --gid 1000 provose \
    && adduser \
        --uid 1000 \
        --ingroup provose \
        --home /home/provose \
        --shell /bin/bash \
        --disabled-password \
        --gecos "" \
        provose

# Install fixuid
RUN wget --quiet --output-document=fixuid.tar.gz https://github.com/boxboat/fixuid/releases/download/v0.5/fixuid-0.5-linux-amd64.tar.gz \
    && tar xvf fixuid.tar.gz \
    && mv fixuid /bin \
    && rm fixuid.tar.gz \
    && mkdir -p /etc/fixuid \
    && printf "user: provose\ngroup: provose\n" > /etc/fixuid/config.yml

# Install the Tini init system
RUN wget --quiet --output-document=/bin/tini https://github.com/krallin/tini/releases/download/v0.19.0/tini-static \
    && chmod +x /bin/tini

# Install HashiCorp Terraform
RUN wget --quiet --output-document=terraform.zip https://releases.hashicorp.com/terraform/0.13.5/terraform_0.13.5_linux_amd64.zip \
    && unzip -qq terraform.zip \
    && mv terraform /bin \
    && rm terraform.zip

# Install HashiCorp Packer
RUN wget --quiet --output-document=packer.zip https://releases.hashicorp.com/packer/1.6.5/packer_1.6.5_linux_amd64.zip \
    && unzip -qq packer.zip \
    && mv packer /bin \
    && rm packer.zip

# Install the AWS CLI v2
RUN wget --quiet --output-document=aws.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip \
    && unzip -qq aws.zip \
    && ./aws/install -i /usr/local/aws-cli -b /bin \
    && rm -rf aws aws.zip

# Install Docker
RUN wget --quiet --output-document=docker-cli.deb https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/amd64/docker-ce-cli_19.03.13~3-0~ubuntu-focal_amd64.deb \
    && dpkg -i docker-cli.deb \
    && rm docker-cli.deb

# Install docker-compose
RUN wget --quiet --output-document=docker-compose https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-x86_64 \
    && chmod +x docker-compose \
    && mv docker-compose /bin

ADD entrypoint.sh /bin
RUN chmod +x /bin/entrypoint.sh
ENTRYPOINT [ "/bin/entrypoint.sh" ]

USER provose
