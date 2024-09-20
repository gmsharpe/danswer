job "danswer" {
  datacenters = ["dc1"]
  type      = "service"
  namespace = "danswer"
  node_pool = "secondary"

  vault {
    policies = ["nomad-server"]  # Vault policies required for this job
  }

  group "background_group" {
    count = 1

    # Background Task
    task "background" {
      driver = "docker"

      logs {
        enabled       = true
        max_files     = 5
        max_file_size = 10
      }
      config {
        image   = "danswer/danswer-backend:${IMAGE_TAG}"
        command = "/usr/bin/supervisord"
        args = ["-c", "/etc/supervisor/conf.d/supervisord.conf"]
      }

      resources {
        cpu    = 500
        memory = 1024
      }

      vault {
        policies = ["nomad-server"]  # Specify the Vault policies to use
      }

      env {
        IMAGE_TAG                = "${NOMAD_VAR_IMAGE_TAG}"
        ENCRYPTION_KEY_SECRET     = "${NOMAD_VAR_ENCRYPTION_KEY_SECRET}"

        # Gen AI Settings (Needed by DanswerBot)
        GEN_AI_MAX_TOKENS          = "${NOMAD_VAR_GEN_AI_MAX_TOKENS}"
        QA_TIMEOUT                 = "${NOMAD_VAR_QA_TIMEOUT}"
        MAX_CHUNKS_FED_TO_CHAT     = "${NOMAD_VAR_MAX_CHUNKS_FED_TO_CHAT}"
        DISABLE_LLM_CHOOSE_SEARCH  = "${NOMAD_VAR_DISABLE_LLM_CHOOSE_SEARCH}"
        DISABLE_LLM_QUERY_REPHRASE = "${NOMAD_VAR_DISABLE_LLM_QUERY_REPHRASE}"
        DISABLE_GENERATIVE_AI      = "${NOMAD_VAR_DISABLE_GENERATIVE_AI}"
        GENERATIVE_MODEL_ACCESS_CHECK_FREQ = "${NOMAD_VAR_GENERATIVE_MODEL_ACCESS_CHECK_FREQ}"
        DISABLE_LITELLM_STREAMING  = "${NOMAD_VAR_DISABLE_LITELLM_STREAMING}"
        LITELLM_EXTRA_HEADERS      = "${NOMAD_VAR_LITELLM_EXTRA_HEADERS}"
        BING_API_KEY               = "${NOMAD_VAR_BING_API_KEY}"

        # Query Options
        DOC_TIME_DECAY = "${NOMAD_VAR_DOC_TIME_DECAY}"
        # Recency Bias for search results, decay at 1 / (1 + DOC_TIME_DECAY * x years)
        HYBRID_ALPHA = "${NOMAD_VAR_HYBRID_ALPHA}"
        # Hybrid Search Alpha (0 for entirely keyword, 1 for entirely vector)
        EDIT_KEYWORD_QUERY           = "${NOMAD_VAR_EDIT_KEYWORD_QUERY}"
        MULTILINGUAL_QUERY_EXPANSION = "${NOMAD_VAR_MULTILINGUAL_QUERY_EXPANSION}"
        LANGUAGE_HINT                = "${NOMAD_VAR_LANGUAGE_HINT}"
        LANGUAGE_CHAT_NAMING_HINT    = "${NOMAD_VAR_LANGUAGE_CHAT_NAMING_HINT}"
        QA_PROMPT_OVERRIDE           = "${NOMAD_VAR_QA_PROMPT_OVERRIDE}"

        # Other Services
        POSTGRES_HOST     = "relational_db"
        POSTGRES_USER     = "${NOMAD_VAR_POSTGRES_USER}"
        POSTGRES_PASSWORD = "${NOMAD_VAR_POSTGRES_PASSWORD}"
        POSTGRES_DB       = "${NOMAD_VAR_POSTGRES_DB}"
        VESPA_HOST        = "index"
        WEB_DOMAIN        = "${NOMAD_VAR_WEB_DOMAIN}"  # For frontend redirect auth purpose for OAuth2 connectors

        # Don't change the NLP model configs unless you know what you're doing
        DOCUMENT_ENCODER_MODEL = "${NOMAD_VAR_DOCUMENT_ENCODER_MODEL}"
        DOC_EMBEDDING_DIM      = "${NOMAD_VAR_DOC_EMBEDDING_DIM}"
        NORMALIZE_EMBEDDINGS   = "${NOMAD_VAR_NORMALIZE_EMBEDDINGS}"
        ASYM_QUERY_PREFIX      = "${NOMAD_VAR_ASYM_QUERY_PREFIX}"  # Needed by DanswerBot
        ASYM_PASSAGE_PREFIX    = "${NOMAD_VAR_ASYM_PASSAGE_PREFIX}"
        MODEL_SERVER_HOST      = "${NOMAD_VAR_MODEL_SERVER_HOST}"
        MODEL_SERVER_PORT      = "${NOMAD_VAR_MODEL_SERVER_PORT}"
        INDEXING_MODEL_SERVER_HOST = "${NOMAD_VAR_INDEXING_MODEL_SERVER_HOST}"

        # Indexing Configs
        NUM_INDEXING_WORKERS                          = "${NOMAD_VAR_NUM_INDEXING_WORKERS}"
        ENABLED_CONNECTOR_TYPES                       = "${NOMAD_VAR_ENABLED_CONNECTOR_TYPES}"
        DISABLE_INDEX_UPDATE_ON_SWAP                  = "${NOMAD_VAR_DISABLE_INDEX_UPDATE_ON_SWAP}"
        DASK_JOB_CLIENT_ENABLED                       = "${NOMAD_VAR_DASK_JOB_CLIENT_ENABLED}"
        CONTINUE_ON_CONNECTOR_FAILURE                 = "${NOMAD_VAR_CONTINUE_ON_CONNECTOR_FAILURE}"
        EXPERIMENTAL_CHECKPOINTING_ENABLED            = "${NOMAD_VAR_EXPERIMENTAL_CHECKPOINTING_ENABLED}"
        CONFLUENCE_CONNECTOR_LABELS_TO_SKIP           = "${NOMAD_VAR_CONFLUENCE_CONNECTOR_LABELS_TO_SKIP}"
        JIRA_CONNECTOR_LABELS_TO_SKIP                 = "${NOMAD_VAR_JIRA_CONNECTOR_LABELS_TO_SKIP}"
        WEB_CONNECTOR_VALIDATE_URLS                   = "${NOMAD_VAR_WEB_CONNECTOR_VALIDATE_URLS}"
        JIRA_API_VERSION                              = "${NOMAD_VAR_JIRA_API_VERSION}"
        GONG_CONNECTOR_START_TIME                     = "${NOMAD_VAR_GONG_CONNECTOR_START_TIME}"
        NOTION_CONNECTOR_ENABLE_RECURSIVE_PAGE_LOOKUP = "${NOMAD_VAR_NOTION_CONNECTOR_ENABLE_RECURSIVE_PAGE_LOOKUP}"
        GITHUB_CONNECTOR_BASE_URL                     = "${NOMAD_VAR_GITHUB_CONNECTOR_BASE_URL}"

        # Danswer SlackBot Configs
        DANSWER_BOT_SLACK_APP_TOKEN          = "${NOMAD_VAR_DANSWER_BOT_SLACK_APP_TOKEN}"
        DANSWER_BOT_SLACK_BOT_TOKEN          = "${NOMAD_VAR_DANSWER_BOT_SLACK_BOT_TOKEN}"
        DANSWER_BOT_DISABLE_DOCS_ONLY_ANSWER = "${NOMAD_VAR_DANSWER_BOT_DISABLE_DOCS_ONLY_ANSWER}"
        DANSWER_BOT_FEEDBACK_VISIBILITY      = "${NOMAD_VAR_DANSWER_BOT_FEEDBACK_VISIBILITY}"
        DANSWER_BOT_DISPLAY_ERROR_MSGS       = "${NOMAD_VAR_DANSWER_BOT_DISPLAY_ERROR_MSGS}"
        DANSWER_BOT_RESPOND_EVERY_CHANNEL    = "${NOMAD_VAR_DANSWER_BOT_RESPOND_EVERY_CHANNEL}"
        DANSWER_BOT_DISABLE_COT              = "${NOMAD_VAR_DANSWER_BOT_DISABLE_COT}"  # Currently unused
        NOTIFY_SLACKBOT_NO_ANSWER            = "${NOMAD_VAR_NOTIFY_SLACKBOT_NO_ANSWER}"
        DANSWER_BOT_MAX_QPM                  = "${NOMAD_VAR_DANSWER_BOT_MAX_QPM}"
        DANSWER_BOT_MAX_WAIT_TIME            = "${NOMAD_VAR_DANSWER_BOT_MAX_WAIT_TIME}"

        # Logging
        # Leave this on pretty please? Nothing sensitive is collected!
        # https://docs.danswer.dev/more/telemetry
        DISABLE_TELEMETRY              = "${NOMAD_VAR_DISABLE_TELEMETRY}"
        LOG_LEVEL                      = "${NOMAD_VAR_LOG_LEVEL}"  # Set to debug to get more fine-grained logs
        # Log all of Danswer prompts and interactions with the LLM
        LOG_ALL_MODEL_INTERACTIONS     = "${NOMAD_VAR_LOG_ALL_MODEL_INTERACTIONS}"  # LiteLLM Verbose Logging
        LOG_DANSWER_MODEL_INTERACTIONS = "${NOMAD_VAR_LOG_DANSWER_MODEL_INTERACTIONS}"
        LOG_VESPA_TIMING_INFORMATION   = "${NOMAD_VAR_LOG_VESPA_TIMING_INFORMATION}"

        # Enterprise Edition stuff
        ENABLE_PAID_ENTERPRISE_EDITION_FEATURES = "${NOMAD_VAR_ENABLE_PAID_ENTERPRISE_EDITION_FEATURES}"
      }

      # Template block to fetch Vault secrets
      template {
        data = <<EOH
        {{ with secret "secret/data/danswer" }}
        NOMAD_VAR_IMAGE_TAG={{ .Data.data.IMAGE_TAG }}
        NOMAD_VAR_ENCRYPTION_KEY_SECRET={{ .Data.data.ENCRYPTION_KEY_SECRET }}
        NOMAD_VAR_GEN_AI_MAX_TOKENS={{ .Data.data.GEN_AI_MAX_TOKENS }}
        NOMAD_VAR_QA_TIMEOUT={{ .Data.data.QA_TIMEOUT }}
        NOMAD_VAR_MAX_CHUNKS_FED_TO_CHAT={{ .Data.data.MAX_CHUNKS_FED_TO_CHAT }}
        NOMAD_VAR_DISABLE_LLM_CHOOSE_SEARCH={{ .Data.data.DISABLE_LLM_CHOOSE_SEARCH }}
        NOMAD_VAR_DISABLE_LLM_QUERY_REPHRASE={{ .Data.data.DISABLE_LLM_QUERY_REPHRASE }}
        NOMAD_VAR_DISABLE_GENERATIVE_AI={{ .Data.data.DISABLE_GENERATIVE_AI }}
        NOMAD_VAR_GENERATIVE_MODEL_ACCESS_CHECK_FREQ={{ .Data.data.GENERATIVE_MODEL_ACCESS_CHECK_FREQ }}
        NOMAD_VAR_DISABLE_LITELLM_STREAMING={{ .Data.data.DISABLE_LITELLM_STREAMING }}
        NOMAD_VAR_LITELLM_EXTRA_HEADERS={{ .Data.data.LITELLM_EXTRA_HEADERS }}
        NOMAD_VAR_BING_API_KEY={{ .Data.data.BING_API_KEY }}
        NOMAD_VAR_DOC_TIME_DECAY={{ .Data.data.DOC_TIME_DECAY }}
        NOMAD_VAR_HYBRID_ALPHA={{ .Data.data.HYBRID_ALPHA }}
        NOMAD_VAR_EDIT_KEYWORD_QUERY={{ .Data.data.EDIT_KEYWORD_QUERY }}
        NOMAD_VAR_MULTILINGUAL_QUERY_EXPANSION={{ .Data.data.MULTILINGUAL_QUERY_EXPANSION }}
        NOMAD_VAR_LANGUAGE_HINT={{ .Data.data.LANGUAGE_HINT }}
        NOMAD_VAR_LANGUAGE_CHAT_NAMING_HINT={{ .Data.data.LANGUAGE_CHAT_NAMING_HINT }}
        NOMAD_VAR_QA_PROMPT_OVERRIDE={{ .Data.data.QA_PROMPT_OVERRIDE }}
        NOMAD_VAR_POSTGRES_USER={{ .Data.data.POSTGRES_USER }}
        NOMAD_VAR_POSTGRES_PASSWORD={{ .Data.data.POSTGRES_PASSWORD }}
        NOMAD_VAR_POSTGRES_DB={{ .Data.data.POSTGRES_DB }}
        NOMAD_VAR_WEB_DOMAIN={{ .Data.data.WEB_DOMAIN }}
        NOMAD_VAR_DOCUMENT_ENCODER_MODEL={{ .Data.data.DOCUMENT_ENCODER_MODEL }}
        NOMAD_VAR_DOC_EMBEDDING_DIM={{ .Data.data.DOC_EMBEDDING_DIM }}
        NOMAD_VAR_NORMALIZE_EMBEDDINGS={{ .Data.data.NORMALIZE_EMBEDDINGS }}
        NOMAD_VAR_ASYM_QUERY_PREFIX={{ .Data.data.ASYM_QUERY_PREFIX }}
        NOMAD_VAR_ASYM_PASSAGE_PREFIX={{ .Data.data.ASYM_PASSAGE_PREFIX }}
        NOMAD_VAR_MODEL_SERVER_HOST={{ .Data.data.MODEL_SERVER_HOST }}
        NOMAD_VAR_MODEL_SERVER_PORT={{ .Data.data.MODEL_SERVER_PORT }}
        NOMAD_VAR_INDEXING_MODEL_SERVER_HOST={{ .Data.data.INDEXING_MODEL_SERVER_HOST }}
        NOMAD_VAR_NUM_INDEXING_WORKERS={{ .Data.data.NUM_INDEXING_WORKERS }}
        NOMAD_VAR_ENABLED_CONNECTOR_TYPES={{ .Data.data.ENABLED_CONNECTOR_TYPES }}
        NOMAD_VAR_DISABLE_INDEX_UPDATE_ON_SWAP={{ .Data.data.DISABLE_INDEX_UPDATE_ON_SWAP }}
        NOMAD_VAR_DASK_JOB_CLIENT_ENABLED={{ .Data.data.DASK_JOB_CLIENT_ENABLED }}
        NOMAD_VAR_CONTINUE_ON_CONNECTOR_FAILURE={{ .Data.data.CONTINUE_ON_CONNECTOR_FAILURE }}
        NOMAD_VAR_EXPERIMENTAL_CHECKPOINTING_ENABLED={{ .Data.data.EXPERIMENTAL_CHECKPOINTING_ENABLED }}
        NOMAD_VAR_CONFLUENCE_CONNECTOR_LABELS_TO_SKIP={{ .Data.data.CONFLUENCE_CONNECTOR_LABELS_TO_SKIP }}
        NOMAD_VAR_JIRA_CONNECTOR_LABELS_TO_SKIP={{ .Data.data.JIRA_CONNECTOR_LABELS_TO_SKIP }}
        NOMAD_VAR_WEB_CONNECTOR_VALIDATE_URLS={{ .Data.data.WEB_CONNECTOR_VALIDATE_URLS }}
        NOMAD_VAR_JIRA_API_VERSION={{ .Data.data.JIRA_API_VERSION }}
        NOMAD_VAR_GONG_CONNECTOR_START_TIME={{ .Data.data.GONG_CONNECTOR_START_TIME }}
        NOMAD_VAR_NOTION_CONNECTOR_ENABLE_RECURSIVE_PAGE_LOOKUP={{ .Data.data.NOTION_CONNECTOR_ENABLE_RECURSIVE_PAGE_LOOKUP }}
        NOMAD_VAR_GITHUB_CONNECTOR_BASE_URL={{ .Data.data.GITHUB_CONNECTOR_BASE_URL }}
        NOMAD_VAR_DANSWER_BOT_SLACK_APP_TOKEN={{ .Data.data.DANSWER_BOT_SLACK_APP_TOKEN }}
        NOMAD_VAR_DANSWER_BOT_SLACK_BOT_TOKEN={{ .Data.data.DANSWER_BOT_SLACK_BOT_TOKEN }}
        NOMAD_VAR_DANSWER_BOT_DISABLE_DOCS_ONLY_ANSWER={{ .Data.data.DANSWER_BOT_DISABLE_DOCS_ONLY_ANSWER }}
        NOMAD_VAR_DANSWER_BOT_FEEDBACK_VISIBILITY={{ .Data.data.DANSWER_BOT_FEEDBACK_VISIBILITY }}
        NOMAD_VAR_DANSWER_BOT_DISPLAY_ERROR_MSGS={{ .Data.data.DANSWER_BOT_DISPLAY_ERROR_MSGS }}
        NOMAD_VAR_DANSWER_BOT_RESPOND_EVERY_CHANNEL={{ .Data.data.DANSWER_BOT_RESPOND_EVERY_CHANNEL }}
        NOMAD_VAR_DANSWER_BOT_DISABLE_COT={{ .Data.data.DANSWER_BOT_DISABLE_COT }}
        NOMAD_VAR_NOTIFY_SLACKBOT_NO_ANSWER={{ .Data.data.NOTIFY_SLACKBOT_NO_ANSWER }}
        NOMAD_VAR_DANSWER_BOT_MAX_QPM={{ .Data.data.DANSWER_BOT_MAX_QPM }}
        NOMAD_VAR_DANSWER_BOT_MAX_WAIT_TIME={{ .Data.data.DANSWER_BOT_MAX_WAIT_TIME }}
        NOMAD_VAR_DISABLE_TELEMETRY={{ .Data.data.DISABLE_TELEMETRY }}
        NOMAD_VAR_LOG_LEVEL={{ .Data.data.LOG_LEVEL }}
        NOMAD_VAR_LOG_ALL_MODEL_INTERACTIONS={{ .Data.data.LOG_ALL_MODEL_INTERACTIONS }}
        NOMAD_VAR_LOG_DANSWER_MODEL_INTERACTIONS={{ .Data.data.LOG_DANSWER_MODEL_INTERACTIONS }}
        NOMAD_VAR_LOG_VESPA_TIMING_INFORMATION={{ .Data.data.LOG_VESPA_TIMING_INFORMATION }}
        NOMAD_VAR_ENABLE_PAID_ENTERPRISE_EDITION_FEATURES={{ .Data.data.ENABLE_PAID_ENTERPRISE_EDITION_FEATURES }}
        {{ end }}
        EOH

        destination = "local/env.sh"
        env         = true
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

      service {
        name = "danswer-db"
        tags = ["danswer-db"]
        port = "db_port"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      network {
        port "db_port" {
          static = 5432
        }
      }
      logs {
        enabled       = true
        max_files     = 5
        max_file_size = 10
      }
      config {
        image = "postgres:15.2-alpine"
        command = "postgres"
        args = ["-c", "max_connections=150"]
        ports = ["db_port"]
      }

      vault {
        policies = ["nomad-server"]  # Specify the Vault policies to use
      }
      # Template block to fetch Vault secrets
      template {
        data = <<EOH
        {{ with secret "secret/data/danswer" }}
        NOMAD_VAR_POSTGRES_USER={{ .Data.data.POSTGRES_USER }}
        NOMAD_VAR_POSTGRES_PASSWORD={{ .Data.data.POSTGRES_PASSWORD }}
        {{ end }}
        EOH

        destination = "local/env.sh"
        env         = true
      }
      env {
        POSTGRES_USER        = "${NOMAD_VAR_POSTGRES_USER}"
        POSTGRES_PASSWORD    = "${NOMAD_VAR_POSTGRES_PASSWORD}"
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
        image = "danswer/danswer-model-server:${IMAGE_TAG}"

        ports = ["inference_http", "indexing_http"]

        # Command block to handle conditional logic
        command = "/bin/sh"
        args = [
          "-c",
          "if [ \"${DISABLE_MODEL_SERVER}\" = \"True\" ]; then echo 'Skipping service...'; exit 0; else exec uvicorn model_server.main:app --host 0.0.0.0 --port 9000; fi"
        ]

        # Mount the Huggingface cache as a volume
        volumes = ["model_cache_huggingface:/root/.cache/huggingface/"]
      }

      vault {
        policies = ["nomad-server"]  # Specify the Vault policies to use
      }

      # Environment Variables
      env {
        IMAGE_TAG                = "${NOMAD_VAR_IMAGE_TAG}"
        MIN_THREADS_ML_MODELS     = "${NOMAD_VAR_MIN_THREADS_ML_MODELS}"
        LOG_LEVEL                 = "${NOMAD_VAR_LOG_LEVEL}"
        DISABLE_MODEL_SERVER      = "${NOMAD_VAR_DISABLE_MODEL_SERVER}"
      }

      # Template block to fetch Vault secrets
      template {
        data = <<EOH
        {{ with secret "secret/data/danswer" }}
        NOMAD_VAR_IMAGE_TAG={{ .Data.data.IMAGE_TAG }}
        NOMAD_VAR_MIN_THREADS_ML_MODELS={{ .Data.data.MIN_THREADS_ML_MODELS }}
        NOMAD_VAR_LOG_LEVEL={{ .Data.data.LOG_LEVEL }}
        NOMAD_VAR_DISABLE_MODEL_SERVER={{ .Data.data.DISABLE_MODEL_SERVER }}
        {{ end }}
        EOH

        destination = "local/env.sh"
        env         = true
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
        image = "danswer/danswer-model-server:${IMAGE_TAG}"

        # Command block to handle conditional logic
        command = "/bin/sh"
        args = [
          "-c",
          "if [ \"${DISABLE_MODEL_SERVER}\" = \"True\" ]; then echo 'Skipping service...'; exit 0; else exec uvicorn model_server.main:app --host 0.0.0.0 --port 9000; fi"
        ]

        # Mount the Huggingface cache as a volume
        volumes = ["indexing_model_cache_huggingface:/root/.cache/huggingface/"]
      }

      vault {
        policies = ["nomad-server"]  # Specify the Vault policies to use
      }

      # Environment block
      env {
        IMAGE_TAG                 = "${IMAGE_TAG}"
        MIN_THREADS_ML_MODELS      = "${NOMAD_VAR_MIN_THREADS_ML_MODELS}"
        INDEXING_ONLY              = "True"
        LOG_LEVEL                  = "${NOMAD_VAR_LOG_LEVEL}"
        DISABLE_MODEL_SERVER       = "${NOMAD_VAR_DISABLE_MODEL_SERVER}"
      }

      # Template to fetch Vault secrets
      template {
        data = <<EOH
        {{ with secret "secret/data/danswer" }}
        IMAGE_TAG={{ .Data.data.IMAGE_TAG }}
        NOMAD_VAR_MIN_THREADS_ML_MODELS={{ .Data.data.MIN_THREADS_ML_MODELS }}
        NOMAD_VAR_LOG_LEVEL={{ .Data.data.LOG_LEVEL }}
        NOMAD_VAR_DISABLE_MODEL_SERVER={{ .Data.data.DISABLE_MODEL_SERVER }}
        {{ end }}
        EOH

        destination = "local/env.sh"
        env         = true
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
        ports = ["vespa_admin", "vespa_http"]
      }

      vault {
        policies = ["nomad-server"]  # Specify the Vault policies to use
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


