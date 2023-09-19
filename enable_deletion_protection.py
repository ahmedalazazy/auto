import subprocess

# Input project name from the user
PROJECT_IDNAME = input("Please enter the project you need to enable deletion protection for an instance: ")

# Set the project for gcloud config
subprocess.run(["gcloud", "config", "set", "project", PROJECT_IDNAME], check=True)

# Get the list of instances
instance_list_output = subprocess.run(["gcloud", "compute", "instances", "list", "--project", PROJECT_IDNAME, "--format", "csv[no-heading](name,zone)"], stdout=subprocess.PIPE, text=True, check=True)
instance_lines = instance_list_output.stdout.strip().split('\n')

for line in instance_lines:
    name, zone = line.split(',')
    FULSE = "deletionProtection: false"
    
    # Describe the instance to check deletionProtection
    describe_output = subprocess.run(["gcloud", "compute", "instances", "describe", name, "--zone", zone, "--project", PROJECT_IDNAME], stdout=subprocess.PIPE, text=True, check=True)
    
    # Check if deletionProtection is false
    if FULSE in describe_output.stdout:
        # Enable deletion protection
        subprocess.run(["gcloud", "compute", "instances", "update", name, "--deletion-protection", "--zone", zone, "--project", PROJECT_IDNAME], check=True)
        print(f"{name},Protection,NOW")
    else:
        print(f"{name},deletion protection already")
