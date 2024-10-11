vault {
  address = "http://${leader_ip}:8200"
}

# Disable mlock if needed (for non-root/dev environments)
disable_mlock = true
