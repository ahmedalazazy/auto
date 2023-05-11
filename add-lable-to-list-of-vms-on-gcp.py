import csv, subprocess

def add_labels_to_vms(file_path):
    with open(file_path, 'r') as file:
        reader = csv.reader(file)
        for row in reader:
            vm_name, label_key, label_value, project_id = row
            zone = get_vm_zone(vm_name, project_id)
            add_label_to_vm(vm_name, zone, label_key, label_value, project_id)

def get_vm_zone(vm_name, project_id):
    # Run gcloud command to get the zone of the VM
    command = ['gcloud', 'compute', 'instances', 'describe', vm_name, '--project', project_id, '--format', 'value(zone)']
    result = subprocess.run(command, capture_output=True, text=True)
    
    if result.returncode == 0:
        zone = result.stdout.strip()
        return zone
    else:
        error_message = result.stderr.strip()
        raise Exception(f"Failed to retrieve zone: {error_message}")

def add_label_to_vm(vm_name, zone, label_key, label_value, project_id):
    # Run gcloud command to add labels to the VM
    command = ['gcloud', 'compute', 'instances', 'add-labels', vm_name, '--labels', f'{label_key}={label_value}', '--zone', zone, '--project', project_id]
    result = subprocess.run(command, capture_output=True, text=True)
    
    if result.returncode == 0:
        print(f"Labels added to VM: {vm_name}")
        with open('add_label_logs', 'a') as log_file:
            log_file.write(f"{vm_name},{zone},{label_key},{project_id}-Done\n")
    else:
        error_message = result.stderr.strip()
        print(f"Failed to add labels to VM: {vm_name}\nError: {error_message}")

# Example usage
file_path = 'file00.csv'
add_labels_to_vms(file_path)