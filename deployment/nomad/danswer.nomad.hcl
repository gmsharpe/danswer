variable "IMAGE_TAG" {
  description = "The tag of the Docker image to deploy"
  type    = string
  default = "latest"
}
variable "AUTH_TYPE" {
  description = "The type of authentication to use"
  type    = string
  default = "disabled"
}
variable "ENABLE_PAID_ENTERPRISE_EDITION_FEATURES" {
  description = "Enable paid enterprise edition features"
  type    = string
  default = "false"
}
variable "MODEL_SERVER_HOST" {
  description = "The host of the model server"
  type    = string
  default = "inference_model_server"
}
variable "LOG_LEVEL" {
  description = "The log level"
  type    = string
  default = "info"
}
variable "SMTP_SERVER" {
  description = "The SMTP server"
  type    = string
  default = "smtp.gmail.com"
}
variable "SMTP_PORT" {
  description = "The SMTP port"
  type    = string
  default = "587"
}
variable "INDEXING_MODEL_SERVER_HOST" {
    description = "The host of the indexing model server"
    type    = string
    default = "indexing_model_server"
}
variable "NEXT_PUBLIC_DISABLE_STREAMING" {
    description = "Disable streaming"
    type    = string
    default = "false"
}
variable "NEXT_PUBLIC_NEW_CHAT_DIRECTS_TO_SAME_PERSONA" {
  description = "New chat directs to the same persona"
  type        = string
  default     = "false"
}
variable "NEXT_PUBLIC_DO_NOT_USE_TOGGLE_OFF_DANSWER_POWERED" {
    description = "Do not use toggle off danswer powered"
    type        = string
    default     = "false"
}
variable "DISABLE_MODEL_SERVER" {
    description = "Disable model server"
    type        = string
    default     = "false"
}
variable "POSTGRES_USER" {
    description = "Postgres user"
    type        = string
    default     = "postgres"
}
variable "POSTGRES_PASSWORD" {
    description = "Postgres password"
    type        = string
    default     = "password"
}

job "danswer" {
  datacenters = ["dc1"]
  type        = "service"

  group "danswer_group" {
    count = 1

    # API Server
    task "api_server" {
      driver = "docker"

      config {
        image = "danswer/danswer-backend:${var.IMAGE_TAG}"
        port_map {
          api_port = 8080
        }
        command = "/bin/sh"
        args    = ["-c", "alembic upgrade head && echo \"Starting Danswer API Server\" && uvicorn danswer.main:app --host 0.0.0.0 --port 8080"]
      }

      resources {
        cpu    = 500
        memory = 1024
        network {
          port "api_port" {
            static = 8080
          }
        }
      }

      env {

        # Auth Settings
        AUTH_TYPE                      =  "${AUTH_TYPE}"
        SESSION_EXPIRE_TIME_SECONDS     = "${SESSION_EXPIRE_TIME_SECONDS}"
        ENCRYPTION_KEY_SECRET           = "${ENCRYPTION_KEY_SECRET}"
        VALID_EMAIL_DOMAINS             = "${VALID_EMAIL_DOMAINS}"
        GOOGLE_OAUTH_CLIENT_ID          = "${GOOGLE_OAUTH_CLIENT_ID}"
        GOOGLE_OAUTH_CLIENT_SECRET      = "${GOOGLE_OAUTH_CLIENT_SECRET}"
        REQUIRE_EMAIL_VERIFICATION      = "${REQUIRE_EMAIL_VERIFICATION}"
        SMTP_SERVER                     = "${SMTP_SERVER}"  # Default is 'smtp.gmail.com'
        SMTP_PORT                       = "${SMTP_PORT}"  # Default is '587'
        SMTP_USER                       = "${SMTP_USER}"
        SMTP_PASS                       = "${SMTP_PASS}"
        EMAIL_FROM                      = "${EMAIL_FROM}"
        OAUTH_CLIENT_ID                 = "${OAUTH_CLIENT_ID}"
        OAUTH_CLIENT_SECRET             = "${OAUTH_CLIENT_SECRET}"
        OPENID_CONFIG_URL               = "${OPENID_CONFIG_URL}"
        TRACK_EXTERNAL_IDP_EXPIRY       = "${TRACK_EXTERNAL_IDP_EXPIRY}"

        # Gen AI Settings
        GEN_AI_MAX_TOKENS               = "${GEN_AI_MAX_TOKENS}"
        QA_TIMEOUT                      = "${QA_TIMEOUT}"
        MAX_CHUNKS_FED_TO_CHAT          = "${MAX_CHUNKS_FED_TO_CHAT}"
        DISABLE_LLM_CHOOSE_SEARCH       = "${DISABLE_LLM_CHOOSE_SEARCH}"
        DISABLE_LLM_QUERY_REPHRASE      = "${DISABLE_LLM_QUERY_REPHRASE}"
        DISABLE_GENERATIVE_AI           = "${DISABLE_GENERATIVE_AI}"
        DISABLE_LITELLM_STREAMING       = "${DISABLE_LITELLM_STREAMING}"
        LITELLM_EXTRA_HEADERS           = "${LITELLM_EXTRA_HEADERS}"
        BING_API_KEY                    = "${BING_API_KEY}"
        DISABLE_LLM_DOC_RELEVANCE       = "${DISABLE_LLM_DOC_RELEVANCE}"
        # if set, allows for the use of the token budget system
        TOKEN_BUDGET_GLOBALLY_ENABLED   = "${TOKEN_BUDGET_GLOBALLY_ENABLED}"
        # Enables the use of bedrock models
        AWS_ACCESS_KEY_ID               = "${AWS_ACCESS_KEY_ID}"
        AWS_SECRET_ACCESS_KEY           = "${AWS_SECRET_ACCESS_KEY}"
        AWS_REGION_NAME                 = "${AWS_REGION_NAME}"

        # Query Options
        DOC_TIME_DECAY                  = "${DOC_TIME_DECAY}"  # Recency Bias for search results, decay at 1 / (1 + DOC_TIME_DECAY * x years)
        HYBRID_ALPHA                    = "${HYBRID_ALPHA}"  # Hybrid Search Alpha (0 for entirely keyword, 1 for entirely vector)
        EDIT_KEYWORD_QUERY              = "${EDIT_KEYWORD_QUERY}"
        MULTILINGUAL_QUERY_EXPANSION    = "${MULTILINGUAL_QUERY_EXPANSION}"
        LANGUAGE_HINT                   = "${LANGUAGE_HINT}"
        LANGUAGE_CHAT_NAMING_HINT       = "${LANGUAGE_CHAT_NAMING_HINT}"
        QA_PROMPT_OVERRIDE              = "${QA_PROMPT_OVERRIDE}"

        # Other Services
        POSTGRES_HOST                   = "relational_db"
        VESPA_HOST                      = "index"
        WEB_DOMAIN                      = "${WEB_DOMAIN}" # For frontend redirect auth purpose
        # Don't change the NLP model configs unless you know what you're doing
        DOCUMENT_ENCODER_MODEL          = "${DOCUMENT_ENCODER_MODEL}"
        DOC_EMBEDDING_DIM               = "${DOC_EMBEDDING_DIM}"
        NORMALIZE_EMBEDDINGS            = "${NORMALIZE_EMBEDDINGS}"
        ASYM_QUERY_PREFIX               = "${ASYM_QUERY_PREFIX}"
        DISABLE_RERANK_FOR_STREAMING    = "${DISABLE_RERANK_FOR_STREAMING}"
        MODEL_SERVER_HOST               = "${MODEL_SERVER_HOST}"
        MODEL_SERVER_PORT               = "${MODEL_SERVER_PORT}"

        # Leave this on pretty please? Nothing sensitive is collected!
        # https://docs.danswer.dev/more/telemetry
        DISABLE_TELEMETRY               = "${DISABLE_TELEMETRY}"
        LOG_LEVEL                       = "${LOG_LEVEL}" # Set to debug to get more fine-grained logs
        LOG_ALL_MODEL_INTERACTIONS      = "${LOG_ALL_MODEL_INTERACTIONS}"# LiteLLM Verbose Logging
        # Log all of Danswer prompts and interactions with the LLM
        LOG_DANSWER_MODEL_INTERACTIONS  = "${LOG_DANSWER_MODEL_INTERACTIONS}"
        # If set to `true` will enable additional logs about Vespa query performance
        # (time spent on finding the right docs + time spent fetching summaries from disk)
        LOG_VESPA_TIMING_INFORMATION    = "${LOG_VESPA_TIMING_INFORMATION}"
        LOG_ENDPOINT_LATENCY            = "${LOG_ENDPOINT_LATENCY}"
        LOG_POSTGRES_LATENCY            = "${LOG_POSTGRES_LATENCY}"
        LOG_POSTGRES_CONN_COUNTS        = "${LOG_POSTGRES_CONN_COUNTS}"

        # Enterprise Edition only
        ENABLE_PAID_ENTERPRISE_EDITION_FEATURES = "${ENABLE_PAID_ENTERPRISE_EDITION_FEATURES}"
        API_KEY_HASH_ROUNDS                    = "${API_KEY_HASH_ROUNDS}"
        # Seeding configuration
        ENV_SEED_CONFIGURATION                 = "${ENV_SEED_CONFIGURATION}"
      }


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

    # Background Task
    task "background" {
      driver = "docker"

      config {
        image = "danswer/danswer-backend:${IMAGE_TAG}"
        command = "/usr/bin/supervisord"
        args    = ["-c", "/etc/supervisor/conf.d/supervisord.conf"]
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      env {
        ENCRYPTION_KEY_SECRET           = "${ENCRYPTION_KEY_SECRET}"

        # Gen AI Settings (Needed by DanswerBot)
        GEN_AI_MAX_TOKENS               = "${GEN_AI_MAX_TOKENS}"
        QA_TIMEOUT                      = "${QA_TIMEOUT}"
        MAX_CHUNKS_FED_TO_CHAT          = "${MAX_CHUNKS_FED_TO_CHAT}"
        DISABLE_LLM_CHOOSE_SEARCH       = "${DISABLE_LLM_CHOOSE_SEARCH}"
        DISABLE_LLM_QUERY_REPHRASE      = "${DISABLE_LLM_QUERY_REPHRASE}"
        DISABLE_GENERATIVE_AI           = "${DISABLE_GENERATIVE_AI}"
        GENERATIVE_MODEL_ACCESS_CHECK_FREQ = "${GENERATIVE_MODEL_ACCESS_CHECK_FREQ}"
        DISABLE_LITELLM_STREAMING       = "${DISABLE_LITELLM_STREAMING}"
        LITELLM_EXTRA_HEADERS           = "${LITELLM_EXTRA_HEADERS}"
        BING_API_KEY                    = "${BING_API_KEY}"

        # Query Options
        DOC_TIME_DECAY                  = "${DOC_TIME_DECAY}"  # Recency Bias for search results, decay at 1 / (1 + DOC_TIME_DECAY * x years)
        HYBRID_ALPHA                    = "${HYBRID_ALPHA}"  # Hybrid Search Alpha (0 for entirely keyword, 1 for entirely vector)
        EDIT_KEYWORD_QUERY              = "${EDIT_KEYWORD_QUERY}"
        MULTILINGUAL_QUERY_EXPANSION    = "${MULTILINGUAL_QUERY_EXPANSION}"
        LANGUAGE_HINT                   = "${LANGUAGE_HINT}"
        LANGUAGE_CHAT_NAMING_HINT       = "${LANGUAGE_CHAT_NAMING_HINT}"
        QA_PROMPT_OVERRIDE              = "${QA_PROMPT_OVERRIDE}"

        # Other Services
        POSTGRES_HOST                   = "relational_db"
        POSTGRES_USER                   = "${POSTGRES_USER}"
        POSTGRES_PASSWORD               = "${POSTGRES_PASSWORD}"
        POSTGRES_DB                     = "${POSTGRES_DB}"
        VESPA_HOST                      = "index"
        WEB_DOMAIN                      = "${WEB_DOMAIN}"  # For frontend redirect auth purpose for OAuth2 connectors

        # Don't change the NLP model configs unless you know what you're doing
        DOCUMENT_ENCODER_MODEL          = "${DOCUMENT_ENCODER_MODEL}"
        DOC_EMBEDDING_DIM               = "${DOC_EMBEDDING_DIM}"
        NORMALIZE_EMBEDDINGS            = "${NORMALIZE_EMBEDDINGS}"
        ASYM_QUERY_PREFIX               = "${ASYM_QUERY_PREFIX}"  # Needed by DanswerBot
        ASYM_PASSAGE_PREFIX             = "${ASYM_PASSAGE_PREFIX}"
        MODEL_SERVER_HOST               = "${MODEL_SERVER_HOST}"
        MODEL_SERVER_PORT               = "${MODEL_SERVER_PORT}"
        INDEXING_MODEL_SERVER_HOST      = "${INDEXING_MODEL_SERVER_HOST}"

        # Indexing Configs
        NUM_INDEXING_WORKERS            = "${NUM_INDEXING_WORKERS}"
        ENABLED_CONNECTOR_TYPES         = "${ENABLED_CONNECTOR_TYPES}"
        DISABLE_INDEX_UPDATE_ON_SWAP    = "${DISABLE_INDEX_UPDATE_ON_SWAP}"
        DASK_JOB_CLIENT_ENABLED         = "${DASK_JOB_CLIENT_ENABLED}"
        CONTINUE_ON_CONNECTOR_FAILURE   = "${CONTINUE_ON_CONNECTOR_FAILURE}"
        EXPERIMENTAL_CHECKPOINTING_ENABLED = "${EXPERIMENTAL_CHECKPOINTING_ENABLED}"
        CONFLUENCE_CONNECTOR_LABELS_TO_SKIP = "${CONFLUENCE_CONNECTOR_LABELS_TO_SKIP}"
        JIRA_CONNECTOR_LABELS_TO_SKIP   = "${JIRA_CONNECTOR_LABELS_TO_SKIP}"
        WEB_CONNECTOR_VALIDATE_URLS     = "${WEB_CONNECTOR_VALIDATE_URLS}"
        JIRA_API_VERSION                = "${JIRA_API_VERSION}"
        GONG_CONNECTOR_START_TIME       = "${GONG_CONNECTOR_START_TIME}"
        NOTION_CONNECTOR_ENABLE_RECURSIVE_PAGE_LOOKUP = "${NOTION_CONNECTOR_ENABLE_RECURSIVE_PAGE_LOOKUP}"
        GITHUB_CONNECTOR_BASE_URL       = "${GITHUB_CONNECTOR_BASE_URL}"

        # Danswer SlackBot Configs
        DANSWER_BOT_SLACK_APP_TOKEN     = "${DANSWER_BOT_SLACK_APP_TOKEN}"
        DANSWER_BOT_SLACK_BOT_TOKEN     = "${DANSWER_BOT_SLACK_BOT_TOKEN}"
        DANSWER_BOT_DISABLE_DOCS_ONLY_ANSWER = "${DANSWER_BOT_DISABLE_DOCS_ONLY_ANSWER}"
        DANSWER_BOT_FEEDBACK_VISIBILITY = "${DANSWER_BOT_FEEDBACK_VISIBILITY}"
        DANSWER_BOT_DISPLAY_ERROR_MSGS  = "${DANSWER_BOT_DISPLAY_ERROR_MSGS}"
        DANSWER_BOT_RESPOND_EVERY_CHANNEL = "${DANSWER_BOT_RESPOND_EVERY_CHANNEL}"
        DANSWER_BOT_DISABLE_COT         = "${DANSWER_BOT_DISABLE_COT}"  # Currently unused
        NOTIFY_SLACKBOT_NO_ANSWER       = "${NOTIFY_SLACKBOT_NO_ANSWER}"
        DANSWER_BOT_MAX_QPM             = "${DANSWER_BOT_MAX_QPM}"
        DANSWER_BOT_MAX_WAIT_TIME       = "${DANSWER_BOT_MAX_WAIT_TIME}"

        # Logging
        # Leave this on pretty please? Nothing sensitive is collected!
        # https://docs.danswer.dev/more/telemetry
        DISABLE_TELEMETRY               = "${DISABLE_TELEMETRY}"
        LOG_LEVEL                       = "${LOG_LEVEL}"  # Set to debug to get more fine-grained logs
        LOG_ALL_MODEL_INTERACTIONS      = "${LOG_ALL_MODEL_INTERACTIONS}"  # LiteLLM Verbose Logging
        # Log all of Danswer prompts and interactions with the LLM
        LOG_DANSWER_MODEL_INTERACTIONS  = "${LOG_DANSWER_MODEL_INTERACTIONS}"
        LOG_VESPA_TIMING_INFORMATION    = "${LOG_VESPA_TIMING_INFORMATION}"

        # Enterprise Edition stuff
        ENABLE_PAID_ENTERPRISE_EDITION_FEATURES = "${ENABLE_PAID_ENTERPRISE_EDITION_FEATURES}"
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

      config {
        image = "danswer/danswer-web-server:${IMAGE_TAG}"
        port_map {
          web_port = 80
        }

        # Build arguments (replaced in Nomad by environment variables)
        env {
          NEXT_PUBLIC_DISABLE_STREAMING               = "${NEXT_PUBLIC_DISABLE_STREAMING}"
          NEXT_PUBLIC_NEW_CHAT_DIRECTS_TO_SAME_PERSONA = "${NEXT_PUBLIC_NEW_CHAT_DIRECTS_TO_SAME_PERSONA}"
          NEXT_PUBLIC_POSITIVE_PREDEFINED_FEEDBACK_OPTIONS = "${NEXT_PUBLIC_POSITIVE_PREDEFINED_FEEDBACK_OPTIONS}"
          NEXT_PUBLIC_NEGATIVE_PREDEFINED_FEEDBACK_OPTIONS = "${NEXT_PUBLIC_NEGATIVE_PREDEFINED_FEEDBACK_OPTIONS}"
          NEXT_PUBLIC_DISABLE_LOGOUT                  = "${NEXT_PUBLIC_DISABLE_LOGOUT}"
          NEXT_PUBLIC_DEFAULT_SIDEBAR_OPEN            = "${NEXT_PUBLIC_DEFAULT_SIDEBAR_OPEN}"
          NEXT_PUBLIC_THEME                           = "${NEXT_PUBLIC_THEME}"
          NEXT_PUBLIC_DO_NOT_USE_TOGGLE_OFF_DANSWER_POWERED = "${NEXT_PUBLIC_DO_NOT_USE_TOGGLE_OFF_DANSWER_POWERED}"

          # Environment Variables
          INTERNAL_URL                                = "http://api_server:8080"
          WEB_DOMAIN                                  = "${WEB_DOMAIN}"
          THEME_IS_DARK                               = "${THEME_IS_DARK}"
          DISABLE_LLM_DOC_RELEVANCE                   = "${DISABLE_LLM_DOC_RELEVANCE}"
          ENABLE_PAID_ENTERPRISE_EDITION_FEATURES      = "${ENABLE_PAID_ENTERPRISE_EDITION_FEATURES}"
        }
      }

      # Resources for this task
      resources {
        cpu    = 500
        memory = 1024
        network {
          port "web_port" {
          }
        }
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

    # Inference Model Server
    task "inference_model_server" {
      driver = "docker"

      config {
        image = "danswer/danswer-model-server:${IMAGE_TAG}"

        # Command block to handle conditional logic
        command = "/bin/sh"
        args    = ["-c", "if [ \"${DISABLE_MODEL_SERVER}\" = \"True\" ]; then echo 'Skipping service...'; exit 0; else exec uvicorn model_server.main:app --host 0.0.0.0 --port 9000; fi"]

        # Mount the Huggingface cache as a volume
        volumes = [ "model_cache_huggingface:/root/.cache/huggingface/" ]
      }

      # Environment Variables
      env {
        MIN_THREADS_ML_MODELS = "${MIN_THREADS_ML_MODELS}"
        LOG_LEVEL             = "${LOG_LEVEL}"  # Default to info level for logs
      }

      # Resources allocation
      resources {
        cpu    = 500
        memory = 1024
        network {
          port "http" {
            static = 9000  # Expose the service on port 9000
          }
        }
      }

      # Restart policy: on-failure
      restart {
        attempts = 2
        interval = "5m"
        delay    = "25s"
        mode     = "delay"
      }

      # Volume mounts
      volume_mount {
        volume      = "model_cache_huggingface"
        destination = "/root/.cache/huggingface/"
      }
    }

    # Indexing Model Server
    task "indexing_model_server" {
      driver = "docker"

      config {
        image = "danswer/danswer-model-server:${IMAGE_TAG}"

        # Command block to handle conditional logic
        command = "/bin/sh"
        args    = ["-c", "if [ \"${DISABLE_MODEL_SERVER}\" = \"True\" ]; then echo 'Skipping service...'; exit 0; else exec uvicorn model_server.main:app --host 0.0.0.0 --port 9000; fi"]

        # Mount the Huggingface cache as a volume
        volumes = [ "indexing_model_cache_huggingface:/root/.cache/huggingface/" ]
      }

      # Environment Variables
      env {
        MIN_THREADS_ML_MODELS = "${MIN_THREADS_ML_MODELS}"
        INDEXING_ONLY         = "True"
        LOG_LEVEL             = "${LOG_LEVEL}"  # Default to info level for logs
      }

      # Resources allocation
      resources {
        cpu    = 500
        memory = 1024
        network {
          port "http" {
            static = 9001  # Expose the service on port 9001
          }
        }
      }

      # Restart policy: on-failure
      restart {
        attempts = 2
        interval = "5m"
        delay    = "25s"
        mode     = "delay"
      }

      # Volume mounts
      volume_mount {
        volume      = "indexing_model_cache_huggingface"
        destination = "/root/.cache/huggingface/"
      }
    }

    # Relational DB (PostgreSQL)
    task "relational_db" {
      driver = "docker"

      config {
        image = "postgres:15.2-alpine"
        command = ["-c", "max_connections=150"]
        port_map {
          db_port = 5432
        }
      }

      resources {
        cpu    = 500
        memory = 1024
        network {
          port "db_port" {
            static = 5432
          }
        }
      }

      env {
        POSTGRES_USER     = "${POSTGRES_USER}"
        POSTGRES_PASSWORD = "${POSTGRES_PASSWORD}"
      }

      volume_mount {
        volume      = "db"
        destination = "/var/lib/postgresql/data"
      }
    }

    # Vespa index task
    task "index" {
      driver = "docker"

      config {
        image = "vespaengine/vespa:8.277.17"

        # Mount volume for Vespa data
        volumes = ["vespa:/opt/vespa/var"]

        # Set the container to run in the background with the appropriate ports
        ports = ["19071", "8081"]
      }

      # Resources for the Vespa task
      resources {
        cpu    = 1000   # 1000 MHz (1 core)
        memory = 2048   # 2 GB of RAM
        network {
          port "admin" {
            static = 19071  # Vespa admin service
          }
          port "http" {
            static = 8081  # Vespa HTTP service
          }
        }
      }

      # Restart policy (always restart)
      restart {
        attempts = 0  # Unlimited restarts
        interval = "5m"
        delay    = "25s"
        mode     = "delay"
      }

      # Volume mount for Vespa data
      volume_mount {
        volume      = "vespa_volume"
        destination = "/opt/vespa/var"
      }
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx:1.23.4-alpine"

        # Command to handle the startup script and ensure conversion of files
        command = "/bin/sh"
        args    = ["-c", "dos2unix /etc/nginx/conf.d/run-nginx.sh && /etc/nginx/conf.d/run-nginx.sh app.conf.template.dev"]

        # Mount volume for Nginx configuration
        volumes = ["nginx_config:/etc/nginx/conf.d"]

        # Environment variables
        env {
          DOMAIN = "localhost"
        }

        # Ports mapping
        ports = ["80", "3000"]
      }

      # Resources for the Nginx task
      resources {
        cpu    = 500   # 500 MHz (0.5 core)
        memory = 256   # 256 MB of RAM
        network {
          port "http" {
            static = 80     # Expose on port 80
          }
          port "custom" {
            static = 3000   # Expose on port 3000
          }
        }
      }

      # Restart policy (always restart)
      restart {
        attempts = 0  # Unlimited restarts
        interval = "5m"
        delay    = "25s"
        mode     = "delay"
      }

      # Volume mount for Nginx configuration
      volume_mount {
        volume      = "nginx_config"
        destination = "/etc/nginx/conf.d"
      }

    }

    # Volumes definition at the group level
    # 'source' is the host path where the volume is located
    volume "db" {
      type      = "host"
      read_only = false
      source    = "/var/nomad/volumes/danswer/db"
    }

    volume "vespa" {
      type      = "host"
      read_only = false
      source    = "/var/nomad/volumes/danswer/vespa"
    }

    volume "model_cache_huggingface" {
      type      = "host"
      read_only = false
      source    = "/var/nomad/volumes/danswer/model_cache_huggingface"
    }

    volume "indexing_model_cache_huggingface" {
      type      = "host"
      read_only = false
      source    = "/var/nomad/volumes/danswer/indexing_model_cache_huggingface"
    }

    volume "nginx_config" {
      type      = "host"
      read_only = false
      source    = "/var/nomad/volumes/danswer/nginx"
    }
  }
}
