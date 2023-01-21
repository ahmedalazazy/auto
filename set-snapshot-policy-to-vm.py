import csv, random, subprocess, sys, time, os
vm_name = ''

filename = 'vms-list.csv'

def migrate_vms(filename):
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
                        if vm_name == DISK_USER :
                            subprocess.Popen(['/bin/bash', '-c', f'gcloud compute disks add-resource-policies {DISK_NAME} --resource-policies={disk_policy} --zone={DISK_ZONE} --project={project_id}'])
            subprocess.run(['/bin/bash', '-c', f'rm -rf {project_id}-disks.csv'])

migrate_vms(filename)