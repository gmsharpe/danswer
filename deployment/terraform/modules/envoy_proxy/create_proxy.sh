  GNU nano 5.8                                                                                                   create_proxy.sh
#!/bin/bash
consul connect envoy -envoy-binary /usr/local/bin/envoy -sidecar-for echo-service-1 -ignore-envoy-compatibility  > /tmp/sidecar-proxy.log 2>&1 &
#consul connect envoy -envoy-binary /usr/local/bin/envoy -bootstrap -sidecar-for echo-service-1 > bootstrap_echo.json
