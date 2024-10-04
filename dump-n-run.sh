#! /usr/bin/bash

# Helper to print help
function print_help() {
    echo "Usage: $(basename $0) -i <image-name> -c <container-name> [--run-only] [--no-cache-build]"
    echo
    echo "Options:"
    echo "  -i, --image-name       Name of the Docker image. Defaults to localmysql-dumpnrun"
    echo "  -c, --container-name   Name of the Docker container. Defaults to localmysql-dumpnrun-container"
    echo "      --run-only         Only run the container without building"
    echo "      --no-cache-build   Build the Docker image without using cache"
    echo "  -h, --help             Display this help message"
    exit 0
}

# Helper for aws-cli installation and configuration
function validate_aws_and_auth() {
    # Check installation
    if ! command -v aws > /dev/null 2>&1 ; then
        echo "aws-cli is not installed: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    # Check version
    AWS_MAJ_V=$(aws --version | cut -d / -f2 | awk '{ print $1 }' | cut -b 1
    )
    if [[ $AWS_MAJ_V -ne '2' ]]; then
        echo "You need aws-cli v2. You are running $(aws --version)"
        exit 1
    fi

    # Run aws configure
        while true; do
            echo "Running aws configure. Press Ctrl+C to exit."
            aws configure
            if [[ $? -eq 0 ]]; then
                echo "AWS configuration successful."
                break
            else
                echo "AWS configuration failed. Do you want to try again? (y/n)"
                read -r answer
                if [[ "$answer" != "y" ]]; then
                    echo "Exiting."
                    exit 1
                fi
            fi
        done
}

# Helper to check if container is already running
function check_remove_container() {
    if [[ $(docker ps -a --format '{{.Names}}' | grep -w $CONTAINER_NAME) ]]; then
            echo "Container $CONTAINER_NAME already exists. Stopping and removing it."
            docker stop $CONTAINER_NAME
            echo "Container $CONTAINER_NAME stopped."

            docker rm $CONTAINER_NAME
            echo "Container $CONTAINER_NAME removed."
        fi
}

# Need the following args: IMAGE_NAME, CONTAINER_NAME and weither to only build and/or run the container
VALID_ARGS=$(getopt -o i:c:h: --long image-name:,container-name:,run-only,no-cache-build,help -- "$@")
# Print help if the arguments are invalid
if [ $? -ne 0 ]; then
    print_help
    exit
fi
eval set -- "$VALID_ARGS"

# Extract the arguments

while true; do
    case "$1" in
        -i|--image-name)
            IMAGE_NAME=$2
            shift 2
            ;;
        -c|--container-name)
            CONTAINER_NAME=$2
            shift 2
            ;;
        --run-only)
            RUN_ONLY=true
            shift
            ;;
        --no-cache-build)
            NO_CACHE_BUILD=true
            shift
            ;;
        -h|--help)
            print_help
            ;;
        --)
            shift
            break
            ;;
    esac
done

# Set default values if not provided
if [[ -z $IMAGE_NAME ]]; then
    echo "No image name provided. Using default: localmysql-dumpnrun"
fi
IMAGE_NAME=${IMAGE_NAME:-localmysql-dumpnrun}

if [[ -z $CONTAINER_NAME ]]; then
    echo "No container name provided. Using default: localmysql-dumpnrun-container"
fi
CONTAINER_NAME=${CONTAINER_NAME:-localmysql-dumpnrun-container}

# Get the credentials to pass to docker build
if [[ ! -f .env ]]; then
    echo "No .env file found. Please create one with the following keys: DB_HOST, DB_USERNAME, DB_PASSWORD, DB_NAME, MYSQL_ROOT_PASSWORD"
    exit 1
fi

# Source it
source .env
echo -e "Got credentials from .env!\n"

# Run the container if flag set
if [[ $RUN_ONLY ]]; then
    check_remove_container
    echo -e "\nRunning the container $CONTAINER_NAME with the image $IMAGE_NAME..."
    docker run --name "$CONTAINER_NAME" -d -p 3306:3306 $IMAGE_NAME
    exit 0
fi

# Validate aws credentials
AWS_CREDENTIALS=$HOME/.aws/credentials
if [[ -z $AWS_CREDENTIALS ]]; then
    echo "AWS_CREDENTIALS are not found."
    echo "Let's try to auth with aws-cli to have credentials in \$HOME/.aws/credentials"
    validate_aws_and_auth
else
    echo "Found aws credentials! Proceeding to build"
fi;


# Build the docker image with the secret aws layer and .env secrets
export DB_HOST=$DB_HOST
export DB_PASSWORD=$DB_PASSWORD
export DB_USERNAME=$DB_USERNAME
export DB_NAME=$DB_NAME

if [[ $NO_CACHE_BUILD ]]; then
    docker build --secret id=aws,src="$AWS_CREDENTIALS" \
    --secret id=db-host,env=DB_HOST \
    --secret id=db-password,env=DB_PASSWORD \
    --secret id=db-username,env=DB_USERNAME \
    --secret id=db-name,env=DB_NAME \
    --build-arg MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
    --no-cache -t $IMAGE_NAME .
    exit 0
else
    docker build --secret id=aws,src="$AWS_CREDENTIALS" \
        --secret id=db-host,env=DB_HOST \
        --secret id=db-password,env=DB_PASSWORD \
        --secret id=db-username,env=DB_USERNAME \
        --secret id=db-name,env=DB_NAME \
        --build-arg MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD \
        -t $IMAGE_NAME .
fi

# Check if the container already
check_remove_container
echo -e "\nRunning the container $CONTAINER_NAME with the image $IMAGE_NAME..."
docker run --name "$CONTAINER_NAME" -d -p 3306:3306 $IMAGE_NAME
