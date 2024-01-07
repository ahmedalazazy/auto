import csv
import subprocess

# Function to create VPC
def create_vpc(vpc_data):
    cmd = (
        f"gcloud compute networks create {vpc_data['name']} "
        f"--subnet-mode={vpc_data['subnet_mode']} "
        f"--project={vpc_data['project']} "
        f"--description='{vpc_data['description']}' "
        f"--routing-mode={vpc_data['routing_mode']}"
    )
    run_command(cmd)

# Function to create Subnet
def create_subnet(subnet_data):
    cmd = (
        f"gcloud compute networks subnets create {subnet_data['name']} "
        f"--network={subnet_data['network']} "
        f"--region={subnet_data['region']} "
        f"--range={subnet_data['ip_range']} "
        f"--project={subnet_data['project']} "
        f"--description='{subnet_data['description']}'"
    )
    run_command(cmd)

# Function to create VPC FW Rules
def create_vpc_fw_rules(fw_data):
    cmd = (
        f"gcloud compute firewall-rules create {fw_data['name']} "
        f"--action={fw_data['action']} "
        f"--direction={fw_data['direction']} "
        f"--source-ranges={fw_data['source_ranges']} "
        f"--target-tags={fw_data['target_tags']} "
        f"--project={fw_data['project']} "
        f"--description='{fw_data['description']}'"
    )
    run_command(cmd)

# Function to create VPN HA
def create_vpn_ha(vpn_data):
    cmd = (
        f"gcloud compute target-vpn-gateways create {vpn_data['gateway_name']} "
        f"--network={vpn_data['network']} "
        f"--region={vpn_data['region']} "
        f"--project={vpn_data['project']} "
        f"--description='{vpn_data['description']}'"
    )
    run_command(cmd)

# Function to create Load Balancer
def create_lb(lb_data):
    cmd = (
        f"gcloud compute load-balancers create {lb_data['lb_name']} "
        f"--backend-service={lb_data['backend_service']} "
        f"--region={lb_data['region']} "
        f"--project={lb_data['project']} "
        f"--description='{lb_data['description']}'"
    )
    run_command(cmd)

# Function to create WAF Cloud Armor
def create_waf_cloud_armor(waf_data):
    cmd = (
        f"gcloud compute security-policies create {waf_data['policy_name']} "
        f"--description='{waf_data['description']}'"
    )
    # Add more options to the command as required for WAF Cloud Armor setup
    run_command(cmd)

# Function to create Google Cloud Backup machine images schedules
def create_machine_images_schedule(machine_images_data):
    cmd = (
        f"gcloud compute machine-images create {machine_images_data['image_name']} "
        f"--source-disk={machine_images_data['source_disk']} "
        f"--project={machine_images_data['project']} "
        f"--description='{machine_images_data['description']}'"
    )
    run_command(cmd)

# Function to create Google Cloud Backup snapshots schedules
def create_snapshots_schedule(snapshots_data):
    cmd = (
        f"gcloud compute disks snapshot {snapshots_data['disk']} "
        f"--region={snapshots_data['region']} "
        f"--project={snapshots_data['project']} "
        f"--description='{snapshots_data['description']}'"
    )
    run_command(cmd)

# Function to run commands
def run_command(cmd):
    try:
        subprocess.run(cmd, shell=True, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {cmd}")
        print(f"Error: {e}")
        # Add further error handling or logging here

def main():
    print("Choose the resources to create:")
    print("1) VPC")
    print("2) Subnets")
    print("3) VPC FW Rules")
    print("4) VPN HA")
    print("5) LB")
    print("6) WAF Cloud Armor")
    print("7) Google Cloud Backup machine-images schedules")
    print("8) Google Cloud Backup snapshots schedules")

    selected_options = input("Enter the numbers separated by commas: ")
    selected_options = [int(option.strip()) for option in selected_options.split(",")]

    csv_file = input("Enter the path to the CSV file: ")

    with open(csv_file, 'r') as file:
        reader = csv.DictReader(file)
        for row in reader:
            project = row.get('Project')
            region = row.get('Region')

            vpc_data = {
                'name': row.get('VPC_Name'),
                'subnet_mode': row.get('Subnet_Mode'),
                'description': row.get('VPC_Description'),
                'routing_mode': row.get('Routing_Mode'),
                'project': project
            }

            subnet_data = {
                'name': row.get('Subnet_Name'),
                'network': row.get('VPC_Name'),
                'region': region,
                'ip_range': row.get('IP_Range'),
                'description': row.get('Subnet_Description'),
                'project': project
            }

            fw_data = {
                'name': row.get('Firewall_Rule_Name'),
                'action': row.get('Firewall_Action'),
                'direction': row.get('Firewall_Direction'),
                'source_ranges': row.get('Source_Ranges'),
                'target_tags': row.get('Target_Tags'),
                'project': project,
                'description': row.get('Firewall_Description')
            }

            vpn_data = {
                'gateway_name': row.get('Gateway_Name'),
                'network': row.get('VPC_Name'),
                'region': region,
                'project': project,
                'description': row.get('Gateway_Description')
            }

            lb_data = {
                'lb_name': row.get('Load_Balancer_Name'),
                'backend_service': row.get('Backend_Service'),
                'region': region,
                'project': project,
                'description': row.get('Load_Balancer_Description')
            }

            waf_data = {
                'policy_name': row.get('Policy_Name'),
                'description': row.get('Policy_Description')
            }

            machine_images_data = {
                'image_name': row.get('Image_Name'),
                'source_disk': row.get('Source_Disk'),
                'project': project,
                'description': row.get('Image_Description')
            }

            snapshots_data = {
                'disk': row.get('Disk'),
                'region': region,
                'project': project,
                'description': row.get('Snapshot_Description')
            }

            for option in selected_options:
                if option == 1:
                    create_vpc(vpc_data)
                elif option == 2:
                    create_subnet(subnet_data)
                elif option == 3:
                    create_vpc_fw_rules(fw_data)
                elif option == 4:
                    create_vpn_ha(vpn_data)
                elif option == 5:
                    create_lb(lb_data)
                elif option == 6:
                    create_waf_cloud_armor(waf_data)
                elif option == 7:
                    create_machine_images_schedule(machine_images_data)
                elif option == 8:
                    create_snapshots_schedule(snapshots_data)

if __name__ == "__main__":
    main()
