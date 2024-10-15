job "danswer_web" {
  datacenters = ["ats-1"]
  type      = "service"
  namespace = "danswer"
  node_pool = "default"

  vault {
    policies = ["nomad-cluster", "danswer"]  # Specify the Vault policies to use
  }

  group "api_group" {
    count = 1

    # Group-level network configuration
    network {
      port "api_port" {
        static = 8080
      }
      port "web_port" {
        # No static port specified; Nomad will allocate dynamically
      }
    }

    # API Server
    task "api_server" {
      driver = "docker"
      logs {
        enabled       = true
        max_files     = 5
        max_file_size = 10
      }
      config {
        image = "danswer/danswer-backend:${IMAGE_TAG}"
        ports = ["api_port"]

        command = "/bin/sh"
        args = [
          "-c",
          "alembic upgrade head && echo \"Starting Danswer API Server\" && uvicorn danswer.main:app --host 0.0.0.0 --port 8080"
        ]
      }

      vault {
        policies = ["nomad-cluster", "danswer"]  # Specify the Vault policies to use
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      # Template to fetch Vault secrets
      template {
        data = <<EOH
        {{ with secret "secret/data/danswer" }}
        IMAGE_TAG={{ .Data.data.IMAGE_TAG }}
        MIN_THREADS_ML_MODELS={{ .Data.data.MIN_THREADS_ML_MODELS }}
        LOG_LEVEL={{ .Data.data.LOG_LEVEL }}
        DISABLE_MODEL_SERVER={{ .Data.data.DISABLE_MODEL_SERVER }}
        {{ end }}
        EOH

        destination = "local/env.sh"
        env         = true
      }

#       env {
#
#         # Auth Settings
#         AUTH_TYPE                   = "${AUTH_TYPE}"
#         SESSION_EXPIRE_TIME_SECONDS  = "${SESSION_EXPIRE_TIME_SECONDS}"
#         ENCRYPTION_KEY_SECRET        = "${ENCRYPTION_KEY_SECRET}"
#         VALID_EMAIL_DOMAINS          = "${VALID_EMAIL_DOMAINS}"
#         GOOGLE_OAUTH_CLIENT_ID       = "${GOOGLE_OAUTH_CLIENT_ID}"
#         GOOGLE_OAUTH_CLIENT_SECRET   = "${GOOGLE_OAUTH_CLIENT_SECRET}"
#         REQUIRE_EMAIL_VERIFICATION   = "${REQUIRE_EMAIL_VERIFICATION}"
#         SMTP_SERVER                  = "${SMTP_SERVER}"
#         SMTP_PORT                    = "${SMTP_PORT}"
#         SMTP_USER                    = "${SMTP_USER}"
#         SMTP_PASS                    = "${SMTP_PASS}"
#         EMAIL_FROM                   = "${EMAIL_FROM}"
#         OAUTH_CLIENT_ID              = "${OAUTH_CLIENT_ID}"
#         OAUTH_CLIENT_SECRET          = "${OAUTH_CLIENT_SECRET}"
#         OPENID_CONFIG_URL            = "${OPENID_CONFIG_URL}"
#         TRACK_EXTERNAL_IDP_EXPIRY    = "${TRACK_EXTERNAL_IDP_EXPIRY}"
#
#         # Gen AI Settings
#         GEN_AI_MAX_TOKENS            = "${GEN_AI_MAX_TOKENS}"
#         QA_TIMEOUT                   = "${QA_TIMEOUT}"
#         MAX_CHUNKS_FED_TO_CHAT       = "${MAX_CHUNKS_FED_TO_CHAT}"
#         DISABLE_LLM_CHOOSE_SEARCH    = "${DISABLE_LLM_CHOOSE_SEARCH}"
#         DISABLE_LLM_QUERY_REPHRASE   = "${DISABLE_LLM_QUERY_REPHRASE}"
#         DISABLE_GENERATIVE_AI        = "${DISABLE_GENERATIVE_AI}"
#         DISABLE_LITELLM_STREAMING    = "${DISABLE_LITELLM_STREAMING}"
#         LITELLM_EXTRA_HEADERS        = "${LITELLM_EXTRA_HEADERS}"
#         BING_API_KEY                 = "${BING_API_KEY}"
#         DISABLE_LLM_DOC_RELEVANCE    = "${DISABLE_LLM_DOC_RELEVANCE}"
#         TOKEN_BUDGET_GLOBALLY_ENABLED = "${TOKEN_BUDGET_GLOBALLY_ENABLED}"
#
#         AWS_ACCESS_KEY_ID            = "${AWS_ACCESS_KEY_ID}"
#         AWS_SECRET_ACCESS_KEY        = "${AWS_SECRET_ACCESS_KEY}"
#         AWS_REGION_NAME              = "${AWS_REGION_NAME}"
#
#         # Query Options
#         DOC_TIME_DECAY               = "${DOC_TIME_DECAY}"
#         # Recency Bias for search results, decay at 1 / (1 + DOC_TIME_DECAY * x years)
#         HYBRID_ALPHA                 = "${HYBRID_ALPHA}"
#         # Hybrid Search Alpha (0 for entirely keyword, 1 for entirely vector)
#         EDIT_KEYWORD_QUERY           = "${EDIT_KEYWORD_QUERY}"
#         MULTILINGUAL_QUERY_EXPANSION = "${MULTILINGUAL_QUERY_EXPANSION}"
#         LANGUAGE_HINT                = "${LANGUAGE_HINT}"
#         LANGUAGE_CHAT_NAMING_HINT    = "${LANGUAGE_CHAT_NAMING_HINT}"
#         QA_PROMPT_OVERRIDE           = "${QA_PROMPT_OVERRIDE}"
#
#         # Other Services
#         POSTGRES_HOST                = "relational_db"
#         VESPA_HOST                   = "index"
#         WEB_DOMAIN                   = "${WEB_DOMAIN}"
#         # Don't change the NLP model configs unless you know what you're doing
#         DOCUMENT_ENCODER_MODEL       = "${DOCUMENT_ENCODER_MODEL}"
#         DOC_EMBEDDING_DIM            = "${DOC_EMBEDDING_DIM}"
#         NORMALIZE_EMBEDDINGS         = "${NORMALIZE_EMBEDDINGS}"
#         ASYM_QUERY_PREFIX            = "${ASYM_QUERY_PREFIX}"
#         DISABLE_RERANK_FOR_STREAMING = "${DISABLE_RERANK_FOR_STREAMING}"
#         MODEL_SERVER_HOST            = "${MODEL_SERVER_HOST}"
#         MODEL_SERVER_PORT            = "${MODEL_SERVER_PORT}"
#
#         # Leave this on pretty please? Nothing sensitive is collected!
#         # https://docs.danswer.dev/more/telemetry
#         DISABLE_TELEMETRY            = "${DISABLE_TELEMETRY}"
#         LOG_LEVEL                    = "${LOG_LEVEL}"
#         LOG_ALL_MODEL_INTERACTIONS   = "${LOG_ALL_MODEL_INTERACTIONS}"
#         # Log all of Danswer prompts and interactions with the LLM
#         LOG_DANSWER_MODEL_INTERACTIONS = "${LOG_DANSWER_MODEL_INTERACTIONS}"
#         # If set to `true` will enable additional logs about Vespa query performance
#         # (time spent on finding the right docs + time spent fetching summaries from disk)
#         LOG_VESPA_TIMING_INFORMATION = "${LOG_VESPA_TIMING_INFORMATION}"
#         LOG_ENDPOINT_LATENCY         = "${LOG_ENDPOINT_LATENCY}"
#         LOG_POSTGRES_LATENCY         = "${LOG_POSTGRES_LATENCY}"
#         LOG_POSTGRES_CONN_COUNTS     = "${LOG_POSTGRES_CONN_COUNTS}"
#
#         # Enterprise Edition only
#         ENABLE_PAID_ENTERPRISE_EDITION_FEATURES = "${ENABLE_PAID_ENTERPRISE_EDITION_FEATURES}"
#         API_KEY_HASH_ROUNDS                     = "${API_KEY_HASH_ROUNDS}"
#         # Seeding configuration
#         ENV_SEED_CONFIGURATION                  = "${ENV_SEED_CONFIGURATION}"
#
#         # Misc.
#         IMAGE_TAG                               = "${IMAGE_TAG}"
#       }

      service {
        name = "api-server"
        port = "api_port"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      restart {
        attempts = 2
        interval = "5m"
        delay    = "25s"
        mode     = "delay"
      }

    }

    # Web Server
    task "web_server" {
      driver = "docker"
      logs {
        enabled       = true
        max_files     = 5
        max_file_size = 10
      }
      config {
        image = "danswer/danswer-web-server:${IMAGE_TAG}"
        ports = ["web_port"]
      }

      vault {
        policies = ["nomad-cluster", "danswer"]  # Specify the Vault policies to use
      }

      # Build arguments (replaced in Nomad by environment variables)
#       env {
#         NEXT_PUBLIC_DISABLE_STREAMING                     = "${NEXT_PUBLIC_DISABLE_STREAMING}"
#         NEXT_PUBLIC_NEW_CHAT_DIRECTS_TO_SAME_PERSONA      = "${NEXT_PUBLIC_NEW_CHAT_DIRECTS_TO_SAME_PERSONA}"
#         NEXT_PUBLIC_POSITIVE_PREDEFINED_FEEDBACK_OPTIONS  = "${NEXT_PUBLIC_POSITIVE_PREDEFINED_FEEDBACK_OPTIONS}"
#         NEXT_PUBLIC_NEGATIVE_PREDEFINED_FEEDBACK_OPTIONS  = "${NEXT_PUBLIC_NEGATIVE_PREDEFINED_FEEDBACK_OPTIONS}"
#         NEXT_PUBLIC_DISABLE_LOGOUT                        = "${NEXT_PUBLIC_DISABLE_LOGOUT}"
#         NEXT_PUBLIC_DEFAULT_SIDEBAR_OPEN                  = "${NEXT_PUBLIC_DEFAULT_SIDEBAR_OPEN}"
#         NEXT_PUBLIC_THEME                                 = "${NEXT_PUBLIC_THEME}"
#         NEXT_PUBLIC_DO_NOT_USE_TOGGLE_OFF_DANSWER_POWERED = "${NEXT_PUBLIC_DO_NOT_USE_TOGGLE_OFF_DANSWER_POWERED}"
#
#         # Environment Variables
#         INTERNAL_URL                            = "http://api_server:8080"
#         WEB_DOMAIN                              = "${WEB_DOMAIN}"
#         THEME_IS_DARK                           = "${THEME_IS_DARK}"
#         DISABLE_LLM_DOC_RELEVANCE               = "${DISABLE_LLM_DOC_RELEVANCE}"
#         ENABLE_PAID_ENTERPRISE_EDITION_FEATURES = "${ENABLE_PAID_ENTERPRISE_EDITION_FEATURES}"
#         IMAGE_TAG                               = "${IMAGE_TAG}"
#       }

      # Template to fetch Vault secrets
      template {
        data = <<EOH
        {{ with secret "secret/data/danswer" }}
        NEXT_PUBLIC_DISABLE_STREAMING={{ .Data.data.NEXT_PUBLIC_DISABLE_STREAMING }}
        NEXT_PUBLIC_NEW_CHAT_DIRECTS_TO_SAME_PERSONA={{ .Data.data.NEXT_PUBLIC_NEW_CHAT_DIRECTS_TO_SAME_PERSONA }}
        NEXT_PUBLIC_POSITIVE_PREDEFINED_FEEDBACK_OPTIONS={{ .Data.data.NEXT_PUBLIC_POSITIVE_PREDEFINED_FEEDBACK_OPTIONS }}
        NEXT_PUBLIC_NEGATIVE_PREDEFINED_FEEDBACK_OPTIONS={{ .Data.data.NEXT_PUBLIC_NEGATIVE_PREDEFINED_FEEDBACK_OPTIONS }}
        NEXT_PUBLIC_DISABLE_LOGOUT={{ .Data.data.NEXT_PUBLIC_DISABLE_LOGOUT }}
        NEXT_PUBLIC_DEFAULT_SIDEBAR_OPEN={{ .Data.data.NEXT_PUBLIC_DEFAULT_SIDEBAR_OPEN }}
        NEXT_PUBLIC_THEME={{ .Data.data.NEXT_PUBLIC_THEME }}
        NEXT_PUBLIC_DO_NOT_USE_TOGGLE_OFF_DANSWER_POWERED={{ .Data.data.NEXT_PUBLIC_DO_NOT_USE_TOGGLE_OFF_DANSWER_POWERED }}

        WEB_DOMAIN={{ .Data.data.WEB_DOMAIN }}
        THEME_IS_DARK={{ .Data.data.THEME_IS_DARK }}
        DISABLE_LLM_DOC_RELEVANCE={{ .Data.data.DISABLE_LLM_DOC_RELEVANCE }}
        ENABLE_PAID_ENTERPRISE_EDITION_FEATURES={{ .Data.data.ENABLE_PAID_ENTERPRISE_EDITION_FEATURES }}
        IMAGE_TAG={{ .Data.data.IMAGE_TAG }}
        {{ end }}
        EOH

        destination = "local/env.sh"
        env         = true
      }

      # Resources for this task
      resources {
        cpu    = 500
        memory = 1024
      }

      service {
        name = "web-server"
        port = "web_port"
        check {
          type     = "http"
          path     = "/"
          interval = "10s"
          timeout  = "2s"
        }
      }


      # Restart Policy
      restart {
        attempts = 2
        interval = "5m"
        delay    = "25s"
        mode     = "delay"
      }
    }


  }

  group "nginx" {
    count = 1
    # Group-level network configuration
    network {
      port "nginx_http" {
        static = 80
      }
      port "nginx_custom" {
        static = 3000
      }
    }

    service {
      name = "nginx"
      port = "nginx_http"
      check {
        type     = "http"
        path = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "nginx" {
      driver = "docker"

      logs {
        enabled       = true
        max_files     = 5
        max_file_size = 10
      }

      # Environment variables
      env {
        #DOMAIN = "127.0.0.1"
        NGINX_PORT = "80"
      }

      # Resources for the Nginx task
      resources {
        cpu = 500   # 500 MHz (0.5 core)
        memory = 256   # 256 MB of RAM
      }

      restart {
        attempts = 2
        interval = "30s"
        delay    = "15s"
        mode     = "delay"
      }

      #Volume mount for Nginx configuration
      volume_mount {
        volume      = "nginx"
        read_only   = false
        destination = "/etc/nginx/conf.d"
      }

      # Template block to write the script to a file inside the container
      template {
        destination = "/etc/nginx/conf.d/run-nginx.sh"
        perms = "0755"  # Make the script executable
        change_mode = "restart"
        data = <<-EOT
        #!/bin/bash

        # fill in the template
        envsubst '$DOMAIN $SSL_CERT_FILE_NAME $SSL_CERT_KEY_FILE_NAME' < "/etc/nginx/conf.d/$1" > /etc/nginx/conf.d/app.conf

        # wait for the api_server to be ready
        echo "Waiting for API server to boot up; this may take a minute or two..."
        echo "If this takes more than ~5 minutes, check the logs of the API server container for errors with the following command:"
        echo
        echo "docker logs danswer-stack_api_server-1"
        echo

        while true; do
          # Use curl to send a request and capture the HTTP status code
          status_code=$(curl -o /dev/null -s -w "%%{http_code}\n" "http://api_server:8080/health")

          # Check if the status code is 200
          if [ "$status_code" -eq 200 ]; then
            echo "API server responded with 200, starting nginx..."
            break  # Exit the loop
          else
            echo "API server responded with $status_code, retrying in 5 seconds..."
            sleep 5  # Sleep for 5 seconds before retrying
          fi
        done

        # Start nginx and reload every 6 hours
        while :; do sleep 6h & wait; nginx -s reload; done & nginx -g "daemon off;"
      EOT
      }

      # Template block to create the nginx config file
      template {
        destination = "/etc/nginx/conf.d/app.conf.template.dev"
        perms = "0644"  # Standard permissions for configuration files
        change_mode = "restart"
        data = <<-EOT
        # Override log format to include request latency
        log_format custom_main '$remote_addr - $remote_user [$time_local] "$request" '
                              '$status $body_bytes_sent "$http_referer" '
                              '"$http_user_agent" "$http_x_forwarded_for" '
                              'rt=$request_time';

        upstream api_server {
            # fail_timeout=0 means we always retry an upstream even if it failed
            # to return a good HTTP response

            # for UNIX domain socket setups
            #server unix:/tmp/gunicorn.sock fail_timeout=0;

            # for a TCP configuration
            # TODO: use gunicorn to manage multiple processes
            server api_server:8080 fail_timeout=0;
        }

        upstream web_server {
            server web_server:3000 fail_timeout=0;
        }

        server {
            listen 80;
            server_name $${DOMAIN};

            client_max_body_size 5G;    # Maximum upload size

            access_log /var/log/nginx/access.log custom_main;

            # Match both /api/* and /openapi.json in a single rule
            location ~ ^/(api|openapi.json)(/.*)?$ {
                # Rewrite /api prefixed matched paths
                rewrite ^/api(/.*)$ $1 break;

                # misc headers
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Forwarded-Host $host;
                proxy_set_header Host $host;

                # need to use 1.1 to support chunked transfers
                proxy_http_version 1.1;
                proxy_buffering off;

                # we don't want nginx trying to do something clever with
                # redirects, we set the Host: header above already.
                proxy_redirect off;
                proxy_pass http://api_server;
            }

            location / {
                # misc headers
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Forwarded-Host $host;
                proxy_set_header Host $host;

                proxy_http_version 1.1;

                # we don't want nginx trying to do something clever with
                # redirects, we set the Host: header above already.
                proxy_redirect off;
                proxy_pass http://web_server;
            }
        }
        EOT
      }
      config {
        image = "nginx:1.23.4-alpine"
        privileged = true
        # Command to handle the startup script and ensure conversion of files
        command = "/bin/sh"
        args = [
          "-c",
          "while [ ! -f /etc/nginx/conf.d/run-nginx.sh ]; do pwd; ls; echo 'File not found, sleeping...'; sleep 1; done; dos2unix /etc/nginx/conf.d/run-nginx.sh && /etc/nginx/conf.d/run-nginx.sh app.conf.template.dev"
        ]

        # Mount volume for Nginx configuration
        #volumes = ["nginx:/etc/nginx/conf.d"]

        ports = ["nginx_http", "nginx_custom"]
      }

    }

    volume "nginx" {
      type      = "host"
      read_only = false
      source    = "nginx"
    }
  }

}