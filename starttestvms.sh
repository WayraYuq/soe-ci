#!/bin/bash

# Instruct Foreman to start the test VMs (just in case they are off)
#
# e.g ${WORKSPACE}/scripts/starttestvms.sh 'test'
#
# this will tell Foreman to rebuild all machines in hostgroup TESTVM_HOSTGROUP

# Load common parameter variables
. $(dirname "${0}")/common.sh

if [[ -z ${PUSH_USER} ]] || [[ -z ${SATELLITE} ]]  || [[ -z ${RSA_ID} ]] \
   || [[ -z ${ORG} ]] || [[ -z ${TESTVM_HOSTCOLLECTION} ]]
then
    err "Environment variable PUSH_USER, SATELLITE, RSA_ID, ORG " \
        "or TESTVM_HOSTCOLLECTION not set or not found."
    exit ${WORKSPACE_ERR}
fi

get_test_vm_list # populate TEST_VM_LIST

# TODO: Error out if no test VM's are available.
if [ $(echo ${#TEST_VM_LIST[@]}) -eq 0 ]; then
  err "No test VMs configured in Satellite"
fi

# rebuild test VMs
for I in "${TEST_VM_LIST[@]}"
do
    inform "Making sure VM ID $I is on"

    _PROBED_STATUS=$(ssh -q -l ${PUSH_USER} -i ${RSA_ID} ${SATELLITE} "hammer host status --id $I" | grep Power | cut -f2 -d: | tr -d ' ')

    # different hypervisors report power status with different words. parse and get a single word per status
    # KVM uses running / shutoff
    # VMware uses poweredOn / poweredOff
    # add other hypervisors as you come across them and please submit to https://github.com/RedHatEMEA/soe-ci

    case "${_PROBED_STATUS}" in
      running)
        _STATUS=On
        ;;
      poweredOn)
        _STATUS=On
        ;;
      up)
        _STATUS=On
        ;;
      shutoff)
        _STATUS=Off
        ;;
      poweredOff)
        _STATUS=Off
        ;;
      down)
        _STATUS=Off
        ;;
      off)
        _STATUS=Off
        ;;
      *)
        echo "can not parse power status, please review $0"
    esac

    if [[ ${_STATUS} == 'On' ]]
    then
        inform "Host $I is already on."
    elif [[ ${_STATUS} == 'Off' ]]
    then
        inform "Host $I is already off, switching it on."
        ssh -q -l ${PUSH_USER} -i ${RSA_ID} ${SATELLITE} \
            "hammer host start --id $I"
    else
        err "Host $I is neither running nor shutoff. No action possible!"
        # exit 0 while testingi for issue  #50,
        # allows for manual rebooting of the test VM(s)
        exit 0
    fi
done
