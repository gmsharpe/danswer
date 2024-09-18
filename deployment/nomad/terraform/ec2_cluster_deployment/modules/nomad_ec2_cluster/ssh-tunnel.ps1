# PowerShell SSH tunnel script
Start-Process "ssh" -ArgumentList "-L 14646:10.0.1.10:14646 -L 18500:10.0.1.10:18500 ec2-user@ec2-54-151-43-228.us-west-1.compute.amazonaws.com -N" -NoNewWindow
