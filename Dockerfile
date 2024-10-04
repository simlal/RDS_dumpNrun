FROM mysql:latest as dumper

WORKDIR /root

# Install dependencies
RUN microdnf install -y unzip less

# Install awscli
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip "awscliv2.zip" && ./aws/install

# Make the sql dump
RUN --mount=type=secret,id=aws,target=/root/.aws/credentials \
    --mount=type=secret,id=db-host,env=DB_HOST \
    --mount=type=secret,id=db-password,env=DB_PASSWORD \
    --mount=type=secret,id=db-username,env=DB_USERNAME \
    --mount=type=secret,id=db-name,env=DB_NAME \
    mysqldump --single-transaction --set-gtid-purged=OFF --databases -h "$DB_HOST" -u "$DB_USERNAME" -p"$DB_PASSWORD" "$DB_NAME" > rds_dump.sql


# Copy the dump file to a temporary location
RUN cp rds_dump.sql /tmp/rds_dump.sql

# Stage 2: Final stage
FROM mysql:latest

WORKDIR /root

# Copy the dump file from the dumper stage
COPY --from=dumper /tmp/rds_dump.sql /docker-entrypoint-initdb.d/rds_dump.sql

# Make the password accessible to runtime
ARG MYSQL_ROOT_PASSWORD
ENV MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
