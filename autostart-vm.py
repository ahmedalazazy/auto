import subprocess
import time



# Prompt the user to enter the project ID and VM instance name
project_id = input("Enter the project ID: ")
instance_name = input("Enter the VM instance name: ")
ZONE_NAME = input("Enter the VM instance zone: ")
web_hook = input("Enter the web_hook url for status : ")
def check_vm_status(project_id, instance_name):
    # Run gcloud command to get the status of the VM instance
    command = ["gcloud", "compute", "instances", "describe", instance_name, "--project", project_id, "--format=value(status)", "--zone", ZONE_NAME]
    result = subprocess.run(command, capture_output=True, text=True)
    
    # Extract the status from the command output
    status = result.stdout.strip()
    
    return status

def start_vm_instance(project_id, instance_name):
    # Run gcloud command to start the VM instance
    command = ["gcloud", "compute", "instances", "start", instance_name, "--project", project_id, "--zone", ZONE_NAME]
    subprocess.run(command)


# send a message if vm started
def web_hook_trigger(msg):
    url = os.getenv('web_hook')
    payload = {
        "channel":"#scripts_alerts",
        "text": f"{msg}",
        "username":"webhookbot",
    }
    headers = {
        'Content-Type': 'application/json'
    }
    response = requests.post(url, headers=headers, data=json.dumps(payload))
    print(response.text.encode('utf8'))




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
