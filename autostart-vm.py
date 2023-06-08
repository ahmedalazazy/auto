import subprocess
import time



# Prompt the user to enter the project ID and VM instance name
project_id = input("Enter the project ID: ")
instance_name = input("Enter the VM instance name: ")

def check_vm_status(project_id, instance_name):
    # Run gcloud command to get the status of the VM instance
    command = ["gcloud", "compute", "instances", "describe", instance_name, "--project", project_id, "--format=value(status)"]
    result = subprocess.run(command, capture_output=True, text=True)
    
    # Extract the status from the command output
    status = result.stdout.strip()
    
    return status

def start_vm_instance(project_id, instance_name):
    # Run gcloud command to start the VM instance
    command = ["gcloud", "compute", "instances", "start", instance_name, "--project", project_id]
    subprocess.run(command)


while True:
    # Check the status of the VM instance
    status = check_vm_status(project_id, instance_name)
    
    if status != "RUNNING":
        print("VM instance is not running. Starting it now...")
        start_vm_instance(project_id, instance_name)
    else:
        print("VM instance is running.")
        break
    
    # Wait for a few seconds before checking the status again
    time.sleep(5)
