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
                subprocess.Popen(['/bin/bash', '-c', f'gcloud compute disks add-resource-policies {DISK_NAME} --resource-policies={Disk_Policy} --zone={DISK_ZONE} --project={project_id}'])

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
