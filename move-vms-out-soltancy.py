import csv, subprocess, sys, os

project_id = input("Please Enter the PROJECT ID:")
# Run the gcloud command to list all the firewall rules in the project
list_command = f'gcloud compute instances list  --format="csv[no-heading](NAME,ZONE,scheduling.nodeAffinities[values])" --project={project_id}'
output = subprocess.check_output(list_command, shell=True).decode('utf-8')
InstancesLIST = output.split('\n')[:-1]  # remove last empty item
VMS = csv.reader(InstancesLIST)

for VM in VMS:
    VM_NAME = VM[0]
    VM_ZONE = VM[1]
    NODE_AFFINITES = VM[2]
    if NODE_AFFINITES:
        cmd2 = f'gcloud compute instances set-scheduling "{VM_NAME}" --clear-node-affinities --zone={VM_ZONE} --project={project_id}'
        subprocess.run(cmd2, shell=True)
        print(f'{VM_NAME}-{VM_ZONE}-{project_id}-out - of the sole now')
#        cmd3 = f'gcloud compute instances start "{VM_NAME}" --zone={VM_ZONE} --project={project_id}'
#        subprocess.run(cmd3, shell=True)
#        print(f'{VM_NAME}-{VM_ZONE}-{project_id}-started')
