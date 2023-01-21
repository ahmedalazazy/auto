import csv, random, subprocess, sys, time, os

filename = r'projects.list'
def migrate_vms(filename):
    with open(filename, 'r') as csvfile:
        datareader = csv.reader(csvfile)
        for row in datareader:
            project_id = row[0]
            subprocess.run(['/bin/bash', '-c', f'gcloud compute instances list --filter="(scheduling.onHostMaintenance != MIGRATE) OR (scheduling.automaticRestart != true)" --format="csv[no-heading](NAME,ZONE)" --project={project_id} > {project_id}-compute.csv'])
            subprocess.run(['/bin/bash', '-c', f'gcloud compute disks list --filter="-users:*" --format "csv[no-heading](name,zone.scope())" --project={project_id} > {project_id}-unused-compute-disks.csv'])
            subprocess.run(['/bin/bash', '-c', f'gcloud compute addresses list --format "csv[no-heading](NAME,address_range(),address_type,region.basename(),STATUS)" --project={project_id} | grep EXTERNAL | grep RESERVED > {project_id}-unused-ips.csv'])
            with open(f'{project_id}-compute.csv', 'r') as csvfile_tow:
                datareader_tow = csv.reader(csvfile_tow)
                for row in datareader_tow:
                    VMNAME = row[0]
                    VMZONE = row[1]
                    subprocess.run(['/bin/bash', '-c', f'gcloud compute instances set-scheduling {VMNAME} --maintenance-policy=MIGRATE --restart-on-failure --zone={VMZONE} --project={project_id}'])
            subprocess.run(['/bin/bash', '-c', f'rm -rf {project_id}-compute.csv'])
            
migrate_vms(filename)