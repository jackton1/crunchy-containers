#!/bin/bash
# Copyright 2016 - 2019 Crunchy Data Solutions, Inc.
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

source ${CCPROOT}/examples/common.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo_info "Cleaning up.."

cleanup "${CCP_NAMESPACE?}-pgbasebackup-pitr-restored"
cleanup "${CCP_NAMESPACE?}-restore-pitr"

dir_check_rm "restore-pitr"
create_storage "restore-pitr"
if [[ $? -ne 0 ]]
then
    echo_err "Failed to create storage, exiting.."
    exit 1
fi

expenv -f $DIR/restore-pitr.json | ${CCP_CLI?} create --namespace=${CCP_NAMESPACE?} -f -