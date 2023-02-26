#!/bin/bash
# ------------------------------------------------------------------------
# Copyright 2021 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Description:  Google Cloud Platform - SAP Deployment Functions
#
# Version:    2.0.2023021506521676472763
# Build Hash: cac5701db924b1e8b7edb29781b8a989573cc7e4
#
# ------------------------------------------------------------------------

## Check to see if a custom script path was provided by the template
if [[ "${1}" ]]; then
  readonly DEPLOY_URL="${1}"
else
  readonly DEPLOY_URL="https://storage.googleapis.com/cloudsapdeploy/deploymentmanager/202302150652/dm-templates"
fi

##########################################################################
## Start constants
##########################################################################
TEMPLATE_NAME="NW_HA_SCS"


##########################################################################
## Start includes
##########################################################################


set +e

main::set_boot_parameters() {
  main::errhandle_log_info 'Checking boot paramaters'

  ## disable selinux
  if [[ -e /etc/sysconfig/selinux ]]; then
    main::errhandle_log_info "--- Disabling SELinux"
    sed -ie 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
  fi

  if [[ -e /etc/selinux/config ]]; then
    main::errhandle_log_info "--- Disabling SELinux"
    sed -ie 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
  fi
  ## work around for LVM boot where LVM volues are not started on certain SLES/RHEL versions
  if [[ -e /etc/sysconfig/lvm ]]; then
    sed -ie 's/LVM_ACTIVATED_ON_DISCOVERED="disable"/LVM_ACTIVATED_ON_DISCOVERED="enable"/g' /etc/sysconfig/lvm
  fi

  ## Configure cstates and huge pages
  if ! grep -q cstate /etc/default/grub ; then
    main::errhandle_log_info "--- Update grub"
    cmdline=$(grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub | head -1 | sed 's/GRUB_CMDLINE_LINUX_DEFAULT=//g' | sed 's/\"//g')
    cp /etc/default/grub /etc/default/grub.bak
    grep -v GRUBLINE_LINUX_DEFAULT /etc/default/grub.bak >/etc/default/grub
    if [[ $LINUX_DISTRO == "RHEL" ]] && [[ $LINUX_MAJOR_VERSION -ge 8 ]] && [[ $LINUX_MINOR_VERSION -ge 4 ]]; then
      # Enable tsx explicitly - SAP note 2777782
      echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${cmdline} transparent_hugepage=never intel_idle.max_cstate=1 processor.max_cstate=1 intel_iommu=off tsx=on\"" >>/etc/default/grub
    else
      echo "GRUB_CMDLINE_LINUX_DEFAULT=\"${cmdline} transparent_hugepage=never intel_idle.max_cstate=1 processor.max_cstate=1 intel_iommu=off\"" >>/etc/default/grub
      echo "GRUB_ENABLE_LINUX_LABEL=true" >>/etc/default/grub
      echo "GRUB_DEVICE=\"LABEL=ROOT\"" >>/etc/default/grub
    fi
    grub2-mkconfig -o /boot/grub2/grub.cfg
    echo "${HOSTNAME}" >/etc/hostname
    main::errhandle_log_info '--- Parameters updated. Rebooting'
    reboot
    exit 0
  fi
}


main::errhandle_log_info() {
  local log_entry=${1}

  echo "INFO - ${log_entry}"
  if [[ -n "${GCLOUD}" ]]; then
     timeout 10 ${GCLOUD} --quiet logging write "${HOSTNAME}" "${HOSTNAME} Deployment \"${log_entry}\"" --severity=INFO
  fi
}


main::errhandle_log_warning() {
  local log_entry=${1}

  if [[ -z "${deployment_warnings}" ]]; then
    deployment_warnings=1
  else
    deployment_warnings=$((deployment_warnings +1))
  fi

  echo "WARNING - ${log_entry}"
  if [[ -n "${GCLOUD}" ]]; then
    ${GCLOUD} --quiet logging write "${HOSTNAME}" "${HOSTNAME} Deployment \"${log_entry}\"" --severity=WARNING
  fi
}


main::errhandle_log_error() {
  local log_entry=${1}

  echo "ERROR - Deployment Exited - ${log_entry}"
  if [[ -n "${GCLOUD}" ]]; then
    ${GCLOUD}	--quiet logging write "${HOSTNAME}" "${HOSTNAME} Deployment \"${log_entry}\"" --severity=ERROR
    ${GCLOUD} --quiet logging write "${HOSTNAME}" "${HOSTNAME} Deployment \"ERROR - Deployment Exited\"" --severity=ERROR
  fi


  main::complete error
}


main::get_os_version() {
  if grep SLES /etc/os-release; then
    readonly LINUX_DISTRO="SLES"
  elif grep -q "Red Hat" /etc/os-release; then
    readonly LINUX_DISTRO="RHEL"
  else
    main::errhandle_log_warning "Unsupported Linux distribution. Only SLES and RHEL are supported."
  fi
  readonly LINUX_VERSION=$(grep VERSION_ID /etc/os-release | awk -F '\"' '{ print $2 }')
  readonly LINUX_MAJOR_VERSION=$(echo $LINUX_VERSION | awk -F '.' '{ print $1 }')
  readonly LINUX_MINOR_VERSION=$(echo $LINUX_VERSION | awk -F '.' '{ print $2 }')
}


main::config_ssh() {
  ssh-keygen -m PEM -q -N "" < /dev/zero
  sed -ie 's/PermitRootLogin no/PermitRootLogin yes/g' /etc/ssh/sshd_config
  service sshd restart
  cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
  /usr/sbin/rcgoogle-accounts-daemon restart ||  /usr/sbin/rcgoogle-guest-agent restart
}


main::install_ssh_key(){
  local host=${1}
  local host_zone

  host_zone=$(${GCLOUD} compute instances list --filter="name=('${host}')" --format "value(zone)")
  main::errhandle_log_info "Installing ${HOSTNAME} SSH key on ${host}"

  local count=0
  local max_count=10

  while ! ${GCLOUD} --quiet compute instances add-metadata "${host}" --metadata "ssh-keys=root:$(cat ~/.ssh/id_rsa.pub)" --zone "${host_zone}"; do
    count=$((count +1))
    if [ ${count} -gt ${max_count} ]; then
      main::errhandle_log_error "Failed to install ${HOSTNAME} SSH key on ${host}, aborting installation."
    else
      main::errhandle_log_info "Failed to install ${HOSTNAME} SSH key on ${host}, trying again in 5 seconds."
      sleep 5s
    fi
  done
}


main::install_packages() {
  main::errhandle_log_info 'Installing required operating system packages'

  ## SuSE work around to avoid a startup race condition
  if [[ ${LINUX_DISTRO} = "SLES" ]]; then
    local count=0

    ## check if SuSE repos are registered
    while [[ $(find /etc/zypp/repos.d/ -maxdepth 1 | wc -l) -lt 2 ]]; do
      main::errhandle_log_info "--- SuSE repositories are not registered. Waiting 60 seconds before trying again"
      sleep 60s
      count=$((count +1))
      if [ ${count} -gt 30 ]; then
        main::errhandle_log_error "SuSE repositories didn't register within an acceptable time. If you are using BYOS, ensure you login to the system and apply the SuSE license within 30 minutes after deployment. If you are using a VM without external IP make sure you set up a NAT gateway to provide internet access."
      fi
    done
    sleep 10s

    ## check if zypper is still running
    while pgrep zypper; do
      errhandle_log_info "--- zypper is still running. Waiting 10 seconds before attempting to continue"
      sleep 10s
    done
  fi

  ## packages to install
  local sles_packages="libssh2-1 libopenssl0_9_8 libopenssl1_0_0 tuned krb5-32bit unrar SAPHanaSR SAPHanaSR-doc pacemaker numactl csh python-pip python-pyasn1-modules ndctl python-oauth2client python-oauth2client-gce python-httplib2 python3-httplib2 python3-google-api-python-client python-requests python-google-api-python-client libgcc_s1 libstdc++6 libatomic1 sapconf saptune nvme-cli"
  local rhel_packages="unar.x86_64 tuned-profiles-sap-hana tuned-profiles-sap-hana-2.7.1-3.el7_3.3 resource-agents-sap-hana.x86_64 compat-sap-c++-6 numactl-libs.x86_64 libtool-ltdl.x86_64 nfs-utils.x86_64 pacemaker pcs lvm2.x86_64 compat-sap-c++-5.x86_64 csh autofs ndctl compat-sap-c++-9 compat-sap-c++-10 libatomic unzip libsss_autofs python2-pip langpacks-en langpacks-de glibc-all-langpacks libnsl libssh2 wget lsof jq"

  ## install packages
  if [[ ${LINUX_DISTRO} = "SLES" ]]; then
    for package in ${sles_packages}; do # Bash only splits unquoted.
        local count=0;
        local max_count=3;
        while ! sudo ZYPP_LOCK_TIMEOUT=60 zypper in -y "${package}"; do
          count=$((count +1))
          sleep 3
          if [[ ${count} -gt ${max_count} ]]; then
            main::errhandle_log_warning "Failed to install ${package}, continuing installation."
            break
          fi
        done
    done
    # making sure we refresh the bash env
    . /etc/bash.bashrc
    # boto.cfg has spaces in 15sp2, getting rid of them (b/172181835)
    if [[ $(tail -n 1 /etc/boto.cfg) == "  ca_certificates_file = system" ]]; then
      sed -i 's/^[ \t]*//' /etc/boto.cfg
    fi
  elif [[ ${LINUX_DISTRO} = "RHEL" ]]; then
    for package in $rhel_packages; do
        local count=0;
        local max_count=3;
        while ! yum -y install "${package}"; do
          count=$((count +1))
          sleep 3
          if [[ ${count} -gt ${max_count} ]]; then
            main::errhandle_log_warning "Failed to install ${package}, continuing installation."
            break
          fi
        done
    done
    # check for python interpreter - RHEL 8 does not have "python"
    main::errhandle_log_info 'Checking for python interpreter'
    if [[ ! -f "/bin/python" ]] && [[ -f "/usr/bin/python2" ]]; then
      main::errhandle_log_info 'Updating alternatives for python to python2.7'
      alternatives --set python /usr/bin/python2
    fi
    # make sure latest packages are installed (https://cloud.google.com/solutions/sap/docs/sap-hana-ha-config-rhel#install_the_cluster_agents_on_both_nodes)
    main::errhandle_log_info 'Applying updates to packages on system'
    if ! yum update -y; then
      main::errhandle_log_warning 'Applying updates to packages on system failed ("yum update -y"). Logon to the VM to investigate the issue.'
    fi
  fi
  main::errhandle_log_info 'Install of required operating system packages complete'
}

#######################################
# Finds and returns (via 'echo') first device in $by_id_dir that contains
# $searchstring. Works with SCSI (/dev/sdX) and NVME (/dev/nvmeX) devices.
#
# Input: searchstring
# Output: device name
#
# Examples for NVME and SCSI:
#     main::get_device_by_id backup
#       /dev/nvme0n3     (NVME)
#       /dev/sdc         (SCSI)
#######################################
main::get_device_by_id() {

  local searchstring=${1}
  local by_id_dir="/dev/disk/by-id"
  local device_name=""
  local nvme_script='/usr/lib/udev/google_nvme_id'

  device_name=$(readlink -f ${by_id_dir}/$(ls ${by_id_dir} | grep google | grep -m 1 "${searchstring}"))
  if [ ${device_name} != ${by_id_dir} ]; then
    echo ${device_name}
    return
  fi

  # TODO(franklegler): Remove workaround once b/249894430 is resolved
  # On M3 with SLES devices are not yet listed by their name (b/249894430)
  # Workaround: Run script to create symlinks ()
  if [[ -b /dev/nvme0n1 ]] && [[ -f ${nvme_script} ]]; then
    udevadm control --reload-rules && udevadm trigger # b/249894430#comment11
    for i in $(ls /dev/nvme0n*); do                   # b/249894430#comment13
        $nvme_script -d $i -s
    done
    device_name=$(readlink -f ${by_id_dir}/$(ls ${by_id_dir} | grep google | grep -m 1 "${searchstring}"))
    if [ ${device_name} != ${by_id_dir} ]; then
      echo ${device_name}
      return
    fi
  fi
  # End workaround

  main::errhandle_log_error "No device containing '${searchstring}' found."
}


main::create_vg() {
  local device=${1}
  local volume_group=${2}

  if [[ -b "$device" ]]; then
    main::errhandle_log_info "--- Creating physical volume group ${device}"
    pvcreate "${device}"
    main::errhandle_log_info "--- Creating volume group ${volume_group} on ${device}"
    vgcreate "${volume_group}" "${device}"
    /sbin/vgchange -ay
  else
      main::errhandle_log_error "Unable to access ${device}"
  fi
}


main::create_filesystem() {
  local mount_point=${1}
  local device=${2}
  local filesystem=$3
  local is_optional_file_system=${4}

  if [[ -h /dev/disk/by-id/google-"${HOSTNAME}"-"${device}" ]]; then
    main::errhandle_log_info "--- ${mount_point}"
    pvcreate /dev/disk/by-id/google-"${HOSTNAME}"-"${device}"
    vgcreate vg_"${device}" /dev/disk/by-id/google-"${HOSTNAME}"-"${device}"
    lvcreate -l 100%FREE -n vol vg_"${device}"
    main::format_mount "${mount_point}" /dev/vg_"${device}"/vol "${filesystem}"
    if [[ "${mount_point}" != "swap" ]]; then
      main::check_mount "${mount_point}"
    fi
  elif [[ ${is_optional_file_system:-"notOptional"} == "optional" ]]; then
    main::errhandle_log_warning "Unable to create optional file system ${filesystem}."
  else
    main::errhandle_log_error "Unable to access ${device}"
  fi

}


main::check_mount() {
  local mount_point=${1}
  local on_error=${2}

  ## check /etc/mtab to see if the filesystem is mounted
  if ! grep -q "${mount_point}" /etc/mtab; then
    case "${on_error}" in
      error)
        main::errhandle_log_error "Unable to mount ${mount_point}"
        ;;

      info)
        main::errhandle_log_info "Unable to mount ${mount_point}"
        ;;

      warning)
        main::errhandle_log_warning "Unable to mount ${mount_point}"
        ;;

      *)
        main::errhandle_log_error "Unable to mount ${mount_point}"
    esac
  fi

}

main::format_mount() {
  local mount_point=${1}
  local device=${2}
  local filesystem=${3}
  local options=${4}

  if [[ -b "$device" ]]; then
    if [[ "${filesystem}" = "swap" ]]; then
      echo "${device} none ${filesystem} defaults,nofail 0 0" >>/etc/fstab
      mkswap "${device}"
      swapon "${device}"
    else
      main::errhandle_log_info "--- Creating ${mount_point}"
      mkfs -t "${filesystem}" "${device}"
      mkdir -p "${mount_point}"
      if [[ ! "${options}" = "tmp" ]]; then
        echo "${device} ${mount_point} ${filesystem} defaults,nofail,logbsize=256k 0 2" >>/etc/fstab
        mount -a
      else
        mount -t "${filesystem}" "${device}" "${mount_point}"
      fi
      main::check_mount "${mount_point}"
    fi
  else
    main::errhandle_log_error "Unable to access ${device}"
  fi
}


main::get_settings() {
  main::errhandle_log_info "Fetching GCE Instance Settings"

  ## set current zone as the default zone
  readonly CLOUDSDK_COMPUTE_ZONE=$(main::get_metadata "http://169.254.169.254/computeMetadata/v1/instance/zone" | cut -d'/' -f4)
  export CLOUDSDK_COMPUTE_ZONE
  main::errhandle_log_info "--- Instance determined to be running in ${CLOUDSDK_COMPUTE_ZONE}. Setting this as the default zone"

  readonly VM_REGION=${CLOUDSDK_COMPUTE_ZONE::-2}

  ## get instance type & details
  readonly VM_INSTTYPE=$(main::get_metadata http://169.254.169.254/computeMetadata/v1/instance/machine-type | cut -d'/' -f4)
  main::errhandle_log_info "--- Instance type determined to be ${VM_INSTTYPE}"

  readonly VM_CPUPLAT=$(main::get_metadata "http://169.254.169.254/computeMetadata/v1/instance/cpu-platform")
  main::errhandle_log_info "--- Instance is determined to be part on CPU Platform ${VM_CPUPLAT}"

  readonly VM_CPUCOUNT=$(grep -c processor /proc/cpuinfo)
  main::errhandle_log_info "--- Instance determined to have ${VM_CPUCOUNT} cores"

  readonly VM_MEMSIZE=$(free -g | grep Mem | awk '{ print $2 }')
  main::errhandle_log_info "--- Instance determined to have ${VM_MEMSIZE}GB of memory"

  readonly VM_PROJECT=$(main::get_metadata "http://169.254.169.254/computeMetadata/v1/project/project-id")
  main::errhandle_log_info "--- VM is in project ${VM_PROJECT}"

  ## get network settings
  readonly VM_NETWORK=$(main::get_metadata http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/network | cut -d'/' -f4)
  main::errhandle_log_info "--- Instance is determined to be part of network ${VM_NETWORK}"

  readonly VM_NETWORK_FULL=$(gcloud compute instances describe "${HOSTNAME}" | grep "subnetwork:" | head -1 | grep -o 'projects.*')

  readonly VM_SUBNET=$(grep -o 'subnetworks.*' <<< "${VM_NETWORK_FULL}" | cut -f2- -d"/")
  main::errhandle_log_info "--- Instance is determined to be part of subnetwork ${VM_SUBNET}"

  readonly VM_NETWORK_PROJECT=$(cut -d'/' -f2 <<< "${VM_NETWORK_FULL}")
  main::errhandle_log_info "--- Networking is hosted in project ${VM_NETWORK_PROJECT}"

  readonly VM_IP=$(main::get_metadata http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/ip)
  main::errhandle_log_info "--- Instance IP is determined to be ${VM_IP}"

  # fetch all custom metadata associated with the instance
  main::errhandle_log_info "Fetching GCE Instance Metadata"
  local value
  local key
  declare -g -A VM_METADATA
  local uses_secret_password
  uses_secret_password="false"

  for key in $(curl --fail -sH'Metadata-Flavor: Google' http://169.254.169.254/computeMetadata/v1/instance/attributes/ | grep -v ssh-keys); do
    value=$(main::get_metadata "${key}")

    if [[ "${key}" = *"password"* ]]; then
      main::errhandle_log_info "${key} determined to be *********"
    else
      main::errhandle_log_info "${key} determined to be '${value}'"
    fi


    if [[ ${uses_secret_password} == "true" ]] && [[ "${key}" = *"password" ]]; then
      continue;
    fi

    if [[ "${key}" = *"password_secret"* ]]; then
      if [[ -z ${value} ]]; then
        continue;
      fi
      uses_secret_password="true"
      pass_key=${key::-7} # strips off _secret
      secret_ret=$(${GCLOUD} secrets versions access latest --secret="${value}")
      VM_METADATA[$pass_key]="${secret_ret}"
    else
      VM_METADATA[$key]="${value}"
    fi

  done

  # remove startup script
  if [[ -n "${VM_METADATA[startup-script]}" ]]; then
    main::remove_metadata startup-script
  fi

  # remove metrics info
  if [[ -n "${VM_METADATA[template-type]}" ]]; then
    main::remove_metadata template-type
  else
    VM_METADATA[template-type]="UNKNOWN"
  fi

  ## if the startup script has previously completed, abort execution.
  if [[ -n "${VM_METADATA[status]}" ]]; then
    main::errhandle_log_info "Startup script has previously been run. Taking no further action."
    exit 0
  fi
}


main::create_static_ip() {
  ## attempt to reserve the current IP address as static
  if [[ "$VM_NETWORK_PROJECT" == "${VM_PROJECT}" ]]; then
    main::errhandle_log_info "Creating static IP address ${VM_IP} in subnetwork ${VM_SUBNET}"
    ${GCLOUD} --quiet compute --project "${VM_NETWORK_PROJECT}" addresses create "${HOSTNAME}" --addresses "${VM_IP}" --region "${VM_REGION}" --subnet "${VM_SUBNET}"
  else
    main::errhandle_log_info "Creating static IP address ${VM_IP} in shared VPC ${VM_NETWORK_PROJECT}"
    ${GCLOUD} --quiet compute --project "${VM_PROJECT}" addresses create "${HOSTNAME}" --addresses "${VM_IP}" --region "${VM_REGION}" --subnet "${VM_NETWORK_FULL}"
  fi
}


main::remove_metadata() {
  local key=${1}

  ${GCLOUD} --quiet compute instances remove-metadata "${HOSTNAME}" --keys "${key}"
}


main::install_gsdk() {
  local install_location=${1}
  local rc

  if [[ -e /usr/bin/gsutil ]]; then
    # if SDK is installed, link to the standard location for backwards compatibility
    if [[ ! -d /usr/local/google-cloud-sdk/bin ]]; then
      mkdir -p /usr/local/google-cloud-sdk/bin
    fi
    if [[ ! -e /usr/local/google-cloud-sdk/bin/gsutil ]]; then
      ln -s /usr/bin/gsutil /usr/local/google-cloud-sdk/bin/gsutil
    fi
    if [[ ! -e /usr/local/google-cloud-sdk/bin/gcloud ]]; then
      ln -s /usr/bin/gcloud /usr/local/google-cloud-sdk/bin/gcloud
    fi
  elif [[ ! -d "${install_location}/google-cloud-sdk" ]]; then
    # b/188946979
    if [[ "${LINUX_DISTRO}" = "SLES" && "${LINUX_MAJOR_VERSION}" = "12" ]]; then
      export CLOUDSDK_PYTHON=/usr/bin/python
    fi
    bash <(curl -s https://dl.google.com/dl/cloudsdk/channels/rapid/install_google_cloud_sdk.bash) --disable-prompts --install-dir="${install_location}" >/dev/null
    rc=$?
    if [[ "${rc}" -eq 0 ]]; then
      main::errhandle_log_info "Installed Google SDK in ${install_location}"
    else
      main::errhandle_log_error "Google SDK not correctly installed. Aborting installation."
    fi

    if [[ ${LINUX_DISTRO} = "SLES" ]]; then
      update-alternatives --install /usr/bin/gsutil gsutil /usr/local/google-cloud-sdk/bin/gsutil 1 --force
      update-alternatives --install /usr/bin/gcloud gcloud /usr/local/google-cloud-sdk/bin/gcloud 1 --force
    fi
  fi

  readonly GCLOUD="/usr/bin/gcloud"
  readonly GSUTIL="/usr/bin/gsutil"

  ## set default python version for Cloud SDK in SLES, move from 3.4 to 2.7
  # b/188946979 - only applicable to SLES12
  if [[ ${LINUX_DISTRO} = "SLES" && "${LINUX_MAJOR_VERSION}" = "12" ]]; then
    update-alternatives --install /usr/bin/gsutil gsutil /usr/local/google-cloud-sdk/bin/gsutil 1 --force
    update-alternatives --install /usr/bin/gcloud gcloud /usr/local/google-cloud-sdk/bin/gcloud 1 --force
    export CLOUDSDK_PYTHON=/usr/bin/python
    # b/189944327 - to avoid gcloud/gsutil fails when using Python3.4 on SLES12
    if ! grep -q CLOUDSDK_PYTHON /etc/profile; then
      echo "export CLOUDSDK_PYTHON=/usr/bin/python" | tee -a /etc/profile
    fi
    if ! grep -q CLOUDSDK_PYTHON /etc/environment; then
      echo "export CLOUDSDK_PYTHON=/usr/bin/python" | tee -a /etc/environment
    fi
  fi

  ## run an instances list to ensure the software is up to date
  ${GCLOUD} --quiet beta compute instances list >/dev/null
}


main::check_default() {
  local default=${1}
  local current=${2}

  if [[ -z ${current} ]]; then
    echo "${default}"
  else
    echo "${current}"
  fi
}


main::get_metadata() {
  local key=${1}

  local value

  if [[ ${key} = *"169.254.169.254/computeMetadata"* ]]; then
      value=$(curl --fail -sH'Metadata-Flavor: Google' "${key}")
  else
    value=$(curl --fail -sH'Metadata-Flavor: Google' http://169.254.169.254/computeMetadata/v1/instance/attributes/"${key}")
  fi
  echo "${value}"
}


main::update-metadata() {
    local key="${1}"
    local value="${2}"

    local count=0
    local max_count=10

    while ! ${GCLOUD} --quiet compute instances add-metadata "${HOSTNAME}" --metadata "${key}=${value}" --zone "${CLOUDSDK_COMPUTE_ZONE}"; do
      count=$((count +1))
      if [ ${count} -gt ${max_count} ]; then
        main::errhandle_log_info "Failed to update metadata key=${key}, value=${value}, continuing."
        break
      else
        main::errhandle_log_info "Failed to update metadata key=${key}, value=${value}, trying again in 5 seconds. [Attempt ${count}/${max_count}"
        sleep 5s
      fi
    done
}

main::complete() {
  local on_error=${1}

  ## update instance metadata with status
  if [[ -n "${on_error}" ]]; then
    main::update-metadata "status" "failed_or_error"
    metrics::send_metric -s "ERROR"  -e "1"
  elif [[ -n "${deployment_warnings}" ]]; then
    main::errhandle_log_info "INSTANCE DEPLOYMENT COMPLETE"
    main::update-metadata "status" "completed_with_warnings"
    metrics::send_metric -s "ERROR"  -e "2"
  else
    main::errhandle_log_info "INSTANCE DEPLOYMENT COMPLETE"
    main::update-metadata "status" "completed"
    metrics::send_metric -s "CONFIGURED"
  fi

  ## prepare advanced logs
  if [[ "${VM_METADATA[sap_deployment_debug]}" = "True" ]]; then
    mkdir -p /root/.deploy
    main::errhandle_log_info "--- Debug mode is turned on. Preparing additional logs"
    env > /root/.deploy/"${HOSTNAME}"_debug_env.log
    grep startup /var/log/messages > /root/.deploy/"${HOSTNAME}"_debug_startup_script_output.log
    tar -czvf /root/.deploy/"${HOSTNAME}"_deployment_debug.tar.gz -C /root/.deploy/ .
    main::errhandle_log_info "--- Debug logs stored in /root/.deploy/"
  ## Upload logs to GCS bucket & display complete message
    if [ -n "${VM_METADATA[sap_hana_deployment_bucket]}" ]; then
      main::errhandle_log_info "--- Uploading logs to Google Cloud Storage bucket"
      ${GSUTIL} -q cp /root/.deploy/"${HOSTNAME}"_deployment_debug.tar.gz  gs://"${VM_METADATA[sap_hana_deployment_bucket]}"/logs/
    fi
  fi

  ## Run custom post deployment script
  if [[ -n "${VM_METADATA[post_deployment_script]}" ]]; then
      main::errhandle_log_info "--- Running custom post deployment script - ${VM_METADATA[post_deployment_script]}"
    if [[ "${VM_METADATA[post_deployment_script]:0:8}" = "https://" ]] || [[ "${VM_METADATA[post_deployment_script]:0:7}" = "http://" ]]; then
      source /dev/stdin <<< "$(curl -s "${VM_METADATA[post_deployment_script]}")"
    elif [[ "${VM_METADATA[post_deployment_script]:0:5}" = "gs://" ]]; then
      source /dev/stdin <<< "$("${GSUTIL}" cat "${VM_METADATA[post_deployment_script]}")"
    else
      main::errhandle_log_warning "--- Unknown post deployment script. URL must begin with https:// http:// or gs://"
    fi
  fi

  if [[ -z "${deployment_warnings}" ]]; then
    main::errhandle_log_info "--- Finished"
  else
    main::errhandle_log_warning "--- Finished (${deployment_warnings} warnings)"
  fi

  ## exit sending right error code
  if [[ -z "${on_error}" ]]; then
      exit 0
    else
    exit 1
  fi
}

main::send_start_metrics() {
  metrics::send_metric -s "STARTED"
  metrics::send_metric -s "TEMPLATEID"
}

main::install_ops_agent() {
  if [[ ! "${VM_METADATA[install_cloud_ops_agent]}" == "false" ]]; then
    main::errhandle_log_info "Installing Google Ops Agent"
    curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
    sudo bash add-google-cloud-ops-agent-repo.sh --also-install
  fi
}

main::install_monitoring_agent() {
  local msg1
  local msg2

  main::errhandle_log_info "Installing SAP Agent"
  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    main::errhandle_log_info "Installing agent for SLES"
    # SLES
    zypper addrepo --gpgcheck-allow-unsigned-package --refresh https://packages.cloud.google.com/yum/repos/google-cloud-sap-agent-sles$(grep "VERSION_ID=" /etc/os-release | cut -d = -f 2 | tr -d '"' | cut -d . -f 1)-\$basearch google-cloud-sap-agent
    rpm --import https://packages.cloud.google.com/yum/doc/yum-key.gpg

    if timeout 300 zypper -n --no-gpg-checks install "google-cloud-sap-agent"; then
      main::errhandle_log_info "Finished installation SAP Agent"
    else
      local msg1="SAP Agent did not install correctly."
      local msg2="Try to install it manually."
      main::errhandle_log_info "${msg1} ${msg2}"
    fi
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    # RHEL
    main::errhandle_log_info "Installing agent for RHEL"

  tee /etc/yum.repos.d/google-cloud-sap-agent.repo << EOM
[google-cloud-sap-agent]
name=Google Cloud Agent for SAP
baseurl=https://packages.cloud.google.com/yum/repos/google-cloud-sap-agent-el$(cat /etc/redhat-release | cut -d . -f 1 | tr -d -c 0-9)-\$basearch
enabled=1
gpgcheck=0
repo_gpgcheck=0
EOM

    if timeout 300 yum install -y "google-cloud-sap-agent"; then
      main::errhandle_log_info "Finished installation SAP Agent"
    else
      local msg1="SAP Agent did not install correctly."
      local msg2="Try to install it manually."
      main::errhandle_log_info "${msg1} ${msg2}"
    fi
  fi
  set +e
}

ha::check_settings() {

  # Set additional global constants
  sleep "60"
  readonly PRIMARY_NODE_IP=$(gcloud compute instances list --format="csv[no-heading](INTERNAL_IP)"  --filter="name=(aigascs-ers1)" --project=aig-sap-dev)
  readonly SECONDARY_NODE_IP=$(gcloud compute instances list --format="csv[no-heading](INTERNAL_IP)"  --filter="name=(aigascs-ers2)" --project=aig-sap-dev)
#  readonly PRIMARY_NODE_IP=$(ping "${VM_METADATA[sap_primary_instance]}" -c 1 | head -1 | awk  '{ print $3 }' | sed 's/(//' | sed 's/)//')
#  readonly SECONDARY_NODE_IP=$(ping "${VM_METADATA[sap_secondary_instance]}" -c 1 | head -1 | awk  '{ print $3 }' | sed 's/(//' | sed 's/)//')
  echo "${PRIMARY_NODE_IP} line 1384"
  echo "${SECONDARY_NODE_IP} line 1385"
  echo "${PRIMARY_NODE_IP} aigascs-ers1" >> /etc/hosts
  echo "${SECONDARY_NODE_IP} aigascs-ers2" >> /etc/hosts
  ## check required parameters are present
  echo "sap vip : ${VM_METADATA[sap_vip]} - primary-name: ${VM_METADATA[sap_primary_instance]}- primary ip : ${PRIMARY_NODE_IP}"
  echo "praimary zone: ${VM_METADATA[sap_primary_zone]}- secondary-name: ${VM_METADATA[sap_secondary_instance]}- SECONDARY ip : ${SECONDARY_NODE_IP}"
  if [ -z "${VM_METADATA[sap_vip]}" ] || [ -z "${VM_METADATA[sap_primary_instance]}" ] || [ -z "${PRIMARY_NODE_IP}" ] || [ -z "${VM_METADATA[sap_primary_zone]}" ] || [ -z "${VM_METADATA[sap_secondary_instance]}" ] || [ -z "${SECONDARY_NODE_IP}" ]; then
  main::errhandle_log_warning "High Availability variables were missing or incomplete. Both SAP HANA VMs will be installed and configured but HA will need to be manually setup "
  main::complete
  fi

  mkdir -p /root/.deploy
}


ha::download_scripts() {
  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    main::errhandle_log_info "Downloading pacemaker-gcp"
    mkdir -p /usr/lib/ocf/resource.d/gcp
    mkdir -p /usr/lib64/stonith/plugins/external
    curl https://storage.googleapis.com/cloudsapdeploy/deploymentmanager/latest/pacemaker-gcp/alias -o /usr/lib/ocf/resource.d/gcp/alias
    curl https://storage.googleapis.com/cloudsapdeploy/deploymentmanager/latest/pacemaker-gcp/route -o /usr/lib/ocf/resource.d/gcp/route
    curl https://storage.googleapis.com/cloudsapdeploy/deploymentmanager/latest/pacemaker-gcp/gcpstonith -o /usr/lib64/stonith/plugins/external/gcpstonith
    chmod +x /usr/lib/ocf/resource.d/gcp/alias
    chmod +x /usr/lib/ocf/resource.d/gcp/route
    chmod +x /usr/lib64/stonith/plugins/external/gcpstonith
  fi
  # not needed for RHEL
}


ha::create_hdb_user() {
  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    hana_monitoring_user="slehasync"
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    hana_monitoring_user="rhelhasync"
  fi

  main::errhandle_log_info "Adding user ${hana_monitoring_user} to ${VM_METADATA[sap_hana_sid]}"

  ## create .sql file
  echo "CREATE USER ${hana_monitoring_user} PASSWORD \"${VM_METADATA[sap_hana_system_password]}\";" > /root/.deploy/"${HOSTNAME}"_hdbadduser.sql
  echo "GRANT DATA ADMIN TO ${hana_monitoring_user};" >> /root/.deploy/"${HOSTNAME}"_hdbadduser.sql
  echo "ALTER USER ${hana_monitoring_user} DISABLE PASSWORD LIFETIME;" >> /root/.deploy/"${HOSTNAME}"_hdbadduser.sql

  ## run .sql file
  PATH="$PATH:/usr/sap/${VM_METADATA[sap_hana_sid]}/HDB${VM_METADATA[sap_hana_instance_number]}/exe"
  bash -c "source /usr/sap/*/home/.sapenv.sh && hdbsql -u system -p '"${VM_METADATA[sap_hana_system_password]}"' -i ${VM_METADATA[sap_hana_instance_number]} -I /root/.deploy/${HOSTNAME}_hdbadduser.sql"
}


ha::hdbuserstore() {

  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    hana_user_store_key="SLEHALOC"
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    hana_user_store_key="SAPHANARH2SR"
  fi

  main::errhandle_log_info "Adding hdbuserstore entry '${hana_user_store_key}' pointing to localhost:3${VM_METADATA[sap_hana_instance_number]}15"

  #add user store
  PATH="$PATH:/usr/sap/${VM_METADATA[sap_hana_sid]}/HDB${VM_METADATA[sap_hana_instance_number]}/exe"
  bash -c "source /usr/sap/*/home/.sapenv.sh && hdbuserstore SET ${hana_user_store_key} localhost:3${VM_METADATA[sap_hana_instance_number]}15 ${hana_monitoring_user} '"${VM_METADATA[sap_hana_system_password]}"'"

  #check userstore
  bash -c "source /usr/sap/*/home/.sapenv.sh && hdbsql -U ${hana_user_store_key} -o /root/.deploy/hdbsql.out -a 'select * from dummy'"

  if  ! grep -q \"X\" /root/.deploy/hdbsql.out; then
    main::errhandle_log_warning "Unable to connect to HANA after adding hdbuserstore entry. Both SAP HANA systems have been installed and configured but the remainder of the HA setup will need to be manually performed"
    main::complete
  fi

  main::errhandle_log_info "--- hdbuserstore connection test successful"
}


ha::install_secondary_sshkeys() {
  main::errhandle_log_info "Adding ${VM_METADATA[sap_primary_instance]} ssh keys to ${VM_METADATA[sap_secondary_instance]}"

  local count=0
  local max_count=10

  while ! gcloud compute instances add-metadata "${VM_METADATA[sap_secondary_instance]}" --metadata "ssh-keys=root:$(cat ~/.ssh/id_rsa.pub)" --zone "${VM_METADATA[sap_secondary_zone]}"; do
    count=$((count +1))
    if [ ${count} -gt ${max_count} ]; then
      main::errhandle_log_error "Failed to add ${VM_METADATA[sap_primary_instance]} ssh keys to ${VM_METADATA[sap_secondary_instance]}, aborting installation."
    else
      main::errhandle_log_info "Failed to to add ${VM_METADATA[sap_primary_instance]} ssh keys to ${VM_METADATA[sap_secondary_instance]}, trying again in 5 seconds."
      sleep 5s
    fi
  done

  cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
}


ha::install_primary_sshkeys() {
  main::errhandle_log_info "Adding ${VM_METADATA[sap_secondary_instance]} ssh keys to ${VM_METADATA[sap_primary_instance]}"

  local count=0
  local max_count=10

  while ! gcloud compute instances add-metadata "${VM_METADATA[sap_primary_instance]}" --metadata "ssh-keys=root:$(cat /root/.ssh/id_rsa.pub)" --zone "${VM_METADATA[sap_primary_zone]}"; do
    count=$((count +1))
    if [ ${count} -gt ${max_count} ]; then
      main::errhandle_log_error "Failed to add ${VM_METADATA[sap_secondary_instance]} ssh keys to ${VM_METADATA[sap_primary_instance]}, aborting installation."
    else
      main::errhandle_log_info "Failed to add  ${VM_METADATA[sap_secondary_instance]} ssh keys to ${VM_METADATA[sap_primary_instance]}, trying again in 5 seconds."
      sleep 5s
    fi
  done
  cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys
}


ha::wait_for_secondary() {
  local count=0
  local deployment_type=${1}

  main::errhandle_log_info "Waiting for ready signal from ${VM_METADATA[sap_secondary_instance]} before continuing"

  while [[ ! -f /root/.deploy/.${VM_METADATA[sap_secondary_instance]}.ready ]]; do
    count=$((count +1))
    scp -o StrictHostKeyChecking=no "${VM_METADATA[sap_secondary_instance]}":/root/.deploy/."${VM_METADATA[sap_secondary_instance]}".ready /root/.deploy/
    main::errhandle_log_info "--- ${VM_METADATA[sap_secondary_instance]} is not ready - sleeping for 60 seconds then trying again"
    sleep 60s
    if [ ${count} -gt 15 ]; then
      if [ ${deployment_type} = "nw_ha" ]; then
        main::errhandle_log_error "${VM_METADATA[sap_secondary_instance]} wasn't ready in time. Aborting installation. Please check /var/log/messages for errors and if machines can communicate with each other."
      else
        main::errhandle_log_warning "${VM_METADATA[sap_secondary_instance]} wasn't ready in time. Both SAP HANA systems have been installed and configured but the remainder of the HA setup will need to be manually performed"
        main::complete
      fi
    fi
  done

  main::errhandle_log_info "--- ${VM_METADATA[sap_secondary_instance]} is now ready - continuing HA setup"
}


ha::wait_for_primary() {
  local count=0
  local deployment_type=${1}

  main::errhandle_log_info "Waiting for ready signal from ${VM_METADATA[sap_primary_instance]} before continuing"
  scp -o StrictHostKeyChecking=no "${VM_METADATA[sap_primary_instance]}":/root/.deploy/."${VM_METADATA[sap_primary_instance]}".ready /root/.deploy/

  while [[ ! -f /root/.deploy/."${VM_METADATA[sap_primary_instance]}".ready ]]; do
    count=$((count +1))
    scp -o StrictHostKeyChecking=no "${VM_METADATA[sap_primary_instance]}":/root/.deploy/."${VM_METADATA[sap_primary_instance]}".ready /root/.deploy/
    main::errhandle_log_info "--- ${VM_METADATA[sap_primary_instance]} is not ready - sleeping for 60 seconds then trying again"
    sleep 60s
    if [ ${count} -gt 10 ]; then
      if [ ${deployment_type} = "nw_ha" ]; then
        main::errhandle_log_error "${VM_METADATA[sap_primary_instance]} wasn't ready in time. Aborting installation. Please check /var/log/messages for errors and if machines can communicate with each other."
      else
        main::errhandle_log_warning "${VM_METADATA[sap_primary_instance]} wasn't ready in time. Both SAP HANA systems have been installed and configured but the remainder of the HA setup will need to be manually performed"
        main::complete
      fi
    fi
  done

  main::errhandle_log_info "--- ${VM_METADATA[sap_primary_instance]} is now ready - continuing HA setup"
}


ha::ready(){
  echo "ready" > /root/.deploy/."${HOSTNAME}".ready
}


ha::config_cluster(){
  main::errhandle_log_info "Configuring cluster primivatives"
}


ha::copy_hdb_ssfs_keys(){
  main::errhandle_log_info "Transfering SSFS keys from ${VM_METADATA[sap_primary_instance]}"
  rm /usr/sap/"${VM_METADATA[sap_hana_sid]}"/SYS/global/security/rsecssfs/data/SSFS_"${VM_METADATA[sap_hana_sid]}".DAT
  rm /usr/sap/"${VM_METADATA[sap_hana_sid]}"/SYS/global/security/rsecssfs/key/SSFS_"${VM_METADATA[sap_hana_sid]}".KEY
  scp -o StrictHostKeyChecking=no "${VM_METADATA[sap_primary_instance]}":/usr/sap/"${VM_METADATA[sap_hana_sid]}"/SYS/global/security/rsecssfs/data/SSFS_"${VM_METADATA[sap_hana_sid]}".DAT /usr/sap/"${VM_METADATA[sap_hana_sid]}"/SYS/global/security/rsecssfs/data/SSFS_"${VM_METADATA[sap_hana_sid]}".DAT
  scp -o StrictHostKeyChecking=no "${VM_METADATA[sap_primary_instance]}":/usr/sap/"${VM_METADATA[sap_hana_sid]}"/SYS/global/security/rsecssfs/key/SSFS_"${VM_METADATA[sap_hana_sid]}".KEY /usr/sap/"${VM_METADATA[sap_hana_sid]}"/SYS/global/security/rsecssfs/key/SSFS_"${VM_METADATA[sap_hana_sid]}".KEY
  chown "${VM_METADATA[sap_hana_sid],,}"adm:sapsys /usr/sap/"${VM_METADATA[sap_hana_sid]}"/SYS/global/security/rsecssfs/data/SSFS_"${VM_METADATA[sap_hana_sid]}".DAT
  chown "${VM_METADATA[sap_hana_sid],,}"adm:sapsys /usr/sap/"${VM_METADATA[sap_hana_sid]}"/SYS/global/security/rsecssfs/key/SSFS_"${VM_METADATA[sap_hana_sid]}".KEY
  chmod g+wrx,u+wrx /usr/sap/"${VM_METADATA[sap_hana_sid]}"/SYS/global/security/rsecssfs/data/SSFS_"${VM_METADATA[sap_hana_sid]}".DAT
  chmod g+wrx,u+wrx  /usr/sap/"${VM_METADATA[sap_hana_sid]}"/SYS/global/security/rsecssfs/key/SSFS_"${VM_METADATA[sap_hana_sid]}".KEY
}


ha::enable_hsr() {
  main::errhandle_log_info "Enabling HANA System Replication support "
  runuser -l "${VM_METADATA[sap_hana_sid],,}adm" -c "hdbnsutil -sr_enable --name=${HOSTNAME}"
}


ha::config_hsr() {
  main::errhandle_log_info "Configuring SAP HANA system replication primary -> secondary"
  runuser -l "${VM_METADATA[sap_hana_sid],,}adm" -c "hdbnsutil -sr_register --remoteHost=${VM_METADATA[sap_primary_instance]} --remoteInstance=${VM_METADATA[sap_hana_instance_number]} --replicationMode=syncmem --operationMode=logreplay --name=${VM_METADATA[sap_secondary_instance]}"
}


ha::check_hdb_replication(){
  main::errhandle_log_info "Checking SAP HANA replication status"
  # check status
  bash -c "source /usr/sap/*/home/.sapenv.sh && /usr/sap/${VM_METADATA[sap_hana_sid]}/HDB${VM_METADATA[sap_hana_instance_number]}/exe/hdbsql -o /root/.deploy/hdbsql.out -a -U ${hana_user_store_key} 'select distinct REPLICATION_STATUS from SYS.M_SERVICE_REPLICATION'"

  local count=0

  while ! grep -q \"ACTIVE\" /root/.deploy/hdbsql.out; do
    count=$((count +1)) # b/183019459
    main::errhandle_log_info "--- Replication is still in progressing. Waiting 60 seconds then trying again"
    bash -c "source /usr/sap/*/home/.sapenv.sh && /usr/sap/${VM_METADATA[sap_hana_sid]}/HDB${VM_METADATA[sap_hana_instance_number]}/exe/hdbsql -o /root/.deploy/hdbsql.out -a -U ${hana_user_store_key} 'select distinct REPLICATION_STATUS from SYS.M_SERVICE_REPLICATION'"
    sleep 60s
    if [ ${count} -gt 20 ]; then
      main::errhandle_log_error "SAP HANA System Replication didn't complete. Please check network connectivity and firewall rules"
    fi
  done
  main::errhandle_log_info "--- Replication in sync. Continuing with HA configuration"
}


ha::check_cluster(){
  main::errhandle_log_info "Checking cluster status"
  local count=0
  local max_attempts=20
  local sleep_time=60
  local finished=1

  while ! [ ${finished} -eq 0 ]; do
    if [ "${LINUX_DISTRO}" = "SLES" ]; then
      crm_mon -s | grep -q "2 nodes online"
      finished=$?
    elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
      [ $(pcs cluster status | egrep -e "(${VM_METADATA[sap_primary_instance]}|${VM_METADATA[sap_secondary_instance]}): Online" | wc -l) = "2" ]
      finished=$?
    fi
    if ! [ ${finished} -eq 0 ]; then
      count=$((count +1))
      main::errhandle_log_info "--- Cluster is not yet online. Waiting ${sleep_time} seconds then trying again (attempt number ${count} of max ${max_attempts})"
      sleep ${sleep_time}s
      if [ ${count} -gt ${max_attempts} ]; then
        main::errhandle_log_error "Pacemaker cluster failed to come online. Please check network connectivity and firewall rules"
      fi
    fi
  done
  main::errhandle_log_info "--- Two cluster nodes are online and ready. Continuing with HA configuration"
}


ha::config_corosync(){
  main::errhandle_log_info "--- Creating /etc/corosync/corosync.conf"
  cat <<EOF > /etc/corosync/corosync.conf
    totem {
      version: 2
      secauth: off
      crypto_hash: sha1
      crypto_cipher: aes256
      cluster_name: hacluster
      clear_node_high_bit: yes
      token: 20000
      token_retransmits_before_loss_const: 10
      join: 60
      max_messages: 20
      transport: udpu
      interface {
        ringnumber: 0
        bindnetaddr: ${1}
        mcastport: 5405
        ttl: 1
      }
    }
    logging {
      fileline: off
      to_stderr: no
      to_logfile: no
      logfile: /var/log/cluster/corosync.log
      to_syslog: yes
      debug: off
      timestamp: on
      logger_subsys {
        subsys: QUORUM
        debug: off
      }
    }
    nodelist {
      node {
        ring0_addr: ${VM_METADATA[sap_primary_instance]}
        nodeid: 1
      }
      node {
        ring0_addr: ${VM_METADATA[sap_secondary_instance]}
        nodeid: 2
      }
    }
    quorum {
      provider: corosync_votequorum
      expected_votes: 2
      two_node: 1
    }
EOF
}


ha::config_pacemaker_primary() {
  main::errhandle_log_info "Creating cluster on primary node"

  main::errhandle_log_info "Updating /etc/hosts."
  # Only add on images that don't already do so
  if ! grep -q $PRIMARY_NODE_IP /etc/hosts; then
    echo $PRIMARY_NODE_IP " " ${VM_METADATA[sap_primary_instance]}"."$(hostname -d)" "${VM_METADATA[sap_primary_instance]} >> /etc/hosts
  fi
  echo $SECONDARY_NODE_IP " " ${VM_METADATA[sap_secondary_instance]}"."$(hostname -d)" "${VM_METADATA[sap_secondary_instance]} >> /etc/hosts

  main::errhandle_log_info "--- Creating corosync-keygen"
  corosync-keygen
  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    main::errhandle_log_info "--- Starting csync2"
    script -q -c 'ha-cluster-init -y csync2' > /dev/null 2>&1 &
    ha::config_corosync "${PRIMARY_NODE_IP}"
    main::errhandle_log_info "--- Starting cluster"
    sleep 5s
    # b/189944327 - to avoid that gcpstonith fails when using Python3.4 on SLES12
    if [[ "${LINUX_MAJOR_VERSION}" = "12" ]]; then
      echo "CLOUDSDK_PYTHON=/usr/bin/python" | tee -a /etc/sysconfig/pacemaker
    fi
    systemctl enable pacemaker
    systemctl start pacemaker
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    main::errhandle_log_info "--- Setting hacluster password"
    echo linux | passwd --stdin hacluster
    main::errhandle_log_info "--- Configure firewall to allow high-availability traffic"
    firewall-cmd --permanent --add-service=high-availability
    firewall-cmd --reload
    main::errhandle_log_info "--- Starting cluster services & enabling on startup"
    systemctl start pcsd.service
    systemctl enable pcsd.service
    main::errhandle_log_info "--- Creating the cluster"

    local count=0
    local max_attempts=30
    local sleep_time=20
    local finished=1
    local pcs_auth_command="pcs REPLACEME auth ${VM_METADATA[sap_primary_instance]} ${VM_METADATA[sap_secondary_instance]} -u hacluster -p linux"

    while ! [ ${finished} -eq 0 ]; do
      if [ "${LINUX_MAJOR_VERSION}" = "7" ]; then
        ${pcs_auth_command/REPLACEME/cluster}
        finished=$?
      elif [ "${LINUX_MAJOR_VERSION}" = "8"  ]; then
        ${pcs_auth_command/REPLACEME/host}
        finished=$?
      fi
      if [ ${finished} -eq 0 ]; then
        if [ "${LINUX_MAJOR_VERSION}" = "7" ]; then
          pcs cluster setup --name hacluster ${VM_METADATA[sap_primary_instance]} ${VM_METADATA[sap_secondary_instance]} --token 20000 --join 60
          main::errhandle_log_info "--- Configuring Corosync"
          sed -i 's/join: 60/join: 60\n    token_retransmits_before_loss_const: 10\n    max_messages: 20/g' /etc/corosync/corosync.conf
        elif [ "${LINUX_MAJOR_VERSION}" = "8"  ]; then
          pcs cluster setup hacluster ${VM_METADATA[sap_primary_instance]} ${VM_METADATA[sap_secondary_instance]} totem token=20000 join=60 token_retransmits_before_loss_const=10 max_messages=20
        fi
      else
        count=$((count +1))
        main::errhandle_log_info "--- pcsd.service not yet started on secondary - retrying in ${sleep_time} seconds (attempt number ${count} of max ${max_attempts})"
        sleep ${sleep_time}s
        if [ ${count} -gt ${max_attempts} ]; then
          main::errhandle_log_error "--- pcsd.service not started on secondary. Stopping deployment. Check logs on secondary."
        fi
      fi
    done
    pcs cluster sync
    pcs cluster enable --all
    pcs cluster start --all
  fi
}


ha::pacemaker_maintenance() {
  local mode="${1}"

  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    main::errhandle_log_info "Setting cluster maintenance mode to ${mode}"
    crm configure property maintenance-mode="${mode}"
    crm resource cleanup
  fi
  # not needed for RHEL during setup - might have to implement it later if needed
}


ha::config_pacemaker_secondary() {
  main::errhandle_log_info "Joining ${VM_METADATA[sap_secondary_instance]} to cluster"

  main::errhandle_log_info "Updating /etc/hosts."
  # Only add on images that don't already do so
  if ! grep -q $SECONDARY_NODE_IP /etc/hosts; then
    echo $SECONDARY_NODE_IP " " ${VM_METADATA[sap_secondary_instance]}"."$(hostname -d)" "${VM_METADATA[sap_secondary_instance]} >> /etc/hosts
  fi
  echo $PRIMARY_NODE_IP " " ${VM_METADATA[sap_primary_instance]}"."$(hostname -d)" "${VM_METADATA[sap_primary_instance]} >> /etc/hosts

  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    ha::config_corosync "${SECONDARY_NODE_IP}"
    bash -c "ha-cluster-join -y -c ${VM_METADATA[sap_primary_instance]} csync2"
    # b/189944327 - to avoid that gcpstonith fails when using Python3.4 on SLES12
    if [[ "${LINUX_MAJOR_VERSION}" = "12" ]]; then
      echo "CLOUDSDK_PYTHON=/usr/bin/python" | tee -a /etc/sysconfig/pacemaker
    fi
    systemctl enable pacemaker
    systemctl start pacemaker
    systemctl enable hawk
    systemctl start hawk
    if [ "${VM_METADATA[sap_vip_solution]}" = "ILB" ]; then
      main::errhandle_log_info "Using an ILB for the VIP"
      zypper in -y socat || main::errhandle_log_warning "- socat could not be installed. Manual configuration will be needed"
    fi
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    main::errhandle_log_info "--- Setting hacluster password"
    echo linux | passwd --stdin hacluster
    main::errhandle_log_info "--- Configure firewall to allow high-availability traffic"
    firewall-cmd --permanent --add-service=high-availability
    firewall-cmd --reload
    main::errhandle_log_info "--- Starting cluster services & enabling on startup"
    systemctl start pcsd.service
    systemctl enable pcsd.service
  fi
  main::complete
}


ha::pacemaker_add_stonith() {
  main::errhandle_log_info "Cluster: Adding STONITH devices"
  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    crm configure primitive STONITH-"${VM_METADATA[sap_primary_instance]}" stonith:external/gcpstonith \
        op monitor interval="300s" timeout="120s" \
        op start interval="0" timeout="60s" \
        params instance_name="${VM_METADATA[sap_primary_instance]}" gcloud_path="${GCLOUD}" logging="yes" \
        pcmk_reboot_timeout=300 pcmk_monitor_retries=4 pcmk_delay_max=30
    crm configure primitive STONITH-"${VM_METADATA[sap_secondary_instance]}" stonith:external/gcpstonith \
        op monitor interval="300s" timeout="120s" \
        op start interval="0" timeout="60s" \
        params instance_name="${VM_METADATA[sap_secondary_instance]}" gcloud_path="${GCLOUD}" logging="yes" \
        pcmk_reboot_timeout=300 pcmk_monitor_retries=4
    crm configure location LOC_STONITH_"${VM_METADATA[sap_primary_instance]}" STONITH-"${VM_METADATA[sap_primary_instance]}" -inf: "${VM_METADATA[sap_primary_instance]}"
    crm configure location LOC_STONITH_"${VM_METADATA[sap_secondary_instance]}" STONITH-"${VM_METADATA[sap_secondary_instance]}" -inf: "${VM_METADATA[sap_secondary_instance]}"
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    pcs stonith create STONITH-"${VM_METADATA[sap_primary_instance]}" fence_gce \
        port="${VM_METADATA[sap_primary_instance]}" zone="${VM_METADATA[sap_primary_zone]}" project="${VM_PROJECT}" \
        pcmk_reboot_timeout=300 pcmk_monitor_retries=4 pcmk_delay_max=30 \
        op monitor interval="300s" timeout="120s" \
        op start interval="0" timeout="60s"
    pcs stonith create STONITH-"${VM_METADATA[sap_secondary_instance]}" fence_gce \
        port="${VM_METADATA[sap_secondary_instance]}" zone="${VM_METADATA[sap_secondary_zone]}" project="${VM_PROJECT}" \
        pcmk_reboot_timeout=300 pcmk_monitor_retries=4 \
        op monitor interval="300s" timeout="120s" \
        op start interval="0" timeout="60s"
    pcs constraint location STONITH-"${VM_METADATA[sap_primary_instance]}" avoids "${VM_METADATA[sap_primary_instance]}"
    pcs constraint location STONITH-"${VM_METADATA[sap_secondary_instance]}" avoids "${VM_METADATA[sap_secondary_instance]}"
  fi
}


ha::pacemaker_add_vip() {
  main::errhandle_log_info "Cluster: Adding virtual IP"
  main::errhandle_log_info "ILB settings" "${VM_METADATA[sap_vip_solution]}" "${VM_METADATA[sap_hc_port]}"
  if [ "${VM_METADATA[sap_vip_solution]}" = "ILB" ]; then
    main::errhandle_log_info "Using an ILB for the VIP"
    if [ "${LINUX_DISTRO}" = "SLES" ]; then
      if zypper in -y socat; then
        crm configure primitive rsc_vip_hc-primary anything params binfile="/usr/bin/socat" cmdline_options="-U TCP-LISTEN:"${VM_METADATA[sap_hc_port]}",backlog=10,fork,reuseaddr /dev/null" op monitor timeout=20s interval=10s op_params depth=0
        crm configure primitive rsc_vip_int-primary IPaddr2 params ip="${VM_METADATA[sap_vip]}" cidr_netmask=32 nic="eth0" op monitor interval=3600s timeout=60s
        crm configure group g-primary rsc_vip_int-primary rsc_vip_hc-primary
      else
        main::errhandle_log_warning "- socat could not be installed, attempting to continue with rest of configuration. Manual configuration will be needed"
      fi
    elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
      pcs resource create rsc_vip_${VM_METADATA[sap_hana_sid]}_${VM_METADATA[sap_hana_instance_number]} \
        IPaddr2 ip="${VM_METADATA[sap_vip]}" nic=eth0 cidr_netmask=32 op monitor interval=3600s timeout=60s
      pcs resource create rsc_healthcheck_${VM_METADATA[sap_hana_sid]} service:haproxy op monitor interval=10s timeout=20s
      pcs resource move rsc_healthcheck_${VM_METADATA[sap_hana_sid]} ${VM_METADATA[sap_primary_instance]}
      pcs resource clear rsc_healthcheck_${VM_METADATA[sap_hana_sid]}
      pcs resource group add g-primary rsc_healthcheck_${VM_METADATA[sap_hana_sid]} rsc_vip_${VM_METADATA[sap_hana_sid]}_${VM_METADATA[sap_hana_instance_number]}
    fi
  else
    if ! ping -c 1 -W 1 "${VM_METADATA[sap_vip]}"; then
      if [ "${LINUX_DISTRO}" = "SLES" ]; then
        crm configure primitive rsc_vip_int-primary IPaddr2 params ip="${VM_METADATA[sap_vip]}" cidr_netmask=32 nic="eth0" op monitor interval=3600s timeout=60s
        if [[ -n "${VM_METADATA[sap_vip_secondary_range]}" ]]; then
          crm configure primitive rsc_vip_gcp-primary ocf:gcp:alias op monitor interval="60s" timeout="60s" op start interval="0" timeout="600s" op stop interval="0" timeout="180s" params alias_ip="${VM_METADATA[sap_vip]}/32" hostlist="${VM_METADATA[sap_primary_instance]} ${VM_METADATA[sap_secondary_instance]}" gcloud_path="${GCLOUD}" alias_range_name="${VM_METADATA[sap_vip_secondary_range]}" logging="yes" meta priority=10
        else
          crm configure primitive rsc_vip_gcp-primary ocf:gcp:alias op monitor interval="60s" timeout="60s" op start interval="0" timeout="600s" op stop interval="0" timeout="180s" params alias_ip="${VM_METADATA[sap_vip]}/32" hostlist="${VM_METADATA[sap_primary_instance]} ${VM_METADATA[sap_secondary_instance]}" gcloud_path="${GCLOUD}" logging="yes" meta priority=10
        fi
        crm configure group g-primary rsc_vip_int-primary rsc_vip_gcp-primary
      fi
    else
      main::errhandle_log_warning "VIP is already associated with another VM. The cluster setup will continue but the floating/virtual IP address will not be added"
    fi
  fi
}


ha::pacemaker_config_bootstrap_hdb() {
  main::errhandle_log_info "Cluster: Configuring bootstrap for SAP HANA"
  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    crm configure property stonith-timeout="300s"
    crm configure property stonith-enabled="true"
    crm configure rsc_defaults resource-stickiness="1000"
    crm configure rsc_defaults migration-threshold="5000"
    crm configure op_defaults timeout="600"
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    main::errhandle_log_info "--- Setting cluster defaults"
    # as per documentation
    pcs resource defaults resource-stickiness=1000
    pcs resource defaults migration-threshold=5000
    pcs property set stonith-enabled="true"
    # increase from default 60
    pcs property set stonith-timeout="300s"
    # increase from default 20
    pcs resource op defaults timeout="600s"
  fi
}


ha::pacemaker_config_bootstrap_nfs() {
  main::errhandle_log_info "Cluster: Configuring bootstrap for NFS"
  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    crm configure property no-quorum-policy="ignore"
    crm configure property startup-fencing="true"
    crm configure property stonith-timeout="300s"
    crm configure property stonith-enabled="true"
    crm configure rsc_defaults resource-stickiness="100"
    crm configure rsc_defaults migration-threshold="5000"
    crm configure op_defaults timeout="600"
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    pcs property set no-quorum-policy="ignore"
    pcs property set startup-fencing="true"
    pcs property set stonith-timeout="300s"
    pcs property set stonith-enabled="true"
    pcs resource defaults default-resource-stickness=1000
    pcs resource defaults default-migration-threshold=5000
    pcs resource op defaults timeout=600s
  fi
}


ha::pacemaker_add_hana() {
  main::errhandle_log_info "Cluster: Creating HANA resources (SAPHanaTopology, SAPHana)"

  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    cat <<EOF > /root/.deploy/cluster.tmp
    primitive rsc_SAPHanaTopology_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]} ocf:suse:SAPHanaTopology \
        operations \$id="rsc_sap2_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]}-operations" \
        op monitor interval="10" timeout="600" \
        op start interval="0" timeout="600" \
        op stop interval="0" timeout="300" \
        params SID="${VM_METADATA[sap_hana_sid]}" InstanceNumber="${VM_METADATA[sap_hana_instance_number]}"

    clone cln_SAPHanaTopology_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]} rsc_SAPHanaTopology_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]} \
        meta clone-node-max="1" target-role="Started" interleave="true"
EOF

    crm configure load update /root/.deploy/cluster.tmp

    cat <<EOF > /root/.deploy/cluster.tmp
    primitive rsc_SAPHana_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]} ocf:suse:SAPHana \
        operations \$id="rsc_sap_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]}-operations" \
        op start interval="0" timeout="3600" \
        op stop interval="0" timeout="3600" \
        op promote interval="0" timeout="3600" \
        op demote interval="0" timeout="3600" \
        op monitor interval="60" role="Master" timeout="700" \
        op monitor interval="61" role="Slave" timeout="700" \
        params SID="${VM_METADATA[sap_hana_sid]}" InstanceNumber="${VM_METADATA[sap_hana_instance_number]}" PREFER_SITE_TAKEOVER="true" \
        DUPLICATE_PRIMARY_TIMEOUT="7200" AUTOMATED_REGISTER="true"

    ms msl_SAPHana_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]} rsc_SAPHana_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]} \
        meta notify="true" clone-max="2" clone-node-max="1" \
        target-role="Started" interleave="true"

    colocation col_saphana_ip_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]} 4000: g-primary:Started \
        msl_SAPHana_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]}:Master
    order ord_SAPHana_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]} Optional: cln_SAPHanaTopology_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]} \
        msl_SAPHana_${VM_METADATA[sap_hana_sid]}_HDB${VM_METADATA[sap_hana_instance_number]}
EOF

    crm configure load update /root/.deploy/cluster.tmp

  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    main::errhandle_log_info "Cluster: Creating resources SAPHanaTopology"
    pcs resource create SAPHanaTopology_${VM_METADATA[sap_hana_sid]}_${VM_METADATA[sap_hana_instance_number]} SAPHanaTopology SID=${VM_METADATA[sap_hana_sid]} \
      InstanceNumber=${VM_METADATA[sap_hana_instance_number]} \
      op start timeout=600 \
      op stop timeout=300 \
      op monitor interval=10 timeout=600 \
      clone clone-max=2 clone-node-max=1 interleave=true
    main::errhandle_log_info "Cluster: Creating resources SAPHana and constraints"
    pcs_create_command="pcs resource create SAPHana_${VM_METADATA[sap_hana_sid]}_${VM_METADATA[sap_hana_instance_number]} SAPHana SID=${VM_METADATA[sap_hana_sid]}
        InstanceNumber=${VM_METADATA[sap_hana_instance_number]}
        PREFER_SITE_TAKEOVER=true DUPLICATE_PRIMARY_TIMEOUT=7200 AUTOMATED_REGISTER=true
        op start timeout=3600
        op stop timeout=3600
        op monitor interval=61 role=Slave timeout=700
        op monitor interval=59 role=Master timeout=700
        op promote timeout=3600
        op demote timeout=3600
        REPLACEME meta notify=true clone-max=2 clone-node-max=1 interleave=true"
    pcs_constraint_order="pcs constraint order SAPHanaTopology_${VM_METADATA[sap_hana_sid]}_${VM_METADATA[sap_hana_instance_number]}-clone
        then SAPHana_${VM_METADATA[sap_hana_sid]}_${VM_METADATA[sap_hana_instance_number]}-REPLACEME symmetrical=false"
    pcs_constraint_coloc="pcs constraint colocation add g-primary
        with master SAPHana_${VM_METADATA[sap_hana_sid]}_${VM_METADATA[sap_hana_instance_number]}-REPLACEME 4000"
    if [ "${LINUX_MAJOR_VERSION}" = "7" ]; then
      ${pcs_create_command/REPLACEME/master}
      ${pcs_constraint_order/REPLACEME/master}
      ${pcs_constraint_coloc/REPLACEME/master}
    elif [ "${LINUX_MAJOR_VERSION}" = "8" ]; then
      ${pcs_create_command/REPLACEME/promotable}
      ${pcs_constraint_order/REPLACEME/clone}
      ${pcs_constraint_coloc/REPLACEME/clone}
    fi
  fi
}


ha::enable_hdb_hadr_provider_hook() {
  main::errhandle_log_info "Enabling HA/DR provider hook - checking HANA version"
  HANA_MAJOR_VERSION=$(su - "${VM_METADATA[sap_hana_sid],,}"adm HDB version | grep "version:" | awk '{ print $2 }' | awk -F "." '{ print $1 }')
  HANA_MINOR_VERSION=$(expr $(su - "${VM_METADATA[sap_hana_sid],,}"adm HDB version | grep "version:" | awk '{ print $2 }' | awk -F "." '{ print $3 }') + 0)
  main::errhandle_log_info "SAP HANA version returned as ${HANA_MAJOR_VERSION}.${HANA_MINOR_VERSION}"
  if [ "${HANA_MAJOR_VERSION}" -ge 2 -a "${HANA_MINOR_VERSION}" -ge 30 ]; then
    # only used HANA 2 SP3 +
    main::errhandle_log_info "Enabling HA/DR provider hook - HANA version checked"
    su - "${VM_METADATA[sap_hana_sid],,}"adm HDB stop
    mkdir -p /hana/shared/myHooks
    [[ "${LINUX_DISTRO}" = "RHEL" ]] && \
      cp /usr/share/SAPHanaSR/srHook/SAPHanaSR.py /hana/shared/myHooks
    [[ "${LINUX_DISTRO}" = "SLES" ]] && \
      cp /usr/share/SAPHanaSR/SAPHanaSR.py /hana/shared/myHooks
    chown -R "${VM_METADATA[sap_hana_sid],,}"adm:sapsys /hana/shared/myHooks

    cat <<EOF >> /hana/shared/"${VM_METADATA[sap_hana_sid]}"/global/hdb/custom/config/global.ini

[ha_dr_provider_SAPHanaSR]
provider = SAPHanaSR
path = /hana/shared/myHooks
execution_order = 1

[trace]
ha_dr_saphanasr = info
EOF

    [[ "${LINUX_DISTRO}" = "RHEL" ]] && cat <<EOF > /etc/sudoers.d/20-saphana
Cmnd_Alias SITEA_SOK = /usr/sbin/crm_attribute -n hana_${VM_METADATA[sap_hana_sid],,}_site_srHook_${VM_METADATA[sap_primary_instance]} -v SOK -t crm_config -s SAPHanaSR
Cmnd_Alias SITEA_SFAIL = /usr/sbin/crm_attribute -n hana_${VM_METADATA[sap_hana_sid],,}_site_srHook_${VM_METADATA[sap_primary_instance]} -v SFAIL -t crm_config -s SAPHanaSR
Cmnd_Alias SITEB_SOK = /usr/sbin/crm_attribute -n hana_${VM_METADATA[sap_hana_sid],,}_site_srHook_${VM_METADATA[sap_secondary_instance]} -v SOK -t crm_config -s SAPHanaSR
Cmnd_Alias SITEB_SFAIL = /usr/sbin/crm_attribute -n hana_${VM_METADATA[sap_hana_sid],,}_site_srHook_${VM_METADATA[sap_secondary_instance]} -v SFAIL -t crm_config -s SAPHanaSR
${VM_METADATA[sap_hana_sid],,}adm ALL=(ALL) NOPASSWD: SITEA_SOK, SITEA_SFAIL, SITEB_SOK, SITEB_SFAIL
# https://access.redhat.com/solutions/6315931
Defaults!SITEA_SOK, SITEA_SFAIL, SITEB_SOK, SITEB_SFAIL !requiretty
EOF

    [[ "${LINUX_DISTRO}" = "SLES" ]] && cat <<EOF > /etc/sudoers.d/20-saphana
# SAPHanaSR-ScaleUp entries for writing srHook cluster attribute
Cmnd_Alias SOK_SITEA = /usr/sbin/crm_attribute -n hana_${VM_METADATA[sap_hana_sid],,}_site_srHook_${VM_METADATA[sap_primary_instance]} -v SOK -t crm_config -s SAPHanaSR
Cmnd_Alias SFAIL_SITEA = /usr/sbin/crm_attribute -n hana_${VM_METADATA[sap_hana_sid],,}_site_srHook_${VM_METADATA[sap_primary_instance]} -v SFAIL -t crm_config -s SAPHanaSR
Cmnd_Alias SOK_SITEB = /usr/sbin/crm_attribute -n hana_${VM_METADATA[sap_hana_sid],,}_site_srHook_${VM_METADATA[sap_secondary_instance]} -v SOK -t crm_config -s SAPHanaSR
Cmnd_Alias SFAIL_SITEB = /usr/sbin/crm_attribute -n hana_${VM_METADATA[sap_hana_sid],,}_site_srHook_${VM_METADATA[sap_secondary_instance]} -v SFAIL -t crm_config -s SAPHanaSR
${VM_METADATA[sap_hana_sid],,}adm ALL=(ALL) NOPASSWD: SOK_SITEA, SFAIL_SITEA, SOK_SITEB, SFAIL_SITEB
EOF

    su - "${VM_METADATA[sap_hana_sid],,}"adm HDB start
    main::errhandle_log_info "Enabling HA/DR provider hook - configuration completed"
  fi
}


ha::setup_haproxy() {
  if [ "${LINUX_DISTRO}" = "RHEL" -a "${VM_METADATA[sap_vip_solution]}" = "ILB" ]; then
    main::errhandle_log_info "Installing haproxy"
    yum install -y haproxy || main::errhandle_log_warning "- haproxy could not be installed. Manual configuration will be needed"

    main::errhandle_log_info "Configuring haproxy"
    sed -ie '/mode/s/http/tcp/' /etc/haproxy/haproxy.cfg
    sed -ie '/option/s/httplog/tcplog/' /etc/haproxy/haproxy.cfg
    sed -ie 's/option forwardfor/#option forwardfor/' /etc/haproxy/haproxy.cfg
    cat <<EOF >> /etc/haproxy/haproxy.cfg

#---------------------------------------------------------------------
# Health check listener port for SAP HANA HA cluster
#---------------------------------------------------------------------
listen healthcheck
  bind *:${VM_METADATA[sap_hc_port]}
EOF
  fi
}

nw::create_filesystems() {
  if [[ -h /dev/disk/by-id/google-"${HOSTNAME}"-usrsap ]]; then
    main::errhandle_log_info "Creating filesytems for NetWeaver"
    main::create_filesystem /usr/sap usrsap xfs
  fi

  if [[ -h /dev/disk/by-id/google-"${HOSTNAME}"-sapmnt ]]; then
    main::create_filesystem /sapmnt sapmnt xfs
  fi

  if [[ -h /dev/disk/by-id/google-"${HOSTNAME}"-swap ]]; then
    main::create_filesystem swap swap swap
  fi
}

nw-ha::fail_for_rhel() {
  if [ "${LINUX_DISTRO}" = "RHEL" ]; then
    main::errhandle_log_error "Installation on RHEL is not yet supported. Exiting."
  fi
}

nw-ha::create_deploy_directory() {
  if [[ ! -d /root/.deploy ]]; then
    mkdir -p /root/.deploy
  fi
}

nw-ha::enable_ilb_backend_communication() {
  local rc
  local loc_vip
  # Default google-guest-agent configuration file
  local cfg_file=/etc/default/instance_configs.cfg

  main::errhandle_log_info "Enabling load balancer back-end communication between the VMs."

  main::errhandle_log_info "Stopping google-guest-agent for reconfiguration."
  service google-guest-agent stop
  for loc_vip in $(ip route show table local | grep "proto 66" | awk '{print $2}'); do
    ip route del table local ${loc_vip} dev eth0
  done

  if grep "IpForwarding]" ${cfg_file}; then
    sed -i 's/^ip_aliases.*/ip_aliases = true/' ${cfg_file}
    sed -i 's/^target_instance_ips.*/target_instance_ips = false/' ${cfg_file}
  else
    cat << AGT >> ${cfg_file}
[IpForwarding]
ethernet_proto_id = 66
ip_aliases = true
target_instance_ips = false
AGT
  fi

  if grep "NetworkInterfaces]" ${cfg_file}; then
    sed -i 's/^ip_forwarding.*/ip_forwarding = false/' ${cfg_file}
  else
    cat << AGT >> ${cfg_file}
[NetworkInterfaces]
ip_forwarding = false
AGT
  fi

  if service google-guest-agent restart; then
    main::errhandle_log_info "IP settings applied to to the google-guest-agent for load balancing back-end communication."
  else
    main::errhandle_log_warning "The google-guest-agent is not functioning / installed. Load balancing might not work as expected."
  fi

}


nw-ha::create_nfs_directories() {
  local rc
  local dir
  local directories

  directories="
    /mnt/nfs/sapmnt${VM_METADATA[sap_sid]}
    /mnt/nfs/usrsaptrans
    /mnt/nfs/usrsap${VM_METADATA[sap_sid]}${VM_METADATA[sap_ascs]}SCS${VM_METADATA[sap_scs_instance_number]}
    /mnt/nfs/usrsap${VM_METADATA[sap_sid]}"ERS"${VM_METADATA[sap_ers_instance_number]}"

  main::errhandle_log_info "Creating shared NFS directories at '${VM_METADATA[nfs_path]}'."
  mkdir /mnt/nfs
  mount -t nfs "${VM_METADATA[nfs_path]}" /mnt/nfs
  rc=$?
  if [[ "${rc}" -ne 0 ]]; then
    main::errhandle_log_error "Error mounting '${VM_METADATA[nfs_path]}'. Exiting."
  fi

  for dir in ${directories}; do
    if [[ ! -d ${dir} ]]; then
      mkdir "${dir}"
      rc=$?
      if [[ "${rc}" -ne 0 ]]; then
        main::errhandle_log_error "Cannot create directory in '${dir}'. Check permissions or if directory already exists. Exiting."
      else
        main::errhandle_log_info "Directory /mnt/nfs/sapmnt"${dir}" created."
      fi
    else
      main::errhandle_log_warning "Directory /mnt/nfs/sapmnt"${dir}" already existed."
    fi
  done

  umount /mnt/nfs
  rm -rf /mnt/nfs
  main::errhandle_log_info "Shared directories created."
}


nw-ha::configure_shared_file_system() {
  local nfs_opts
  nfs_opts="-rw,relatime,vers=3,hard,proto=tcp,timeo=600,retrans=2,mountvers=3,mountport=2050,mountproto=tcp"

  main::errhandle_log_info "Configuring shared file system."
  mkdir -p /sapmnt/"${VM_METADATA[sap_sid]}"
  mkdir -p /usr/sap/trans
  mkdir -p /usr/sap/"${VM_METADATA[sap_sid]}"/"${VM_METADATA[sap_ascs]}"SCS"${VM_METADATA[sap_scs_instance_number]}"
  mkdir -p /usr/sap/"${VM_METADATA[sap_sid]}"/ERS"${VM_METADATA[sap_ers_instance_number]}"

  echo "/- /etc/auto.sap" | tee -a /etc/auto.master
  echo "/sapmnt/${VM_METADATA[sap_sid]} $nfs_opts ${VM_METADATA[nfs_path]}/sapmnt${VM_METADATA[sap_sid]}" | tee -a /etc/auto.sap
  echo "/usr/sap/trans $nfs_opts ${VM_METADATA[nfs_path]}/usrsaptrans" | tee -a /etc/auto.sap

  systemctl enable autofs
  systemctl restart autofs
  automount -v

  cd /sapmnt/${VM_METADATA[sap_sid]}
  cd /usr/sap/trans
  main::errhandle_log_info "Shared file system configured."
}


nw-ha::update_etc_hosts() {
  local primary_node_ip
  local secondary_node_ip

  main::errhandle_log_info "Updating /etc/hosts."

  primary_node_ip=$(ping "${VM_METADATA[sap_primary_instance]}" -c 1 | head -1 | awk  '{ print $3 }' | sed 's/(//' | sed 's/)//')
  secondary_node_ip=$(ping "${VM_METADATA[sap_secondary_instance]}" -c 1 | head -1 | awk  '{ print $3 }' | sed 's/(//' | sed 's/)//')

  echo "$primary_node_ip ${VM_METADATA[sap_primary_instance]}.$(hostname -d) ${VM_METADATA[sap_primary_instance]}" | tee -a /etc/hosts
  echo "$secondary_node_ip ${VM_METADATA[sap_secondary_instance]}.$(hostname -d) ${VM_METADATA[sap_secondary_instance]}" | tee -a /etc/hosts
  echo "${VM_METADATA[scs_vip_address]} ${VM_METADATA[scs_vip_name]}.$(hostname -d) ${VM_METADATA[scs_vip_name]}" | tee -a /etc/hosts
  echo "${VM_METADATA[ers_vip_address]} ${VM_METADATA[ers_vip_name]}.$(hostname -d) ${VM_METADATA[ers_vip_name]}" | tee -a /etc/hosts

  main::errhandle_log_info "/etc/hosts updated."
}


nw-ha::install_ha_packages() {
  main::errhandle_log_info "Installing HA packages."
  if [[ ${LINUX_DISTRO} = "SLES" ]]; then
    zypper install -t pattern ha_sles
    zypper install -y sap-suse-cluster-connector
    zypper install -y socat
  fi
  if [[ ${LINUX_DISTRO} = "RHEL" ]]; then
    yum install -y pcs pacemaker
    yum install -y fence-agents-gce
    yum install -y resource-agents-gcp
    yum install -y resource-agents-sap
    yum install -y sap-cluster-connector
    yum install -y haproxy
    yum install -y socat
  fi
  main::errhandle_log_info "HA packages installed."
}


nw-ha::pacemaker_create_cluster_primary() {
  main::errhandle_log_info "Creating cluster on primary node."

  main::errhandle_log_info "Initializing cluster."
  if [[ ${LINUX_DISTRO} = "SLES" ]]; then
    ha-cluster-init --name "${VM_METADATA[pacemaker_cluster_name]}" --yes --interface eth0 csync2
    ha-cluster-init --name "${VM_METADATA[pacemaker_cluster_name]}" --yes --interface eth0 corosync
    main::errhandle_log_info "Configuring Corosync ..."
    sed -i 's/token:.*/token: 20000/g' /etc/corosync/corosync.conf
    sed -i '/consensus:/d' /etc/corosync/corosync.conf
    sed -i 's/join:.*/join: 60/g' /etc/corosync/corosync.conf
    sed -i 's/max_messages:.*/max_messages: 20/g' /etc/corosync/corosync.conf
    sed -i 's/token_retransmits_before_loss_const:.*/token_retransmits_before_loss_const: 10/g' /etc/corosync/corosync.conf
    main::errhandle_log_info "Creating the cluster"
    ha-cluster-init --name ${VM_METADATA[pacemaker_cluster_name]} --yes cluster
  fi
  if [[ ${LINUX_DISTRO} = "RHEL" ]]; then
    local hacluster_pass
    # Generate one-shot password for initial setup
    main::errhandle_log_info "Setting up the hacluster user and starting pcsd"
    hacluster_pass=$(cat /dev/urandom | tr -dc '[:alnum:]' | fold -w ${1:-10} | head -n 1)
    echo "hacluster:${hacluster_pass}" | chpasswd
    ssh -o StrictHostKeyChecking=no ${VM_METADATA[sap_secondary_instance]} << EOF
echo hacluster:"${hacluster_pass}" | chpasswd
EOF
    firewall-cmd --permanent --add-service=high-availability
    firewall-cmd --reload
    systemctl start pcsd.service
    systemctl enable pcsd.service
    nw-ha::setup_haproxy

    echo "ready" > /root/.deploy/."${HOSTNAME}".ready

    local count=0
    local max_attempts=30
    local sleep_time=20
    local finished=1

    main::errhandle_log_info "Registering the hosts for the cluster"
    while ! [ ${finished} -eq 0 ]; do
      if [[ $LINUX_MAJOR_VERSION -ge 8 ]]; then
        if pcs host auth ${VM_METADATA[sap_primary_instance]} ${VM_METADATA[sap_secondary_instance]} -u hacluster -p ${hacluster_pass}; then
          main::errhandle_log_info "Hosts registered for the cluster."
          finished=0
        fi
      fi
      if [[ $LINUX_MAJOR_VERSION -le 7 ]]; then
        if pcs cluster auth ${VM_METADATA[sap_primary_instance]} ${VM_METADATA[sap_secondary_instance]} -u hacluster -p ${hacluster_pass}; then
          main::errhandle_log_info "Hosts registered for the cluster."
          finished=0
        fi
      fi
      count=$((count +1))
      main::errhandle_log_info "pcsd.service not yet started on secondary - retrying in ${sleep_time} seconds (attempt number ${count} of max ${max_attempts})"
      sleep ${sleep_time}s
      if [ ${count} -gt ${max_attempts} ]; then
        main::errhandle_log_error "pcsd.service not started on secondary. Stopping deployment. Check logs on secondary."
      fi
    done

    main::errhandle_log_info "Creating the cluster"
    if [[ $LINUX_MAJOR_VERSION -ge 8 ]]; then
      pcs cluster setup "${VM_METADATA[pacemaker_cluster_name]}" \
        ${VM_METADATA[sap_primary_instance]} ${VM_METADATA[sap_secondary_instance]} \
        totem token=20000 join=60 token_retransmits_before_loss_const=10 max_messages=20
    fi
    if [[ $LINUX_MAJOR_VERSION -le 7 ]]; then
      pcs cluster setup --name "${VM_METADATA[pacemaker_cluster_name]}" \
        ${VM_METADATA[sap_primary_instance]} ${VM_METADATA[sap_secondary_instance]} \
        --token 20000 --join 60
      local cfg_out="/etc/corosync/corosync.conf"
      grep "max_messages:" ${cfg_out} \
        && sed -i 's/max_messages:.*/max_messages: 20/g' ${cfg_out} \
        || sed -i '/token:/a\    max_messages: 20' ${cfg_out}
      grep "token_retransmits_before_loss_const:" ${cfg_out} \
        && sed -i 's/token_retransmits_before_loss_const:.*/token_retransmits_before_loss_const: 10/g' ${cfg_out} \
        || sed -i '/token:/a\    token_retransmits_before_loss_const: 10' ${cfg_out}
    fi
    if [[ ! -f /etc/corosync/corosync.conf ]]; then
      main::errhandle_log_error "/etc/corosync/corosync.conf does not exist. Cluster setup incomplete."
    fi
    if [[ $LINUX_MAJOR_VERSION -ge 8 ]]; then
      sed -i 's/transport:.*/transport: knet/g' /etc/corosync/corosync.conf
    fi
    pcs cluster sync
    pcs cluster enable --all
    pcs cluster stop --all
    pcs cluster start --all
  fi
  main::errhandle_log_info "Setting general cluster properties."
  if [[ ${LINUX_DISTRO} = "SLES" ]]; then
    crm configure property stonith-timeout="300s"
    crm configure property stonith-enabled="true"
    crm configure rsc_defaults resource-stickiness="1"
    crm configure rsc_defaults migration-threshold="3"
    crm configure op_defaults timeout="600"
  fi
  if [[ ${LINUX_DISTRO} = "RHEL" ]]; then
    if [[ $LINUX_MAJOR_VERSION -ge 8 ]]; then
      pcs resource defaults update resource-stickiness="1"
      pcs resource defaults update migration-threshold="3"
    fi
    if [[ $LINUX_MAJOR_VERSION -le 7 ]]; then
      pcs resource defaults resource-stickiness="1"
      pcs resource defaults migration-threshold="3"
    fi
  fi
  main::errhandle_log_info "Enable and start Pacemaker service"
  systemctl enable pacemaker
  systemctl start pacemaker

  if [[ ${LINUX_DISTRO} = "SLES" ]]; then
    echo "ready" > /root/.deploy/."${HOSTNAME}".ready
  fi

  main::errhandle_log_info "Cluster on primary node created."
}


nw-ha::pacemaker_join_secondary() {
  main::errhandle_log_info "Joining secondary VM to the cluster."
  if [[ ${LINUX_DISTRO} = "SLES" ]]; then
    # Workaround of wrapping 'ha-cluster-join' into ssh calls to own host:
    # Without it, 'ha-cluster-join' commands block commands/functions
    # executed after this function (caused by ssh calls inside 'ha-cluster-join')
    ssh -o StrictHostKeyChecking=no $(hostname) << EOF
ha-cluster-join --cluster-node "${VM_METADATA[sap_primary_instance]}" --yes --interface eth0 csync2
EOF
    ssh $(hostname) << EOF
ha-cluster-join --cluster-node "${VM_METADATA[sap_primary_instance]}" --yes ssh_merge
EOF
    ssh $(hostname) << EOF
ha-cluster-join --cluster-node "${VM_METADATA[sap_primary_instance]}" --yes cluster
EOF
  fi

  if [[ ${LINUX_DISTRO} = "RHEL" ]]; then
    # RHEL secondary would be triggered from primary
    # validate that cluster is online
    firewall-cmd --permanent --add-service=high-availability
    firewall-cmd --reload
    systemctl start pcsd.service
    systemctl enable pcsd.service
    pcs cluster sync
    sleep 10
    systemctl restart corosync
    nw-ha::setup_haproxy
  fi

  echo "ready" > /root/.deploy/."${HOSTNAME}".ready

  main::errhandle_log_info "Enable and start Pacemaker."
  systemctl enable pacemaker
  #Retry startup in case there's still initialization
  local retrycount=5
  while [[ retrycount -gt 0 ]]; do
    if systemctl start pacemaker; then
      main::errhandle_log_info "Pacemaker started on secondary."
      break
    else
      let retrycount-=1
      if [[ retrycount -gt 0 ]]; then
        main::errhandle_log_warning "Pacemaker could not be started on secondary yet. Retrying."
        sleep 30
      else
        main::errhandle_log_error "Pacemaker could not be started on secondary. Aborting."
        # Error routine will handle exit
      fi
    fi
  done
  main::errhandle_log_info "Secondary VM joined the cluster."
}


nw-ha::create_fencing_resources() {
  local pri_suffix
  local sec_suffix

  main::errhandle_log_info "Adding fencing resources."

  pri_suffix="${VM_METADATA[sap_sid]}-${VM_METADATA[sap_primary_instance]}"
  sec_suffix="${VM_METADATA[sap_sid]}-${VM_METADATA[sap_secondary_instance]}"

  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    crm configure primitive "fence-${pri_suffix}" stonith:fence_gce \
      op monitor interval="300s" timeout="120s" \
      op start interval="0" timeout="60s" \
      params port="${VM_METADATA[sap_primary_instance]}" \
      zone="${VM_METADATA[sap_primary_zone]}" project="${VM_PROJECT}" \
      pcmk_reboot_timeout=300 pcmk_monitor_retries=4 pcmk_delay_max=30

    crm configure location "loc-fence-${pri_suffix}" "fence-${pri_suffix}" \
                           -inf: "${VM_METADATA[sap_primary_instance]}"

    crm configure primitive "fence-${sec_suffix}" stonith:fence_gce \
      op monitor interval="300s" timeout="120s" \
      op start interval="0" timeout="60s" \
      params port="${VM_METADATA[sap_secondary_instance]}" \
      zone="${VM_METADATA[sap_secondary_zone]}" project="${VM_PROJECT}" \
      pcmk_reboot_timeout=300 pcmk_monitor_retries=4

    crm configure location "loc-fence-${sec_suffix}" "fence-${sec_suffix}" \
                           -inf: "${VM_METADATA[sap_secondary_instance]}"
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    pcs stonith create "fence-${pri_suffix}" fence_gce \
        port="${VM_METADATA[sap_primary_instance]}" \
        zone="${VM_METADATA[sap_primary_zone]}" project="${VM_PROJECT}" \
        pcmk_reboot_timeout=300 pcmk_monitor_retries=4 pcmk_delay_max=30 \
        op monitor interval="300s" timeout="120s" \
        op start interval="0" timeout="60s"
    pcs stonith create "fence-${sec_suffix}" fence_gce \
        port="${VM_METADATA[sap_secondary_instance]}" \
        zone="${VM_METADATA[sap_secondary_zone]}" project="${VM_PROJECT}" \
        pcmk_reboot_timeout=300 pcmk_monitor_retries=4 \
        op monitor interval="300s" timeout="120s" \
        op start interval="0" timeout="60s"
    pcs constraint location "fence-${pri_suffix}" avoids "${VM_METADATA[sap_primary_instance]}"
    pcs constraint location "fence-${sec_suffix}" avoids "${VM_METADATA[sap_secondary_instance]}"
  fi

  main::errhandle_log_info "Fencing resources added."
}


nw-ha::create_file_system_resources() {
  main::errhandle_log_info "Adding file system resources."
  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    crm configure primitive \
      "file-system-${VM_METADATA[sap_sid]}-${VM_METADATA[sap_ascs]}SCS${VM_METADATA[sap_scs_instance_number]}" \
      Filesystem \
      device="${VM_METADATA[nfs_path]}/usrsap${VM_METADATA[sap_sid]}${VM_METADATA[sap_ascs]}SCS${VM_METADATA[sap_scs_instance_number]}" \
      directory="/usr/sap/${VM_METADATA[sap_sid]}/${VM_METADATA[sap_ascs]}SCS${VM_METADATA[sap_scs_instance_number]}" \
      fstype="nfs" \
      op start timeout=60s interval=0 \
      op stop timeout=60s interval=0 \
      op monitor interval=20s timeout=40s

    crm configure primitive \
      file-system-"${VM_METADATA[sap_sid]}-ERS${VM_METADATA[sap_ers_instance_number]}" \
      Filesystem \
      device="${VM_METADATA[nfs_path]}/usrsap${VM_METADATA[sap_sid]}ERS${VM_METADATA[sap_ers_instance_number]}" \
      directory="/usr/sap/${VM_METADATA[sap_sid]}/ERS${VM_METADATA[sap_ers_instance_number]}" \
      fstype="nfs" \
      op start timeout=60s interval=0 \
      op stop timeout=60s interval=0 \
      op monitor interval=20s timeout=40s
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    pcs resource create \
      file-system-"${VM_METADATA[sap_sid]}-${VM_METADATA[sap_ascs]}SCS${VM_METADATA[sap_scs_instance_number]}" \
      Filesystem \
      device="${VM_METADATA[nfs_path]}/usrsap${VM_METADATA[sap_sid]}${VM_METADATA[sap_ascs]}SCS${VM_METADATA[sap_scs_instance_number]}" \
      directory="/usr/sap/${VM_METADATA[sap_sid]}/${VM_METADATA[sap_ascs]}SCS${VM_METADATA[sap_scs_instance_number]}" \
      fstype="nfs" \
      op start timeout=60s interval=0 \
      op stop timeout=60s interval=0 \
      op monitor interval=20s timeout=40s
    pcs resource create \
      file-system-"${VM_METADATA[sap_sid]}-ERS${VM_METADATA[sap_ers_instance_number]}" \
      Filesystem \
      device="${VM_METADATA[nfs_path]}/usrsap${VM_METADATA[sap_sid]}ERS${VM_METADATA[sap_ers_instance_number]}" \
      directory="/usr/sap/${VM_METADATA[sap_sid]}/ERS${VM_METADATA[sap_ers_instance_number]}" \
      fstype="nfs" \
      op start timeout=60s interval=0 \
      op stop timeout=60s interval=0 \
      op monitor interval=20s timeout=40s
  fi
  main::errhandle_log_info "File system resources added."
}

nw-ha::setup_haproxy() {
  if [ "${LINUX_DISTRO}" = "RHEL" ]; then
    main::errhandle_log_info "Configuring haproxy"
    which haproxy || main::errhandle_log_error "haproxy is not installed. Manual configuration will be needed for a healthcheck service"

    ## Set up health check target
    main::errhandle_log_info "Installing haproxy -- setting up systemd files"
    cp /usr/lib/systemd/system/haproxy.service /etc/systemd/system/haproxy@.service
    sed -i 's/HAProxy Load Balancer/HAProxy Load Balancer \%i/' /etc/systemd/system/haproxy\@.service
    sed -i 's/haproxy.cfg/haproxy-\%i.cfg/' /etc/systemd/system/haproxy\@.service
    sed -i 's/haproxy.pid/haproxy-\%i.pid/' /etc/systemd/system/haproxy\@.service

    main::errhandle_log_info "Installing haproxy -- creating configuration files"
    for type in ${VM_METADATA[sap_ascs]}SCS ERS; do
      cat <<- EOF > /etc/haproxy/haproxy-"${VM_METADATA[sap_sid]}${type}".cfg
global
    chroot      /var/lib/haproxy
    pidfile     /var/run/haproxy-%i.pid
    user        haproxy
    group       haproxy
    daemon
defaults
    mode                    tcp
    log                     global
    option                  dontlognull
    option                  redispatch
    retries                 3
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout check           10s
    maxconn                 3000
EOF

      echo "# Listener for SAP healthcheck" >> /etc/haproxy/haproxy-"${VM_METADATA[sap_sid]}${type}".cfg
      echo "listen healthcheck" >> /etc/haproxy/haproxy-"${VM_METADATA[sap_sid]}${type}".cfg
      if [[ $type == "ERS" ]]; then
        echo "   bind *:${VM_METADATA[ers_hc_port]}" >> /etc/haproxy/haproxy-"${VM_METADATA[sap_sid]}${type}".cfg
      else
        echo "   bind *:${VM_METADATA[scs_hc_port]}" >> /etc/haproxy/haproxy-"${VM_METADATA[sap_sid]}${type}".cfg
      fi
    done
  fi
}

nw-ha::create_health_check_resources() {
  main::errhandle_log_info "Adding health check resources."
  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    crm configure primitive \
      "health-check-${VM_METADATA[sap_sid]}-${VM_METADATA[sap_ascs]}SCS${VM_METADATA[sap_scs_instance_number]}" anything \
      params binfile="/usr/bin/socat" \
      cmdline_options="-U TCP-LISTEN:${VM_METADATA[scs_hc_port]},backlog=10,fork,reuseaddr /dev/null" \
      op monitor timeout=20s interval=10s \
      op_params depth=0

    crm -F configure primitive "health-check-${VM_METADATA[sap_sid]}-ERS${VM_METADATA[sap_ers_instance_number]}" anything \
      params binfile="/usr/bin/socat" \
      cmdline_options="-U TCP-LISTEN:${VM_METADATA[ers_hc_port]},backlog=10,fork,reuseaddr /dev/null" \
      op monitor timeout=20s interval=10s \
      op_params depth=0
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    pcs resource create "health-check-${VM_METADATA[sap_sid]}-${VM_METADATA[sap_ascs]}SCS${VM_METADATA[sap_scs_instance_number]}" \
      service:haproxy@${VM_METADATA[sap_sid]}${VM_METADATA[sap_ascs]}SCS \
      op monitor interval=10s timeout=20s
    pcs resource create "health-check-${VM_METADATA[sap_sid]}-ERS${VM_METADATA[sap_ers_instance_number]}" \
      service:haproxy@${VM_METADATA[sap_sid]}ERS \
      op monitor interval=10s timeout=20s
  fi

  main::errhandle_log_info "Health check resources added."
}


nw-ha::create_vip_resources() {
  main::errhandle_log_info "Adding VIP resources."
  if [ "${LINUX_DISTRO}" = "SLES" ]; then
    crm configure primitive \
      "vip-${VM_METADATA[sap_sid]}-${VM_METADATA[sap_ascs]}SCS${VM_METADATA[sap_scs_instance_number]}" \
      IPaddr2 \
      params ip=${VM_METADATA[scs_vip_address]} cidr_netmask=32 nic="eth0" \
      op monitor interval=3600s timeout=60s

    crm configure primitive \
      "vip-${VM_METADATA[sap_sid]}-ERS${VM_METADATA[sap_ers_instance_number]}" \
      IPaddr2 \
      params ip=${VM_METADATA[ers_vip_address]} cidr_netmask=32 nic="eth0" \
      op monitor interval=3600s timeout=60s
  elif [ "${LINUX_DISTRO}" = "RHEL" ]; then
    pcs resource create \
      "vip-${VM_METADATA[sap_sid]}-${VM_METADATA[sap_ascs]}SCS${VM_METADATA[sap_scs_instance_number]}" \
      IPaddr2 \
      ip=${VM_METADATA[scs_vip_address]} cidr_netmask=32 nic="eth0" \
      op monitor interval=3600s timeout=60s

    pcs resource create \
      "vip-${VM_METADATA[sap_sid]}-ERS${VM_METADATA[sap_ers_instance_number]}" \
      IPaddr2 \
      ip=${VM_METADATA[ers_vip_address]} cidr_netmask=32 nic="eth0" \
      op monitor interval=3600s timeout=60s
  fi
  main::errhandle_log_info "VIP resources added."
}
#!/bin/bash

# send_metrics should generally be called from a sub-shell. It should never exit the main process.
metrics::send_metric() {(  #Exits will only exit the sub-shell.
    local SKIP_LOG_DENY_LIST=("510599941441" "1038306394601" "714149369409" "161716815775" "607888266690" "863817768072" "450711760461" "600915385160" "114837167255" "39979408140" "155261204042" "922508251869" "208472317671" "824757391322" "977154783768" "148036532291" "425380551487" "811811474621" "975534532604" "475132212764" "201338458013" "269972924358" "400774613146" "977154783768" "425380551487" "783555621715" "182593831895" "1042063780714" "1001412328766" "148036532291" "135217527788" "444363138560" "116074023633" "545763614633" "528626677366" "871521991065" "271532348354" "706203752296" "742377328177" "756002114100" "599169460194" "880648352583" "973107100758" "783641913733" "355955620782" "653441306135" "703965468432" "381292615623", "605897091243")

    local NUMERIC_VM_PROJECT=$(main::get_metadata "http://169.254.169.254/computeMetadata/v1/project/numeric-project-id")
    local VM_IMAGE_FULL=$(main::get_metadata "http://169.254.169.254/computeMetadata/v1/instance/image")
    local VM_ZONE=$(main::get_metadata "http://169.254.169.254/computeMetadata/v1/instance/zone" | cut -d / -f 4 )
    local VM_NAME=$(main::get_metadata "http://169.254.169.254/computeMetadata/v1/instance/name")
    local METADATA_URL="https://compute.googleapis.com/compute/v1/projects/${VM_PROJECT}/zones/${VM_ZONE}/instances/${VM_NAME}"

    while getopts 's:n:v:e:u:c:p:' argv; do
        case "${argv}" in
        s) status="${OPTARG}";;
        e) error_id="${OPTARG}";;
        u) updated_version="${OPTARG}";;
        c) action_id="${OPTARG}";;
        esac
    done

    if [[ -z "${VM_METADATA[template-type]}" ]]; then
        VM_METADATA[template-type]="UNKNOWN"
    fi
    if [[ -z "${TEMPLATE_NAME}" ]]; then
        TEMPLATE_NAME="UNSET"
    fi

    metrics::validate "${status}" "Missing required status (-s) argument."
    # We don't want to log our own test runs:
    if [[ " ${SKIP_LOG_DENY_LIST[*]} " == *" ${NUMERIC_VM_PROJECT} "* ]]; then
        echo "Not logging metrics this is an internal project."
        exit 0
    fi
    if [[ $VM_IMAGE_FULL =~ ^projects/(centos-cloud|cos-cloud|debian-cloud|fedora-coreos-cloud|rhel-cloud|rhel-sap-cloud|suse-cloud|suse-sap-cloud|ubuntu-os-cloud|ubuntu-os-pro-cloud|windows-cloud|windows-sql-cloud)/global/images/.+$ ]]; then
        VM_IMAGE=$(echo "${VM_IMAGE_FULL}" | cut -d / -f 5)
    else
        VM_IMAGE="unknown"
    fi

    # If IDs are not numeric, we blank them out
    digit_re='^[0-9]+$'
    if ! [[ $error_id =~ $digit_re ]] ; then
        error_id=0
    fi
    if ! [[ $action_id =~ $digit_re ]] ; then
        action_id=0
    fi

    local template_id="${VM_METADATA[template-type]}-${TEMPLATE_NAME}"
    case $status in
    RUNNING|STARTED|STOPPED|CONFIGURED|MISCONFIGURED|INSTALLED|UNINSTALLED)
        user_agent="sap-core-eng/accelerator-template/2.0.2023021506521676472763/${VM_IMAGE}/${status}"
        ;;
    ERROR)
        metrics::validate "${error_id}" "'ERROR' statuses require the error message (-e) argument."
        user_agent="sap-core-eng/accelerator-template/2.0.2023021506521676472763/${VM_IMAGE}/${status}/${error_id}-${template_id}"
        ;;
    UPDATED)
        metrics::validate "${updated_version}" "'UPDATED' statuses require the updated version (-u) argument."
        user_agent="sap-core-eng/accelerator-template/2.0.2023021506521676472763/${VM_IMAGE}/${status}/${updated_version}"
        ;;
    ACTION)
        metrics::validate "${action_id}" "'ACTION' statuses require the action id (-c) argument."
        user_agent="sap-core-eng/accelerator-template/2.0.2023021506521676472763/${VM_IMAGE}/${status}/${action_id}"
        ;;
    TEMPLATEID)
        user_agent="sap-core-eng/accelerator-template/2.0.2023021506521676472763/${VM_IMAGE}/ACTION/${template_id}"
        ;;
    *)
        echo "Error, valid status must be provided."
        exit 0
    esac

    local curlToken=$(metrics::get_token)
    curl --fail -H "Authorization: Bearer ${curlToken}" -A "${user_agent}" "${METADATA_URL}"
)}


metrics::validate () {
    variable="$1"
    validate_message="$2"
    if [[ -z "${variable}" ]]; then
        echo "${validate_message}"
        exit 0
    fi
}

metrics::get_token() {
    if command -v jq>/dev/null; then
        TOKEN=$(curl --fail -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | jq -r '.access_token')
    elif command -v python>/dev/null; then
        TOKEN=$(curl --fail -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | python -c "import sys, json; print(json.load(sys.stdin)['access_token'])")
    elif command -v python3>/dev/null; then
        TOKEN=$(curl --fail -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")
    else
        echo "Failed to retrieve token, metrics logging requires either Python, Python3, or jq."
        exit 0
    fi
    echo "${TOKEN}"
}

##########################################################################
## End includes
##########################################################################

# Set additional global constants
sleep "60"
readonly PRIMARY_NODE_IP=$(gcloud compute instances list --format="csv[no-heading](INTERNAL_IP)"  --filter="name=(aigascs-ers1)" --project=aig-sap-dev)
readonly SECONDARY_NODE_IP=$(gcloud compute instances list --format="csv[no-heading](INTERNAL_IP)"  --filter="name=(aigascs-ers2)" --project=aig-sap-dev)
echo "${PRIMARY_NODE_IP} aigascs-ers1" >> /etc/hosts
echo "${SECONDARY_NODE_IP} aigascs-ers2" >> /etc/hosts




## Base configuration
main::get_os_version
main::install_gsdk /usr/local
main::set_boot_parameters
main::install_packages
main::config_ssh
main::get_settings
main::send_start_metrics
main::create_static_ip

## Prepare for NetWeaver
nw::create_filesystems
main::install_monitoring_agent

## Setup HA
nw-ha::create_deploy_directory
ha::install_secondary_sshkeys
nw-ha::create_nfs_directories
nw-ha::configure_shared_file_system
nw-ha::enable_ilb_backend_communication
nw-ha::update_etc_hosts
nw-ha::install_ha_packages
nw-ha::pacemaker_create_cluster_primary
ha::wait_for_secondary "nw_ha"
ha::pacemaker_maintenance true
nw-ha::create_fencing_resources
nw-ha::create_file_system_resources
nw-ha::create_health_check_resources
nw-ha::create_vip_resources
ha::pacemaker_maintenance false

## Post deployment & installation cleanup
main::complete