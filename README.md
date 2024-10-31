# RDS_dumpNrun

Dump a MySQL RDS database into a Docker container that can be ran for local dev

## Installation

### Prerequisites

-   [Docker](https://docs.docker.com/get-docker/)
-   [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html)
-   Previous authentication with AWS CLI and setup to access the RDS instance
-   `.env` file with the following variables:
    -   `DB_HOST`
    -   `DB_USER`
    -   `DB_PASS`
    -   `DB_NAME`
    -   `MYSQL_ROOT_PASSWORD`

Clone the repo and `chmod +x dump-n-run.sh`

### Build-N(or)-Run

Instructions can be found with `./dump-n-run.sh --help` .

You can either build the image with no cache to make sure the latest dump is fetched or just run the container with the latest image from Docker Hub.

You can also run only a pre-built image without the build step.

A default image and container name is provided, but you can change it with the `-i --image-name` and `-c --container-name` flags.

**Build-n-run Examples**

```bash
# To build with no-cache and run the container
./dump-n-run.sh -i mylocalsql-image -c mylocalsql-cont --no-cache-build

# If you want to run that container again
./dump-n-run.sh -c mylocalsql-cont --run-only
```

`no-cache-build` flag is used when you want the latest dump of your db, otherwise the layer is cached and not rebuilt when building the container.

At the end of the execution, you have the MySQL server running locally at port localhost:3306! But we are not finished...

**Database use**

Now, we have only dumped the MySQL database and ran the MySQL server locally. We still need to use the database if we want to access it.

```bash
# Access the container
docker exec -it mylocalsql-cont /bin/bash

# Then inside run mysql as root. We have the MYSQL_ROOT_PASSWORD ENV already there!
mysql -p$MYSQL_ROOT_PASSWORD

# Now we can use the database
mysql> show databases;
mysql> use mydbname;

# Now we can exec the interactive mode
mysql> exit
exit
```

**Logging**

general_log is enabled by default in the container. You can check the logs with the following command:

There is a oneliner convience script avail at `/root/follow-logs.sh` that is already chmoded +x. When you exec into the container, you can run this script to follow the logs.

```bash
docker exec -it mylocalsql-cont /bin/bash /root/follow-logs.sh
```

Don't forget to stop the container when your done.
