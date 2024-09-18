job "danswer" {
  datacenters = ["dc1"]
  type      = "service"
  namespace = "danswer"
  node_pool = "secondary"

  vault {
    policies = ["danswer-policy"]  # Vault policies required for this job
  }

  group "background_group" {
    count = 1
    network {
      port "db_port" {
        static = 5432
      }

    }

    # Background Task
    task "background" {
      driver = "docker"

      logs {
        enabled       = true
        max_files     = 5
        max_file_size = 10
      }
      config {
        image   = "danswer/danswer-backend:${NOMAD_META.IMAGE_TAG}"
        command = "/usr/bin/supervisord"
        args = ["-c", "/etc/supervisor/conf.d/supervisord.conf"]
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      env {
        ENCRYPTION_KEY_SECRET = "${NOMAD_META.ENCRYPTION_KEY_SECRET}"

        # Gen AI Settings (Needed by DanswerBot)
        GEN_AI_MAX_TOKENS                  = "${NOMAD_META.GEN_AI_MAX_TOKENS}"
        QA_TIMEOUT                         = "${NOMAD_META.QA_TIMEOUT}"
        MAX_CHUNKS_FED_TO_CHAT             = "${NOMAD_META.MAX_CHUNKS_FED_TO_CHAT}"
        DISABLE_LLM_CHOOSE_SEARCH          = "${NOMAD_META.DISABLE_LLM_CHOOSE_SEARCH}"
        DISABLE_LLM_QUERY_REPHRASE         = "${NOMAD_META.DISABLE_LLM_QUERY_REPHRASE}"
        DISABLE_GENERATIVE_AI              = "${NOMAD_META.DISABLE_GENERATIVE_AI}"
        GENERATIVE_MODEL_ACCESS_CHECK_FREQ = "${NOMAD_META.GENERATIVE_MODEL_ACCESS_CHECK_FREQ}"
        DISABLE_LITELLM_STREAMING          = "${NOMAD_META.DISABLE_LITELLM_STREAMING}"
        LITELLM_EXTRA_HEADERS              = "${NOMAD_META.LITELLM_EXTRA_HEADERS}"
        BING_API_KEY = "${NOMAD_META.BING_API_KEY}"

        # Query Options
        DOC_TIME_DECAY = "${NOMAD_META.DOC_TIME_DECAY}"
        # Recency Bias for search results, decay at 1 / (1 + DOC_TIME_DECAY * x years)
        HYBRID_ALPHA = "${NOMAD_META.HYBRID_ALPHA}"
        # Hybrid Search Alpha (0 for entirely keyword, 1 for entirely vector)
        EDIT_KEYWORD_QUERY           = "${NOMAD_META.EDIT_KEYWORD_QUERY}"
        MULTILINGUAL_QUERY_EXPANSION = "${NOMAD_META.MULTILINGUAL_QUERY_EXPANSION}"
        LANGUAGE_HINT                = "${NOMAD_META.LANGUAGE_HINT}"
        LANGUAGE_CHAT_NAMING_HINT    = "${NOMAD_META.LANGUAGE_CHAT_NAMING_HINT}"
        QA_PROMPT_OVERRIDE = "${NOMAD_META.QA_PROMPT_OVERRIDE}"

        # Other Services
        POSTGRES_HOST     = "relational_db"
        POSTGRES_USER     = "${NOMAD_META.POSTGRES_USER}"
        POSTGRES_PASSWORD = "${NOMAD_META.POSTGRES_PASSWORD}"
        POSTGRES_DB       = "${NOMAD_META.POSTGRES_DB}"
        VESPA_HOST        = "index"
        WEB_DOMAIN        = "${NOMAD_META.WEB_DOMAIN}"  # For frontend redirect auth purpose for OAuth2 connectors

        # Don't change the NLP model configs unless you know what you're doing
        DOCUMENT_ENCODER_MODEL = "${NOMAD_META.DOCUMENT_ENCODER_MODEL}"
        DOC_EMBEDDING_DIM      = "${NOMAD_META.DOC_EMBEDDING_DIM}"
        NORMALIZE_EMBEDDINGS   = "${NOMAD_META.NORMALIZE_EMBEDDINGS}"
        ASYM_QUERY_PREFIX = "${NOMAD_META.ASYM_QUERY_PREFIX}"  # Needed by DanswerBot
        ASYM_PASSAGE_PREFIX    = "${NOMAD_META.ASYM_PASSAGE_PREFIX}"
        MODEL_SERVER_HOST      = "${NOMAD_META.MODEL_SERVER_HOST}"
        MODEL_SERVER_PORT      = "${NOMAD_META.MODEL_SERVER_PORT}"
        INDEXING_MODEL_SERVER_HOST = "${NOMAD_META.INDEXING_MODEL_SERVER_HOST}"

        # Indexing Configs
        NUM_INDEXING_WORKERS                          = "${NOMAD_META.NUM_INDEXING_WORKERS}"
        ENABLED_CONNECTOR_TYPES                       = "${NOMAD_META.ENABLED_CONNECTOR_TYPES}"
        DISABLE_INDEX_UPDATE_ON_SWAP                  = "${NOMAD_META.DISABLE_INDEX_UPDATE_ON_SWAP}"
        DASK_JOB_CLIENT_ENABLED                       = "${NOMAD_META.DASK_JOB_CLIENT_ENABLED}"
        CONTINUE_ON_CONNECTOR_FAILURE                 = "${NOMAD_META.CONTINUE_ON_CONNECTOR_FAILURE}"
        EXPERIMENTAL_CHECKPOINTING_ENABLED            = "${NOMAD_META.EXPERIMENTAL_CHECKPOINTING_ENABLED}"
        CONFLUENCE_CONNECTOR_LABELS_TO_SKIP           = "${NOMAD_META.CONFLUENCE_CONNECTOR_LABELS_TO_SKIP}"
        JIRA_CONNECTOR_LABELS_TO_SKIP                 = "${NOMAD_META.JIRA_CONNECTOR_LABELS_TO_SKIP}"
        WEB_CONNECTOR_VALIDATE_URLS                   = "${NOMAD_META.WEB_CONNECTOR_VALIDATE_URLS}"
        JIRA_API_VERSION                              = "${NOMAD_META.JIRA_API_VERSION}"
        GONG_CONNECTOR_START_TIME                     = "${NOMAD_META.GONG_CONNECTOR_START_TIME}"
        NOTION_CONNECTOR_ENABLE_RECURSIVE_PAGE_LOOKUP = "${NOMAD_META.NOTION_CONNECTOR_ENABLE_RECURSIVE_PAGE_LOOKUP}"
        GITHUB_CONNECTOR_BASE_URL = "${NOMAD_META.GITHUB_CONNECTOR_BASE_URL}"

        # Danswer SlackBot Configs
        DANSWER_BOT_SLACK_APP_TOKEN          = "${NOMAD_META.DANSWER_BOT_SLACK_APP_TOKEN}"
        DANSWER_BOT_SLACK_BOT_TOKEN          = "${NOMAD_META.DANSWER_BOT_SLACK_BOT_TOKEN}"
        DANSWER_BOT_DISABLE_DOCS_ONLY_ANSWER = "${NOMAD_META.DANSWER_BOT_DISABLE_DOCS_ONLY_ANSWER}"
        DANSWER_BOT_FEEDBACK_VISIBILITY      = "${NOMAD_META.DANSWER_BOT_FEEDBACK_VISIBILITY}"
        DANSWER_BOT_DISPLAY_ERROR_MSGS       = "${NOMAD_META.DANSWER_BOT_DISPLAY_ERROR_MSGS}"
        DANSWER_BOT_RESPOND_EVERY_CHANNEL    = "${NOMAD_META.DANSWER_BOT_RESPOND_EVERY_CHANNEL}"
        DANSWER_BOT_DISABLE_COT = "${NOMAD_META.DANSWER_BOT_DISABLE_COT}"  # Currently unused
        NOTIFY_SLACKBOT_NO_ANSWER            = "${NOMAD_META.NOTIFY_SLACKBOT_NO_ANSWER}"
        DANSWER_BOT_MAX_QPM                  = "${NOMAD_META.DANSWER_BOT_MAX_QPM}"
        DANSWER_BOT_MAX_WAIT_TIME            = "${NOMAD_META.DANSWER_BOT_MAX_WAIT_TIME}"

        # Logging
        # Leave this on pretty please? Nothing sensitive is collected!
        # https://docs.danswer.dev/more/telemetry
        DISABLE_TELEMETRY              = "${NOMAD_META.DISABLE_TELEMETRY}"
        LOG_LEVEL = "${NOMAD_META.LOG_LEVEL}"  # Set to debug to get more fine-grained logs
        LOG_ALL_MODEL_INTERACTIONS     = "${NOMAD_META.LOG_ALL_MODEL_INTERACTIONS}"  # LiteLLM Verbose Logging
        # Log all of Danswer prompts and interactions with the LLM
        LOG_DANSWER_MODEL_INTERACTIONS = "${NOMAD_META.LOG_DANSWER_MODEL_INTERACTIONS}"
        LOG_VESPA_TIMING_INFORMATION = "${NOMAD_META.LOG_VESPA_TIMING_INFORMATION}"

        # Enterprise Edition stuff
        ENABLE_PAID_ENTERPRISE_EDITION_FEATURES = "${NOMAD_META.ENABLE_PAID_ENTERPRISE_EDITION_FEATURES}"
      }

      restart {
        attempts = 2
        interval = "5m"
        delay    = "25s"
        mode     = "delay"
      }
    }

    # Relational DB (PostgreSQL)
    task "relational_db" {
      driver = "docker"

      logs {
        enabled       = true
        max_files     = 5
        max_file_size = 10
      }
      config {
        image = "postgres:15.2-alpine"
        command = ["postgres"]
        args = ["-c", "max_connections=150"]
        port_map {
          db_port = 5432
        }
      }

      env {
        POSTGRES_USER     = "${NOMAD_META.POSTGRES_USER}"
        POSTGRES_PASSWORD = "${NOMAD_META.POSTGRES_PASSWORD}"
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      volume_mount {
        volume      = "db"
        destination = "/var/lib/postgresql/data"
      }
    }
    volume "db" {
      type      = "host"
      read_only = false
      source    = "db"
    }

  }

  group "model_group" {
    count = 1
    network {
      port "inference_http" {
        static = 9000
      }
      port "indexing_http" {
        static = 9001
      }
    }
    # Inference Model Server
    task "inference_model_server" {
      driver = "docker"
      logs {
        enabled       = true
        max_files     = 5
        max_file_size = 10
      }
      config {
        image = "danswer/danswer-model-server:${NOMAD_META.IMAGE_TAG}"

        # Command block to handle conditional logic
        command = "/bin/sh"
        args = [
          "-c",
          "if [ \"${NOMAD_META.DISABLE_MODEL_SERVER}\" = \"True\" ]; then echo 'Skipping service...'; exit 0; else exec uvicorn model_server.main:app --host 0.0.0.0 --port 9000; fi"
        ]

        # Mount the Huggingface cache as a volume
        volumes = ["model_cache_huggingface:/root/.cache/huggingface/"]
      }

      # Environment Variables
      env {
        MIN_THREADS_ML_MODELS = "${NOMAD_META.MIN_THREADS_ML_MODELS}"
        LOG_LEVEL = "${NOMAD_META.LOG_LEVEL}"  # Default to info level for logs
        DISABLE_MODEL_SERVER  = "${NOMAD_META.DISABLE_MODEL_SERVER}"
      }

      # Resources allocation
      resources {
        cpu    = 500
        memory = 1024
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
      logs {
        enabled       = true
        max_files     = 5
        max_file_size = 10
      }
      config {
        image = "danswer/danswer-model-server:${NOMAD_META.IMAGE_TAG}"

        # Command block to handle conditional logic
        command = "/bin/sh"
        args = [
          "-c",
          "if [ \"${NOMAD_META.DISABLE_MODEL_SERVER}\" = \"True\" ]; then echo 'Skipping service...'; exit 0; else exec uvicorn model_server.main:app --host 0.0.0.0 --port 9000; fi"
        ]

        # Mount the Huggingface cache as a volume
        volumes = ["indexing_model_cache_huggingface:/root/.cache/huggingface/"]
      }

      # Environment Variables
      env {
        MIN_THREADS_ML_MODELS = "${NOMAD_META.MIN_THREADS_ML_MODELS}"
        INDEXING_ONLY         = "True"
        LOG_LEVEL = "${NOMAD_META.LOG_LEVEL}"  # Default to info level for logs
        DISABLE_MODEL_SERVER  = "${NOMAD_META.DISABLE_MODEL_SERVER}"
      }

      # Resources allocation
      resources {
        cpu    = 500
        memory = 1024
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

    volume "model_cache_huggingface" {
      type      = "host"
      read_only = false
      source    = "model_cache_huggingface"
    }

    volume "indexing_model_cache_huggingface" {
      type      = "host"
      read_only = false
      source    = "indexing_model_cache_huggingface"
    }

  }

  group "vespa_group" {
    count = 1
    network {
      port "vespa_admin" {
        static = 19071
      }
      port "vespa_http" {
        static = 8081
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
        cpu = 1000   # 1000 MHz (1 core)
        memory = 2048   # 2 GB of RAM
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
        volume      = "vespa"
        destination = "/opt/vespa/var"
      }

      logs {
        enabled       = true
        max_files     = 5
        max_file_size = 10
      }
    }

    volume "vespa" {
      type      = "host"
      read_only = false
      source    = "vespa"
    }
  }
}


