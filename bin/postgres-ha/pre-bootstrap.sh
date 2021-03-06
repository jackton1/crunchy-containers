#!/bin/bash

# Copyright 2019 - 2020 Crunchy Data Solutions, Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

export PGHOST="/tmp"

source /opt/cpm/bin/common_lib.sh

echo_info "postgres-ha pre-bootstrap starting..."

# Set defaults for the various auto-configuration options that can be enabled/disabled
set_default_pgha_autoconfig_env()  {

    if [[ ! -v PGHA_DEFAULT_CONFIG ]]
    then
        export PGHA_DEFAULT_CONFIG="true"
        default_pgha_autoconfig_env_vars+=("PGHA_DEFAULT_CONFIG")
    fi

    if [[ ! -v PGHA_BASE_BOOTSTRAP_CONFIG ]]
    then
        export PGHA_BASE_BOOTSTRAP_CONFIG="true"
        default_pgha_autoconfig_env_vars+=("PGHA_BASE_BOOTSTRAP_CONFIG")
    fi

    if [[ ! -v PGHA_BASE_PG_CONFIG ]]
    then
        export PGHA_BASE_PG_CONFIG="true"
        default_pgha_autoconfig_env_vars+=("PGHA_BASE_PG_CONFIG")
    fi

    if [[ ! -v PGHA_ENABLE_WALDIR ]]
    then
        export PGHA_ENABLE_WALDIR="false"
        default_pgha_autoconfig_env_vars+=("PGHA_ENABLE_WALDIR")
    fi

    if [[ ! -v PGHA_PGBACKREST ]]
    then
        export PGHA_PGBACKREST="true"
        default_pgha_autoconfig_env_vars+=("PGHA_PGBACKREST")
        if [[ ! -v PGHA_PGBACKREST_LOCAL_S3_STORAGE ]]
        then
            export PGHA_PGBACKREST_LOCAL_S3_STORAGE="false"
            default_pgha_autoconfig_env_vars+=("PGHA_PGBACKREST_LOCAL_S3_STORAGE")
        fi
        if [[ ! -v PGHA_PGBACKREST_INITIALIZE ]]
        then
            export PGHA_PGBACKREST_INITIALIZE="false"
            default_pgha_autoconfig_env_vars+=("PGHA_PGBACKREST_INITIALIZE")
        fi
    else
        echo_info "pgBackRest auto-config disabled"
        echo_info "PGHA_PGBACKREST_LOCAL_S3_STORAGE and PGHA_PGBACKREST_INITIALIZE will be ignored if provided"
    fi

    if [[ ! -v PGHA_CRUNCHYADM ]]
    then
        export PGHA_CRUNCHYADM="false"
        default_pgha_autoconfig_env_vars+=("PGHA_CRUNCHYADM")
    fi

    if [[ ! -v PGHA_SYNC_REPLICATION ]]
    then
        export PGHA_SYNC_REPLICATION="false"
        default_pgha_autoconfig_env_vars+=("PGHA_SYNC_REPLICATION")
    fi

    if [[ ! ${#default_pgha_autoconfig_env_vars[@]} -eq 0 ]]
    then
        pgha_autoconfig_env_vars=$(printf ', %s' "${default_pgha_autoconfig_env_vars[@]}")
        echo_info "Defaults have been set for the following postgres-ha auto-configuration env vars: ${pgha_autoconfig_env_vars:2}"
    fi
}

# Set defaults for the custom crunchy-postgres-ha env vars required to bootstrap a cluster
set_default_pgha_env()  {

    if [[ ! -v PGHA_PATRONI_PORT ]]
    then
        export PGHA_PATRONI_PORT="8009"
        default_pgha_env_vars+=("PGHA_PATRONI_PORT")
    fi

    if [[ ! -v PGHA_PG_PORT ]]
    then
        export PGHA_PG_PORT="5432"
        default_pgha_env_vars+=("PGHA_PG_PORT")
    fi

    if [[ ! -v PGHA_DATABASE ]]
    then
        export PGHA_DATABASE="userdb"
        default_pgha_env_vars+=("PGHA_DATABASE")
    fi

    if [[ "${PGHA_ENABLE_WALDIR}" == "true" ]]  # set PGHA_ENABLE_WALDIR to "false" if not "true"
    then
        if [[ ! -v PGHA_WALDIR ]]
        then
            export PGHA_WALDIR="/pgwal/${HOSTNAME}-wal"
            default_pgha_env_vars+=("PGHA_WALDIR")
        fi
    else
        echo_info "The use of the /pgwal directory for writing WAL is not enabled"
        echo_info "A default value will not be set for PGHA_WALDIR and any value provided for will be ignored"
    fi

    if [[ ! -v PGHA_REPLICA_REINIT_ON_START_FAIL ]]
    then
        export PGHA_REPLICA_REINIT_ON_START_FAIL="true"
        pgha_env_vars+=("PGHA_REPLICA_REINIT_ON_START_FAIL")
    fi

    if [[ ! ${#default_pgha_env_vars[@]} -eq 0 ]]
    then
        pgha_env_vars=$(printf ', %s' "${default_pgha_env_vars[@]}")
        echo_info "Defaults have been set for the following postgres-ha env vars: ${pgha_env_vars:2}"
    fi
}

# Set default Patroni environment variables
set_default_patroni_env() {

    host_ip=$(hostname -i)

    if [[ ! -v PATRONI_NAME ]]
    then
        export PATRONI_NAME="${HOSTNAME}"
        default_patroni_env_vars+=("PATRONI_NAME")
    fi

    if [[ ! -v PATRONI_SCOPE ]]
    then
        export PATRONI_SCOPE="example-cluster"
        default_patroni_env_vars+=("PATRONI_SCOPE")
    fi

    if [[ ! -v PATRONI_RESTAPI_LISTEN ]]
    then
        export PATRONI_RESTAPI_LISTEN="0.0.0.0:${PGHA_PATRONI_PORT}"
        default_patroni_env_vars+=("PATRONI_RESTAPI_LISTEN")
    fi

    if [[ ! -v PATRONI_RESTAPI_CONNECT_ADDRESS ]]
    then
        export PATRONI_RESTAPI_CONNECT_ADDRESS="${host_ip}:${PGHA_PATRONI_PORT}"
        default_patroni_env_vars+=("PATRONI_RESTAPI_CONNECT_ADDRESS")
    fi

    if [[ ! -v PATRONI_POSTGRESQL_LISTEN ]]
    then
        export PATRONI_POSTGRESQL_LISTEN="0.0.0.0:${PGHA_PG_PORT}"
        default_patroni_env_vars+=("PATRONI_POSTGRESQL_LISTEN")
    fi

    if [[ ! -v PATRONI_POSTGRESQL_CONNECT_ADDRESS ]]
    then
        export PATRONI_POSTGRESQL_CONNECT_ADDRESS="${host_ip}:${PGHA_PG_PORT}"
        default_patroni_env_vars+=("PATRONI_POSTGRESQL_CONNECT_ADDRESS")
    fi

    if [[ ! -v PATRONI_POSTGRESQL_DATA_DIR ]]
    then
        export PATRONI_POSTGRESQL_DATA_DIR="/pgdata/${HOSTNAME}"
        default_patroni_env_vars+=("PATRONI_POSTGRESQL_DATA_DIR")
    fi

    if [[ ! ${#default_patroni_env_vars[@]} -eq 0 ]]
    then
        pgha_env_vars=$(printf ', %s' "${default_patroni_env_vars[@]}")
        echo_info "Defaults have been set for the following Patroni env vars: ${pgha_env_vars:2}"
    fi
}

# Set the PG user credentials for Patroni & post-bootstrap using the file system (e.g. Kube secrets)
set_pg_user_credentials() {
    echo_info "Setting postgres-ha configuration for database user credentials"

    if [[ -d "/pgconf/pguser" ]]
    then
	    echo_info "Setting 'pguser' credentials using file system"

	    PGHA_USER=$(cat /pgconf/pguser/username)
        err_check "$?" "Set postgres-ha user" "Unable to set PGHA_USER using secret"
	    export PGHA_USER

        PGHA_USER_PASSWORD=$(cat /pgconf/pguser/password)
        err_check "$?" "Set postgres-ha user password" "Unable to set PGHA_USER_PASSWORD using secret"
        export PGHA_USER_PASSWORD
    else
        env_check_err "PGHA_USER"
        env_check_err "PGHA_USER_PASSWORD"
    fi

    if [[ -d "/pgconf/pgsuper" ]]
    then
        echo_info "Setting 'superuser' credentials using file system"

        PATRONI_SUPERUSER_USERNAME=$(cat /pgconf/pgsuper/username)
        err_check "$?" "Set superuser" "Unable to set PGHA_USER_PASSWORD using secret"
        export PATRONI_SUPERUSER_USERNAME

        PATRONI_SUPERUSER_PASSWORD=$(cat /pgconf/pgsuper/password)
        err_check "$?" "Set superuser password" "Unable to set PGHA_USER_PASSWORD using secret"
        export PATRONI_SUPERUSER_PASSWORD
    else
        env_check_err "PATRONI_SUPERUSER_USERNAME"
        env_check_err "PATRONI_SUPERUSER_PASSWORD"
    fi

    if [[ -d "/pgconf/pgreplicator" ]]
    then
        echo_info "Setting 'replicator' credentials using file system"

        # Configure certificate-based authentication for replication if proper certs are available.
        # Otherwise use a password
        if [[ -f "/pgconf/replicator.key" ]] && [[ -f "/pgconf/replicator.crt" ]]
        then
            export PATRONI_REPLICATION_SSLKEY="${PATRONI_POSTGRESQL_DATA_DIR}/replicator.key"
            export PATRONI_REPLICATION_SSLCERT="${PATRONI_POSTGRESQL_DATA_DIR}/replicator.crt"
        else
            PATRONI_REPLICATION_PASSWORD=$(cat /pgconf/pgreplicator/password)
            err_check "$?" "Set replication user password" "Unable to set PATRONI_REPLICATION_PASSWORD using secret"
            export PATRONI_REPLICATION_PASSWORD
        fi

        # set the server CA for the replication user if present
        if [[ -f "${PATRONI_POSTGRESQL_DATA_DIR}/ca.crt" ]]
        then
            export PATRONI_REPLICATION_SSLROOTCERT="${PATRONI_POSTGRESQL_DATA_DIR}/ca.crt"
        fi
        # set the CRL for the replication user if present
        if [[ -f "${PATRONI_POSTGRESQL_DATA_DIR}/replicator.crl" ]]
        then
            export PATRONI_REPLICATION_SSLCRL="${PATRONI_POSTGRESQL_DATA_DIR}/replicator.crl"
        fi

        PATRONI_REPLICATION_USERNAME=$(cat /pgconf/pgreplicator/username)
        err_check "$?" "Set replication user" "Unable to set PATRONI_REPLICATION_USERNAME using secret"
        export PATRONI_REPLICATION_USERNAME
    else
        env_check_err "PATRONI_REPLICATION_USERNAME"
        env_check_err "PATRONI_REPLICATION_PASSWORD"
    fi
}

# Validate environment variables
validate_env() {
    if [[ "${PATRONI_POSTGRESQL_DATA_DIR}" == "/pgdata" || "${PATRONI_POSTGRESQL_DATA_DIR}" == "/pgdata/"
        || ! "${PATRONI_POSTGRESQL_DATA_DIR:0:8}" == "/pgdata/" ]]
    then
        echo_err "The PGDATA directory provided using PATRONI_POSTGRESQL_DATA_DIR must be a subdirectory of volume /pgdata"
        exit 1
    fi
    if [[ "${PGHA_ENABLE_WALDIR}" == "true" ]]
    then
        if [[ "${PGHA_WALDIR}" == "/pgwal" || "${PGHA_WALDIR}" == "/pgwal/" || ! "${PGHA_WALDIR:0:7}" == "/pgwal/" ]]
        then
            echo_err "PGHA_WALDIR must be a subdirectory of volume /pgwal.  Directory ${PGHA_WALDIR} provided"
            exit 1
        fi
    fi
}

# Build the Patroni bootstrap configuration file
build_bootstrap_config_file() {

    bootstrap_file="/tmp/postgres-ha-bootstrap.yaml"
    echo "---" >> "${bootstrap_file}"

    if [[ -f "/pgconf/postgresql.conf" ]]
    then
        echo_info "Setting custom 'postgresql.conf' as base config using 'custom_conf'"
        /opt/cpm/bin/yq m -i -x "${bootstrap_file}" "/opt/cpm/conf/postgres-ha-custom-pgconf.yaml"
    fi

    if [[ "${PGHA_BASE_BOOTSTRAP_CONFIG}" == "true" ]]
    then
        echo_info "Applying base bootstrap config to postgres-ha configuration"
        /opt/cpm/bin/yq m -i -x "${bootstrap_file}" "/opt/cpm/conf/postgres-ha-bootstrap.yaml"
    else
        echo_info "Base bootstrap config for postgres-ha configuration disabled"
    fi

    if [[ "${PGHA_BASE_PG_CONFIG}" == "true" ]]
    then
        cp "/opt/cpm/conf/postgres-ha-pgconf.yaml" "/tmp"
        sed -i "s/PGHA_USER/$PGHA_USER/g" "/tmp/postgres-ha-pgconf.yaml"
        sed -i "s/PATRONI_REPLICATION_USERNAME/$PATRONI_REPLICATION_USERNAME/g" "/tmp/postgres-ha-pgconf.yaml"
        echo_info "Applying base postgres config to postgres-ha configuration"
        /opt/cpm/bin/yq m -i -x "${bootstrap_file}" "/tmp/postgres-ha-pgconf.yaml"
    else
        echo_info "Base PG config for postgres-ha configuration disabled"
    fi

    if [[ "${PGHA_ENABLE_WALDIR}" == "true" ]]
    then
        cp "/opt/cpm/conf/postgres-ha-waldir.yaml" "/tmp"
        sed -i "s/PGHA_WALDIR/${PGHA_WALDIR//\//\\/}/g" "/tmp/postgres-ha-waldir.yaml"
        echo_info "Applying custom WAL dir to postgres-ha configuration"
        # append when merging initdb contents for WAL dir instead of overwriting
        /opt/cpm/bin/yq m -i -a "${bootstrap_file}" "/tmp/postgres-ha-waldir.yaml"
    else
        echo_info "Default WAL directory will be utilized.  Any value provided for PGHA_WALDIR will be ignored"
    fi

    if [[ "${PGHA_PGBACKREST}" == "true" ]]
    then
        echo_info "Applying pgbackrest config to postgres-ha configuration"
        /opt/cpm/bin/yq m -i -x "${bootstrap_file}" "/opt/cpm/conf/postgres-ha-pgbackrest.yaml"
        if [[ "${PGHA_PGBACKREST_LOCAL_S3_STORAGE}" == "true" ]]
        then
            /opt/cpm/bin/yq m -i -x "${bootstrap_file}" "/opt/cpm/conf/postgres-ha-pgbackrest-local-s3.yaml"
        fi
    else
        echo_info "pgBackRest config for postgres-ha configuration disabled"
    fi

    if [[ "${PGHA_INIT}" == "true" ]]
    then
        echo_info "PGDATA directory is empty on node identifed as Primary"
        echo_info "initdb configuration will be applied to intitilize a new database"
        /opt/cpm/bin/yq m -i -x "${bootstrap_file}" "/opt/cpm/conf/postgres-ha-initdb.yaml"
    fi

    if [[ "${PGHA_SYNC_REPLICATION}" == "true" ]]
    then
        echo_info "Applying synchronous replication settings to postgres-ha configuration"
        /opt/cpm/bin/yq m -i -x "${bootstrap_file}" "/opt/cpm/conf/postgres-ha-sync.yaml"
    fi

    if [[ -f "/pgconf/postgres-ha.yaml" ]]
    then
        echo_info "Applying custom postgres-ha configuration file"
        /opt/cpm/bin/yq m -i -x "${bootstrap_file}" "/pgconf/postgres-ha.yaml"
    else
        echo_info "Custom postgres-ha configuration file not detected"
    fi

    if [[ $(cat "${bootstrap_file}") == "---" ]]
    then
        echo_err "postgres-ha configuration file is empty! Please provide a custom config file or enable the base configs."
        exit 1
    else
        echo_info "Finished building postgres-ha configuration file '${bootstrap_file}'"
    fi
}

# Set and logs defaults for postgres-ha (PGHA) env vars
set_default_pgha_autoconfig_env
set_default_pgha_env
pgha_print_env=$(env | grep "^PGHA_")

# Set and log defaults for Patroni env vars (if default config is enabled)
if [[ "${PGHA_DEFAULT_CONFIG}" == "true" ]]
then
    env_check_err "PGHA_PATRONI_PORT"
    env_check_err "PGHA_PG_PORT"
    env_check_err "PGHA_DATABASE"
    set_default_patroni_env
else
    echo_info "Defaults will not be set for Patroni environment variables"
fi
patroni_print_env=$(env | grep "^PATRONI_")  # capture Patroni env prior to setting credentials to them keep out of logs

# Set user credentials using the file system (e.g. Kube secrets) if provided
set_pg_user_credentials

# Perform any additional validation of env vars required
validate_env

# Create the Patroni bootstrap configuration file
build_bootstrap_config_file

# Create the pgdata directory if it doesn't exist
mkdir -p "${PATRONI_POSTGRESQL_DATA_DIR}"
chmod 0700 "${PATRONI_POSTGRESQL_DATA_DIR}"

# If a list of tablespaces has been passed in, create these names in the
#tablespace directory, which are in the format:
#
# tablespace1,tablespace2
IFS=',' read -r -a TABLESPACES <<< "${PGHA_TABLESPACES}"
# Next, iterate through the list, especially if any tablespaces were found
for TABLESPACE in "${TABLESPACES[@]}"
do
  TABLESPACE_PATH="/tablespaces/${TABLESPACE}/${TABLESPACE}"
  echo_info "create directory for tablespace \"${TABLESPACE}\" on mount point \"${TABLESPACE_PATH}\""
  # create the folder that the tablespace will be mounted to as well as set its
  # permissions correctly. This has to go "two deep" in order to account for
  # the direcory structure of the mounted file system
  mkdir -p "${TABLESPACE_PATH}"
  chmod 0700 "${TABLESPACE_PATH}"
done

echo_info "postgres-ha pre-bootstrap complete!  The following configuration will be utilized to initialize " \
"this postgres-ha node:"
echo "******************************"
echo "postgres-ha (PGHA) env vars:"
echo "******************************"
echo "${pgha_print_env}"
echo "******************************"
echo "Patroni env vars:"
echo "******************************"
echo "${patroni_print_env}"
echo "******************************"
echo "Patroni configuration file:"
echo "******************************"
cat ${bootstrap_file}
