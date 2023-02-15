#!/bin/python3
import csv
import random
import subprocess
import sys
import time
import os


project_id = ""


print(sys.argv[1:])

if sys.argv[1:][0] == 'sn':
    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        random_id = random.randint(1000, 9999)
        for row in datareader:
            session_id = random_id
            disk_name = row[0]
            disk_zone = row[1]
            project_id = row[2]
            print(
                f"SESSION ID ##{random_id}## DISK NAME : {disk_name} DISK ZONE : {disk_zone} PROJECT ID : {project_id}")
            subprocess.Popen(
                ['/bin/bash', '-c', f'gcloud beta compute snapshots create {disk_name}-adhoc-dontdelete{random_id} --source-disk={disk_name} --source-disk-zone={disk_zone} --project={project_id} --labels=key=adhoc'])
            time.sleep(3)

elif sys.argv[1:][0] == 'mi':
    print('welcome to machine image')
    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        random_id = random.randint(1000, 9999)
        for row in datareader:
            session_id = random_id
            VM_name = row[0]
            VM_zone = row[1]
            VM_ACTION_NAME = row[2]
            project_id = row[3]
            print(
                f"SESSION ID ##{random_id}## DISK NAME : {VM_name} DISK ZONE : {VM_zone} PROJECT ID : {project_id}")
            subprocess.Popen(
                ['/bin/bash', '-c', f'gcloud beta compute machine-images create {VM_name}-{VM_ACTION_NAME}-{random_id} --source-instance={VM_name} --source-instance-zone={VM_zone} --project={project_id} --description={VM_ACTION_NAME}'])
            time.sleep(3)

##############
elif sys.argv[1:][0] == 'delete-mi':
    print('welcome to delete machine image')
    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        random_id = random.randint(1000, 9999)
        for row in datareader:
            session_id = random_id
            disk_name = row[0]
            disk_zone = row[1]
            project_id = row[2]
            print(
                f"SESSION ID ##{random_id}## DISK NAME : {disk_name} DISK ZONE : {disk_zone} PROJECT ID : {project_id}")
            subprocess.Popen(
                ['/bin/bash', '-c', f'gcloud beta compute machine-images delete {disk_name} --project={project_id} -q'])
            time.sleep(3)
##############
elif sys.argv[1:][0] == 'delete-sn':
    print('welcome to delete machine image')
    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        random_id = random.randint(1000, 9999)
        for row in datareader:
            session_id = random_id
            disk_name = row[0]
            disk_zone = row[1]
            project_id = row[2]
            print(
                f"SESSION ID ##{random_id}## DISK NAME : {disk_name} DISK ZONE : {disk_zone} PROJECT ID : {project_id}")
            subprocess.Popen(
                ['/bin/bash', '-c', f'gcloud beta compute snapshots delete {disk_name}  --project={project_id} -q'])
            time.sleep(3)


##############
elif sys.argv[1:][0] == 'list-mi':
    subprocess.run(['/bin/bash', '-c', f'mkdir machine-images'])
    print('welcome to list machine image')
    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        for row in datareader:
            project_id = row[0]
            subprocess.Popen(['/bin/bash', '-c', f'mkdir {project_id} && gcloud beta compute machine-images list --format="csv[no-heading](NAME)" --project={project_id} > {project_id}/{project_id}-machine-images.csv'])
            time.sleep(1)

    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        for row in datareader:
            project_id = row[0]
            filename_tow = f'{project_id}/{project_id}-machine-images.csv'
            print(f'{filename_tow}')
            with open(filename_tow, 'r') as csvfile_tow:
                datareader_tow = csv.reader(csvfile_tow)
                for i in datareader_tow:
                    mi_name = i[0]
                    subprocess.run(['/bin/bash', '-c', f'gcloud compute machine-images describe {mi_name} --format="csv[no-heading](sourceInstance.scope(sourceInstance),name,creation_timestamp,totalStorageBytes,storageLocations)" --project={project_id} >> machine-images/{project_id}-machine-images.csv'])
                    time.sleep(1)

    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        for row in datareader:
            project_id = row[0]
            subprocess.run(['/bin/bash', '-c', f'rm -rf {project_id}'])
            time.sleep(1)

##############
elif sys.argv[1:][0] == 'add-resource-policies-to-vm':
    print('welcome to add add-resource-policies to vm')
    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        for row in datareader:
            vm_name = row[0]
            vm_zone = row[1]
            disk_policy = row[2]
            project_id = row[3] 
            subprocess.run(['/bin/bash', '-c', f'gcloud compute disks list --format="csv[no-heading](NAME,users.basename(),zone.basename())" --project={project_id} > {project_id}-disks.csv'])
            with open(f'{project_id}-disks.csv', 'r') as csvfile_tow:
                    datareader_tow = csv.reader(csvfile_tow)
                    for row in datareader_tow:
                        DISK_NAME = row[0]
                        DISK_USER = row[1]
                        DISK_ZONE = row[2]
                        subprocess.Popen(['/bin/bash', '-c', f'gcloud compute disks add-resource-policies {DISK_NAME} --resource-policies={disk_policy} --zone={DISK_ZONE} --project={project_id}'])
            subprocess.run(['/bin/bash', '-c', f'rm -rf {project_id}-disks.csv'])
##############
elif sys.argv[1:][0] == 'add-resource-policies-to-disks':
    print('welcome to add add-resource-policies to vm')
    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile_tow:
            datareader_tow = csv.reader(csvfile_tow)
            for row in datareader_tow:
                DISK_NAME = row[0]
                Disk_Policy = row[1]
                DISK_ZONE = row[2]
                project_id = row[3]
                subprocess.run(['/bin/bash', '-c', f'gcloud compute disks add-resource-policies {DISK_NAME} --resource-policies={Disk_Policy} --zone={DISK_ZONE} --project={project_id}'])
                
#####################################################                  
elif sys.argv[1:][0] == 'remove-resource-policies-to-disks':
    print('welcome to remove remove-resource-policies to disks')
    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile_tow:
            datareader_tow = csv.reader(csvfile_tow)
            for row in datareader_tow:
                DISK_NAME = row[0]
                DISK_ZONE = row[1]
                project_id = row[2]
                subprocess.Popen(['/bin/bash', '-c', f'OLDBOOT_DISK_LICENSE=$(gcloud beta compute disks describe {DISK_NAME} --zone={DISK_ZONE} --project={project_id} --format="csv[no-heading](resourcePolicies.basename())") && gcloud compute disks remove-resource-policies {DISK_NAME} --resource-policies=$OLDBOOT_DISK_LICENSE --zone={DISK_ZONE} --project={project_id}'])
#####################################################                  
elif sys.argv[1:][0] == 'remove-sn-schdule-from-disks-and-delete-sn':
    print('welcome to remove resource-policies ad snapshots for disks')
    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile_tow:
            datareader_tow = csv.reader(csvfile_tow)
            for row in datareader_tow:
                DISK_NAME = row[0]
                DISK_ZONE = row[1]
                project_id = row[2]
                subprocess.run(['/bin/bash', '-c', f'OLDBOOT_DISK_LICENSE=$(gcloud beta compute disks describe {DISK_NAME} --zone={DISK_ZONE} --project={project_id} --format="csv[no-heading](resourcePolicies.basename())") && gcloud compute disks remove-resource-policies {DISK_NAME} --resource-policies=$OLDBOOT_DISK_LICENSE --zone={DISK_ZONE} --project={project_id}'])
                cmd = f'gcloud compute snapshots list --filter="sourceDisk={DISK_NAME}" --format="value(name)" --project={project_id}'
                output = subprocess.check_output(cmd, shell=True).decode('utf-8')
                snapshots = output.split('\n')[:-1]  # remove last empty item
                print(f'Found {len(snapshots)} snapshots for disk {DISK_NAME}')
                print(snapshots)
                with open(f'{project_id}-snapshots.csv', 'a', newline='') as csvfile:
                    writer = csv.writer(csvfile)
                    writer.writerow([DISK_NAME, len(snapshots)] + snapshots)
                for snapshot in snapshots:
                    cmd2 = f'gcloud compute snapshots delete {snapshot} --quiet --project={project_id}'
                    subprocess.run(cmd2, shell=True)
                    print(f'Deleted {len(snapshots)} snapshots for disk {DISK_NAME}')
                with open(f'{project_id}-deleted-snapshots.csv', 'a', newline='') as csvfile2:
                    writer = csv.writer(csvfile2)
                    writer.writerow([DISK_NAME, len(snapshots)] + snapshots)

#####################################################
elif sys.argv[1:][0] == 'create-mi-to-anther-project':
    print('welcome to create mi to anther project')
    Source_Project_id = input("Please Enter SORCE PROJECT ID:")
    target_project_id = input("Please Enter TARGET PROJECT ID:")
    cmd = f'gcloud compute instances list --format="csv[no-heading](NAME,ZONE)" --project={Source_Project_id}'
    output = subprocess.check_output(cmd, shell=True).decode('utf-8')
    InstancesLIST = output.split('\n')[:-1]  # remove last empty item
    VMS = csv.reader(InstancesLIST)
    for VM in VMS:
        VM_NAME = VM[0]
        VM_ZONE = VM[1]
        MI_NAME = f'{VM_NAME}-moved-from-{Source_Project_id}'
        # define the fixed column width
        column_width = 30
        # format the variables with a fixed width
        vm_name_TABLE = '{:<{width}}'.format(VM_NAME, width=column_width)
        source_project_id_TABLE = '{:<{width}}'.format(Source_Project_id, width=column_width)
        target_project_id_TABLE = '{:<{width}}'.format(target_project_id, width=column_width)
        cmd2 = f'gcloud compute machine-images create {MI_NAME} --source-instance="projects/{Source_Project_id}/zones/{VM_ZONE}/instances/{VM_NAME}"  --project={target_project_id}'
        subprocess.run(cmd2, shell=True)
        LOGS = f'| Machine - image create from VM: {vm_name_TABLE} | sorce Project: {source_project_id_TABLE} | in target Project: {target_project_id_TABLE} |'
        LOGST = f'Machine - image create from VM: {vm_name_TABLE},sorce Project: {source_project_id_TABLE},in target Project: {target_project_id_TABLE},'
        LOGSFILEPATH = f'LOGS-for-Created-MI-IN-{target_project_id}-from-{Source_Project_id}.csv'
        print(f'{LOGS}')
#        with open(f'{LOGSFILEPATH}', 'a', newline='') as csvfile:
#             writer = csv.writer(csvfile)
#             writer.writerow(f'{LOGST}')        




#####################################################
elif sys.argv[1:][0] == 'add-tags':
    print('welcome to add add-tags to vm')
    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        for row in datareader:
            vm_name = row[0]
            vm_zone = row[1]
            TAG = row[2]
            project_id = row[3] 
            subprocess.run(['/bin/bash', '-c', f'gcloud compute instances add-tags {vm_name} --zone={vm_zone} --tags={TAG} --project={project_id}'])
            print(f'{vm_name} tag {TAG} added' )
##########################################################
elif sys.argv[1:][0] == 'rm-tags':
    print('welcome to add rm-tags to vm')
    filename = sys.argv[1:][1]+".csv"
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        for row in datareader:
            vm_name = row[0]
            vm_zone = row[1]
            TAG = row[2]
            project_id = row[3] 
            subprocess.run(['/bin/bash', '-c', f'gcloud compute instances remove-tags {vm_name} --zone={vm_zone} --tags={TAG} --project={project_id}'])
            print(f'{vm_name} tag {TAG} removed' )
############################################################
else:
    print('coming soon')
