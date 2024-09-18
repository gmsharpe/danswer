
# Nginx Configuration
## Overview
The provided Nginx configuration sets up a reverse proxy server that routes incoming HTTP requests to either an API server or a web server based on the request URI. It also defines custom logging to include request latency, sets client upload size limits, and configures headers and proxy settings to ensure proper communication between the client, Nginx, and the backend servers.


### Override log format to include request latency

```
log_format custom_main '$remote_addr - $remote_user [$time_local] "$request" '
                       '$status $body_bytes_sent "$http_referer" '
                       '"$http_user_agent" "$http_x_forwarded_for" '
                       'rt=$request_time';

```

**Purpose**: Defines a custom log format named custom_main to include standard access log information along with the request time ($request_time), allowing for monitoring of request latency.

* Variables Used:

    * `$remote_addr`: IP address of the client.
    * `$remote_user`: Authenticated user (if any). 
    * `$time_local`: Local time of the request.
    * `$request`: Request line from the client.
    * `$status`: HTTP status code of the response.
    * `$body_bytes_sent`: Size of the response body.
    * `$http_referer`: Referer header from the client.
    * `$http_user_agent`: User-Agent header from the client.
    * `$http_x_forwarded_for`: X-Forwarded-For header, useful for tracking original client IPs behind proxies. 
    * `rt=$request_time`: Custom field to log the request processing time.

``` 
upstream api_server {
    # fail_timeout=0 means we always retry an upstream even if it failed
    # to return a good HTTP response

    # For UNIX domain socket setups (commented out)
    # server unix:/tmp/gunicorn.sock fail_timeout=0;

    # For a TCP configuration
    # TODO: use gunicorn to manage multiple processes
    server api_server:8080 fail_timeout=0;
}
```


**Purpose**: Defines an upstream group named api_server to forward API-related requests.
* Configurations:
  * Commented Out UNIX Socket: Indicates an alternative configuration using a UNIX socket, which is currently not in use.
    * Active Server Directive:
    * `server api_server:8080 fail_timeout=0;`: Specifies the API server's address and port.
    * `fail_timeout=0`: Disables the fail timeout, ensuring Nginx always retries the upstream server even after failures.
    * Note: A TODO comment suggests using Gunicorn to manage multiple worker processes for better scalability.

```  
upstream web_server {
  server web_server:3000 fail_timeout=0;
  }
```
**Purpose**: Defines an upstream group named web_server to handle web-related requests.

* Configuration:
  * `server web_server:3000 fail_timeout=0;`: Specifies the web server's address and port with no fail timeout.
  
```
server {
        listen 80;
        server_name ${DOMAIN};

      client_max_body_size 5G;    # Maximum upload size    
    
      access_log /var/log/nginx/access.log custom_main;
```

Purpose: Begins the server block that defines how Nginx should handle incoming connections.
* Configurations:
  * `listen 80;`: Listens on port 80 for incoming HTTP requests.
  * `server_name ${DOMAIN};`: The domain name for which this server block is responsible. ${DOMAIN} should be replaced with the actual domain.
  * `client_max_body_size 5G;`: Increases the maximum allowed size of the client request body to 5 gigabytes to accommodate large uploads.
  * `access_log /var/log/nginx/access.log custom_main;`: Specifies the access log file and uses the custom log format defined earlier.

```
    # Match both /api/* and /openapi.json in a single rule
    location ~ ^/(api|openapi.json)(/.*)?$ {
    # Rewrite /api prefixed matched paths
    rewrite ^/api(/.*)$ $1 break;

    # Misc headers
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host; 
    proxy_set_header Host $host;

    # Need to use HTTP/1.1 to support chunked transfers
    proxy_http_version 1.1;
    proxy_buffering off;

    # Disable automatic rewriting of redirects
    proxy_redirect off;
    proxy_pass http://api_server;
}
```

Purpose: Handles routing for API requests and the OpenAPI specification file.
Configurations:
Location Matching:
location ~ ^/(api|openapi.json)(/.*)?$: Uses a regular expression to match URIs that start with /api or are exactly /openapi.json.
URI Rewrite:
rewrite ^/api(/.*)$ $1 break;: Removes the /api prefix from the URI before passing it to the upstream server.
Example: /api/users becomes /users.

* Proxy Headers:
  * proxy_set_header X-Real-IP $remote_addr;`: Passes the client's IP address to the backend server.
  * `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`: Maintains a list of proxy servers the request has passed through.
  `proxy_set_header X-Forwarded-Proto $scheme;`: Indicates the protocol (http or https) used by the client.
  `proxy_set_header X-Forwarded-Host $host;`: Passes the original host requested by the client.
  `proxy_set_header Host $host;`: Sets the Host header for the backend request.

* Proxy Settings:
  * `proxy_http_version 1.1;`: Uses HTTP/1.1 to support features like chunked transfer encoding.
  * `proxy_buffering off;`: Disables buffering to allow for real-time data transfer.
  * `proxy_redirect off;`: Prevents Nginx from modifying Location headers in redirects from the backend.

* Upstream Server:
  * `proxy_pass http://api_server;`: Forwards the request to the api_server upstream group.

```
location / {
# Misc headers
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto $scheme;
proxy_set_header X-Forwarded-Host $host;
proxy_set_header Host $host;

        proxy_http_version 1.1;

        # Disable automatic rewriting of redirects
        proxy_redirect off;
        proxy_pass http://web_server;
    }
}
```
**Purpose**: Handles all other requests not matched by the previous location block, typically serving the main web application.

* Configurations:
  * Location Matching:
    * location /: Matches any URI.
  * Proxy Headers: (Same as above)
    * Ensures that important client and request information is passed to the backend web server.
  * Proxy Settings:
    * proxy_http_version 1.1;: Uses HTTP/1.1.
    * proxy_redirect off;: Disables automatic redirect modification.
  * Upstream Server:
    * proxy_pass http://web_server;: Forwards the request to the web_server upstream group.

#### Additional Details and Explanations:

* Custom Log Format:
  * Including rt=$request_time in the log format helps monitor the time taken to process each request, which is valuable for performance tuning and identifying bottlenecks.
* Upstream Servers:
  * api_server: Represents one or more backend API servers handling API requests.
  * web_server: Represents one or more backend web servers handling standard web requests.
* Fail Timeout Setting:
  * By setting fail_timeout=0, Nginx does not mark an upstream server as failed, ensuring continuous retry attempts.
* Headers Passed to Upstream Servers:
  * Passing headers like X-Real-IP and X-Forwarded-For ensures the backend servers are aware of the original client's IP address.
  * Host headers maintain the original domain requested, which can be important for virtual hosting and SSL certificate validation.
* Proxy Settings:
  * HTTP/1.1 Support:
    * Required for features like chunked transfer encoding, which is essential for streaming data and handling large uploads or downloads.
  * Proxy Buffering:
    * Disabling buffering (proxy_buffering off;) allows for real-time data transfer, reducing latency for the client.
  * Proxy Redirect:
    * Disabling proxy redirect (proxy_redirect off;) prevents Nginx from altering Location headers in redirects from the backend, ensuring the client receives accurate URLs.
  * Client Max Body Size:
    * Increasing client_max_body_size to 5G allows clients to upload files up to 5 gigabytes, which is significantly higher than the default limit and necessary for applications that handle large files.
* URI Rewriting:
  * The rewrite rule simplifies the URI before passing it to the backend API server, which may not expect the /api prefix.
* Placeholder Variables:
  * ${DOMAIN} is a placeholder and should be replaced with the actual domain name when deploying this configuration.

### Summary:

This Nginx configuration is designed to act as a gateway that intelligently routes requests to the appropriate backend service based on the request path. By configuring upstream server groups (api_server and web_server), defining precise location blocks, and setting up critical proxy headers and settings, it ensures seamless communication between clients and backend servers. The configuration also enhances logging for better monitoring and sets parameters to handle large client uploads efficiently.

#### Usage Considerations:

* Scalability:
  * The configuration mentions a TODO to use Gunicorn for managing multiple processes. Implementing this would improve the API server's ability to handle concurrent requests.
* Security:
  * Ensure that the backend servers are properly secured and that sensitive headers are handled appropriately.
* Performance:
  * Monitoring the rt value in logs can help identify slow requests and optimize backend performance.
* Testing:
  * Before deploying, replace placeholders and test the configuration in a staging environment to validate that all routes and settings work as intended.