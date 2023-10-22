import csv
import socket
import sys

# Function to validate connectivity to IP and port
def validate_connectivity(ip, port):
    try:
        # Create a new socket object
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        # Set timeout for the connection attempt (in seconds)
        sock.settimeout(1)
        # Attempt to establish a connection to the IP and port
        sock.connect((ip, port))
        # Connection successful
        return "Success"
    except socket.error:
        # Connection failed
        return "Failed"

# Check if the user has provided the input filename
if len(sys.argv) < 2:
    print("Please provide the input filename as an argument.")
    sys.exit(1)

input_filename = sys.argv[1]

# Read IP addresses and ports from the specified input file and write results to output.csv
with open(input_filename, 'r') as input_file, open('output.csv', 'w', newline='') as output_file:
    # Create CSV reader and writer objects
    csv_reader = csv.reader(input_file)
    csv_writer = csv.writer(output_file)

    # Write header to output file
    csv_writer.writerow(['IP', 'Port', 'Status'])

    # Iterate through each row in the input CSV file
    for row in csv_reader:
        if len(row) >= 2:
            ip = row[0]  # IP address is the first column
            port = int(row[1])  # Port is the second column, convert to integer

            # Validate connectivity to the IP and port
            status = validate_connectivity(ip, port)

            # Write IP, port, and status to output CSV file
            csv_writer.writerow([ip, port, status])

print("Connectivity validation completed. Results are saved in output.csv.")
