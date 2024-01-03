#!/usr/bin/env python3

import subprocess
import os
import glob
import argparse

def export_pfx_data(pfx_file):
    folder_name = os.path.splitext(pfx_file)[0]
    os.makedirs(folder_name, exist_ok=True)

    cert_command = f"openssl pkcs12 -in {pfx_file} -nokeys -out {folder_name}/{folder_name}-certificate.pem"
    print(f"Exporting certificate from {pfx_file}...")
    cert_process = subprocess.run(cert_command, shell=True, capture_output=True, text=True)

    key_command = f"openssl pkcs12 -in {pfx_file} -nocerts -out {folder_name}/{folder_name}-key.pem -nodes"
    print(f"Exporting private key from {pfx_file}...")
    key_process = subprocess.run(key_command, shell=True, capture_output=True, text=True)

    if cert_process.returncode == 0 and key_process.returncode == 0:
        print(f"Exported certificate and private key from {pfx_file} to {folder_name}/")
    else:
        print(f"Failed to export certificate and private key from {pfx_file}.")
        print("Certificate output:")
        print(cert_process.stdout)
        print("Private key output:")
        print(key_process.stdout)

def main():
    parser = argparse.ArgumentParser(description="Export certificates and private keys from PFX files.")
    parser.add_argument("directory", metavar="directory", type=str, nargs="?", default=".", help="Directory path (default: current directory)")
    args = parser.parse_args()

    directory = args.directory
    os.chdir(directory)

    pfx_files = glob.glob("*.pfx")

    if len(pfx_files) == 0:
        print(f"No .pfx files found in '{directory}' directory.")
    else:
        print(f"Found {len(pfx_files)} .pfx file(s) to process in '{directory}' directory.")
        for pfx_file in pfx_files:
            export_pfx_data(pfx_file)

if __name__ == "__main__":
    main()
