#!/bin/bash
# This shell script is a wrapper around the Provose Docker image.
# The image doesn't *contain* Provose--we expect the user to include it
# in their code. Instead, the image contains the dependencies that complex
# Provose workflows are likely to need.

if ! which -s docker
then
    echo "Could not find Docker installation."
    echo "You can choose to install Docker somewhere in your \$PATH"
    echo "or just use Provose directly without Docker."
    exit 1
fi

# If we are already in the Provose container, then just run the program
# without creating a child container.
if [ ${IN_PROVOSE_CONTAINER:-} ]
then
    exec bash "$@"
fi

# Mount the user's AWS credentials so that Terraform can use them.
if [ -e "${HOME}/.aws" ]
then
    echo "AWS directory exists."
    # The first mount is so that the path "~/.aws" resolves.
    # The second mount is to support any user code that hard-codes their AWS credentials path.
    PROVOSE_AWS_MOUNT_1="--mount=type=bind,source=${HOME}/.aws,target=/home/provose/.aws"
    PROVOSE_AWS_MOUNT_2="--mount=type=bind,source=${HOME}/.aws,target=${HOME}/.aws"
else
    echo "SSH directory does not exist."
    PROVOSE_AWS_MOUNT_1=""
    PROVOSE_AWS_MOUNT_2=""
fi

# Mount the user's SSH directory on the host so Provose/Terraform/Ansible/SSH can
# authenticate to servers that have the user's public keys.
if [ -e "${HOME}/.ssh" ]
then
    echo "SSH directory exists."
    # The first mount is so that the path "~/.ssh" resolves.
    # The second mount is to support any user code that hard-codes their SSH credentials path.
    PROVOSE_SSH_MOUNT_1="--mount=type=bind,source=${HOME}/.ssh,target=/home/provose/.ssh"
    PROVOSE_SSH_MOUNT_2="--mount=type=bind,source=${HOME}/.ssh,target=${HOME}/.ssh"
else
    echo "SSH directory does not exist."
    PROVOSE_SSH_MOUNT_1=""
    PROVOSE_SSH_MOUNT_2=""
fi

# Pass the host's SSH agent socket. It is an environment variable that contains a path
# that we *also* have to mount as a volume.
if [ ${SSH_AUTH_SOCK:-} ]
then
    # Docker For Mac has this "host-services" path as the SSH agent for
    # containers. This is becaues Docker For Mac (and Windows) has to run
    # a Linux virtual machine, and this is the host's SSH agent mounted in the VM.
    if [ $(uname -s) == "Darwin" ]
    then
        PROVOSE_SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock
    else
        PROVOSE_SSH_AUTH_SOCK="${SSH_AUTH_SOCK}"
    fi
    # Resolve symlinks in the Docker socket so we know exactly where we were mounting.
    PROVOSE_SSH_AUTH_SOCK_REALPATH="$(realpath -m ${PROVOSE_SSH_AUTH_SOCK})"
    PROVOSE_SSH_AUTH_SOCK_MOUNT="--mount=type=bind,source=${PROVOSE_SSH_AUTH_SOCK_REALPATH},target=${PROVOSE_SSH_AUTH_SOCK_REALPATH}"
else
    # I guess the `ssh-agent` program is not running on the host system.
    PROVOSE_SSH_AUTH_SOCK=""
    PROVOSE_SSH_AUTH_SOCK_REALPATH=""
    PROVOSE_SSH_AUTH_SOCK_MOUNT=""
fi

# Mount the Docker socket so Provose can build Docker containers and monitor Docker
# on the host system.
if [ -e "/var/run/docker.sock" ]
then
    echo "Docker mount exists."
    PROVOSE_DOCKER_SOCKET_MOUNT="--mount=type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock"
else
    echo "Docker mount does not exist."
    PROVOSE_DOCKER_SOCKET_MOUNT=""
fi

exec docker run \
    --rm \
    --interactive \
    --tty \
    --workdir="$(pwd)" \
    --mount type=bind,source="$(pwd)",target="$(pwd)" \
    $PROVOSE_SSH_MOUNT_1 \
    $PROVOSE_SSH_MOUNT_2 \
    $PROVOSE_AWS_MOUNT_1 \
    $PROVOSE_AWS_MOUNT_2 \
    $PROVOSE_DOCKER_SOCKET_MOUNT \
    --env force_color_prompt=yes \
    --env IN_PROVOSE_CONTAINER=true \
    --env SSH_AUTH_SOCK=${PROVOSE_SSH_AUTH_SOCK} \
    $PROVOSE_SSH_AUTH_SOCK_MOUNT \
    provose "$@"