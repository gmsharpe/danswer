job "danswer" {
  datacenters = ["ats-1"]
  type      = "service"
  namespace = "danswer"
  node_pool = "danswer"

  vault {
    policies = ["nomad-cluster"]  # Vault policies required for this job
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
        image   = "danswer/danswer-backend:${IMAGE_TAG}"
        command = "/usr/bin/supervisord"
        args = ["-c", "/etc/supervisor/conf.d/supervisord.conf"]
      }

      resources {
        cpu    = 500
        memory = 4096
        disk   = 4000
      }

      vault {
        policies = ["nomad-cluster"]  # Specify the Vault policies to use
      }
      env {
        MODEL_SERVER_HOST = "model-server.service.consul"
        MODEL_SERVER_PORT = 9000
        INDEXING_MODEL_SERVER_HOST = "indexing-model-server.service.consul"
        POSTGRES_HOST = "relational-db.service.consul"
        VESPA_HOST = "index.service.consul"
      }


      # Template block to fetch Vault secrets
      template {
        data = <<EOH
        {{ with secret "secret/data/danswer" }}
        IMAGE_TAG={{ .Data.data.IMAGE_TAG }}
        ENCRYPTION_KEY_SECRET={{ .Data.data.ENCRYPTION_KEY_SECRET }}
        GEN_AI_MAX_TOKENS={{ .Data.data.GEN_AI_MAX_TOKENS }}
        QA_TIMEOUT={{ .Data.data.QA_TIMEOUT }}
        MAX_CHUNKS_FED_TO_CHAT={{ .Data.data.MAX_CHUNKS_FED_TO_CHAT }}
        DISABLE_LLM_CHOOSE_SEARCH={{ .Data.data.DISABLE_LLM_CHOOSE_SEARCH }}
        DISABLE_LLM_QUERY_REPHRASE={{ .Data.data.DISABLE_LLM_QUERY_REPHRASE }}
        DISABLE_GENERATIVE_AI={{ .Data.data.DISABLE_GENERATIVE_AI }}
        GENERATIVE_MODEL_ACCESS_CHECK_FREQ={{ .Data.data.GENERATIVE_MODEL_ACCESS_CHECK_FREQ }}
        DISABLE_LITELLM_STREAMING={{ .Data.data.DISABLE_LITELLM_STREAMING }}
        LITELLM_EXTRA_HEADERS={{ .Data.data.LITELLM_EXTRA_HEADERS }}
        BING_API_KEY={{ .Data.data.BING_API_KEY }}
        DOC_TIME_DECAY={{ .Data.data.DOC_TIME_DECAY }}
        HYBRID_ALPHA={{ .Data.data.HYBRID_ALPHA }}
        EDIT_KEYWORD_QUERY={{ .Data.data.EDIT_KEYWORD_QUERY }}
        MULTILINGUAL_QUERY_EXPANSION={{ .Data.data.MULTILINGUAL_QUERY_EXPANSION }}
        LANGUAGE_HINT={{ .Data.data.LANGUAGE_HINT }}
        LANGUAGE_CHAT_NAMING_HINT={{ .Data.data.LANGUAGE_CHAT_NAMING_HINT }}
        QA_PROMPT_OVERRIDE={{ .Data.data.QA_PROMPT_OVERRIDE }}
        POSTGRES_USER={{ .Data.data.POSTGRES_USER }}
        POSTGRES_PASSWORD={{ .Data.data.POSTGRES_PASSWORD }}
        POSTGRES_DB={{ .Data.data.POSTGRES_DB }}
        WEB_DOMAIN={{ .Data.data.WEB_DOMAIN }}
        DOCUMENT_ENCODER_MODEL={{ .Data.data.DOCUMENT_ENCODER_MODEL }}
        DOC_EMBEDDING_DIM={{ .Data.data.DOC_EMBEDDING_DIM }}
        NORMALIZE_EMBEDDINGS={{ .Data.data.NORMALIZE_EMBEDDINGS }}
        ASYM_QUERY_PREFIX={{ .Data.data.ASYM_QUERY_PREFIX }}
        ASYM_PASSAGE_PREFIX={{ .Data.data.ASYM_PASSAGE_PREFIX }}



        NUM_INDEXING_WORKERS={{ .Data.data.NUM_INDEXING_WORKERS }}
        ENABLED_CONNECTOR_TYPES={{ .Data.data.ENABLED_CONNECTOR_TYPES }}
        DISABLE_INDEX_UPDATE_ON_SWAP={{ .Data.data.DISABLE_INDEX_UPDATE_ON_SWAP }}
        DASK_JOB_CLIENT_ENABLED={{ .Data.data.DASK_JOB_CLIENT_ENABLED }}
        CONTINUE_ON_CONNECTOR_FAILURE={{ .Data.data.CONTINUE_ON_CONNECTOR_FAILURE }}
        EXPERIMENTAL_CHECKPOINTING_ENABLED={{ .Data.data.EXPERIMENTAL_CHECKPOINTING_ENABLED }}
        CONFLUENCE_CONNECTOR_LABELS_TO_SKIP={{ .Data.data.CONFLUENCE_CONNECTOR_LABELS_TO_SKIP }}
        JIRA_CONNECTOR_LABELS_TO_SKIP={{ .Data.data.JIRA_CONNECTOR_LABELS_TO_SKIP }}
        WEB_CONNECTOR_VALIDATE_URLS={{ .Data.data.WEB_CONNECTOR_VALIDATE_URLS }}
        JIRA_API_VERSION={{ .Data.data.JIRA_API_VERSION }}
        GONG_CONNECTOR_START_TIME={{ .Data.data.GONG_CONNECTOR_START_TIME }}
        NOTION_CONNECTOR_ENABLE_RECURSIVE_PAGE_LOOKUP={{ .Data.data.NOTION_CONNECTOR_ENABLE_RECURSIVE_PAGE_LOOKUP }}
        GITHUB_CONNECTOR_BASE_URL={{ .Data.data.GITHUB_CONNECTOR_BASE_URL }}
        DANSWER_BOT_SLACK_APP_TOKEN={{ .Data.data.DANSWER_BOT_SLACK_APP_TOKEN }}
        DANSWER_BOT_SLACK_BOT_TOKEN={{ .Data.data.DANSWER_BOT_SLACK_BOT_TOKEN }}
        DANSWER_BOT_DISABLE_DOCS_ONLY_ANSWER={{ .Data.data.DANSWER_BOT_DISABLE_DOCS_ONLY_ANSWER }}
        DANSWER_BOT_FEEDBACK_VISIBILITY={{ .Data.data.DANSWER_BOT_FEEDBACK_VISIBILITY }}
        DANSWER_BOT_DISPLAY_ERROR_MSGS={{ .Data.data.DANSWER_BOT_DISPLAY_ERROR_MSGS }}
        DANSWER_BOT_RESPOND_EVERY_CHANNEL={{ .Data.data.DANSWER_BOT_RESPOND_EVERY_CHANNEL }}
        DANSWER_BOT_DISABLE_COT={{ .Data.data.DANSWER_BOT_DISABLE_COT }}
        NOTIFY_SLACKBOT_NO_ANSWER={{ .Data.data.NOTIFY_SLACKBOT_NO_ANSWER }}
        DANSWER_BOT_MAX_QPM={{ .Data.data.DANSWER_BOT_MAX_QPM }}
        DANSWER_BOT_MAX_WAIT_TIME={{ .Data.data.DANSWER_BOT_MAX_WAIT_TIME }}
        DISABLE_TELEMETRY={{ .Data.data.DISABLE_TELEMETRY }}
        LOG_LEVEL={{ .Data.data.LOG_LEVEL }}
        LOG_ALL_MODEL_INTERACTIONS={{ .Data.data.LOG_ALL_MODEL_INTERACTIONS }}
        LOG_DANSWER_MODEL_INTERACTIONS={{ .Data.data.LOG_DANSWER_MODEL_INTERACTIONS }}
        LOG_VESPA_TIMING_INFORMATION={{ .Data.data.LOG_VESPA_TIMING_INFORMATION }}
        ENABLE_PAID_ENTERPRISE_EDITION_FEATURES={{ .Data.data.ENABLE_PAID_ENTERPRISE_EDITION_FEATURES }}
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
        name = "relational-db"
        tags = ["relational-db"]
        port = "db_port"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }


      logs {
        enabled       = true
        max_files     = 5
        max_file_size = 10
      }

    template {
      data = <<EOH
      {{ with secret "secret/data/danswer" }}
      POSTGRES_USER={{ .Data.data.POSTGRES_USER }}
      POSTGRES_PASSWORD={{ .Data.data.POSTGRES_PASSWORD }}
      {{ end }}
      EOH

      destination = "local/env.sh"
      env         = true
    }

      config {
        image = "postgres:15.2-alpine"
        command = "postgres"
        args = ["-c", "max_connections=150"]
        ports = ["db_port"]
      }

      vault {
        policies = ["nomad-cluster"]  # Specify the Vault policies to use
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
    ephemeral_disk {
      migrate = true
      size    = 10000
      sticky  = true
    }
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

    service {
      name = "model-server"
      port = "inference_http"
      check {
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

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
          "if [ \"${DISABLE_MODEL_SERVER}\" = \"True\" ]; then echo 'Skipping service...'; exit 0; else exec uvicorn model_server.main:app --host 0.0.0.0 --port ${NOMAD_PORT_inference_http}; fi"
        ]

        # Mount the Huggingface cache as a volume
        #volumes = ["model_cache_huggingface:/root/.cache/huggingface/"]
      }

      vault {
        policies = ["nomad-cluster"]  # Specify the Vault policies to use
      }

      # Environment Variables
#       env {
#         IMAGE_TAG                = "${IMAGE_TAG}"
#         MIN_THREADS_ML_MODELS     = "${MIN_THREADS_ML_MODELS}"
#         LOG_LEVEL                 = "${LOG_LEVEL}"
#         DISABLE_MODEL_SERVER      = "${DISABLE_MODEL_SERVER}"
#       }

      # Template block to fetch Vault secrets
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


      # Resources allocation
      resources {
        cpu    = 500

        memory = 4096
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

      service {
        name = "indexing-model-server"
        port = "indexing_http"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

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
          "if [ \"${DISABLE_MODEL_SERVER}\" = \"True\" ]; then echo 'Skipping service...'; exit 0; else exec uvicorn model_server.main:app --host 0.0.0.0 --port ${NOMAD_PORT_indexing_http}; fi"
        ]

        # Mount the Huggingface cache as a volume
        #volumes = ["indexing_model_cache_huggingface:/root/.cache/huggingface/"]
      }

      vault {
        policies = ["nomad-cluster"]  # Specify the Vault policies to use
      }

      # Environment block
#       env {
#         IMAGE_TAG                 = "${IMAGE_TAG}"
#         MIN_THREADS_ML_MODELS      = "${MIN_THREADS_ML_MODELS}"
#         INDEXING_ONLY              = "True"
#         LOG_LEVEL                  = "${LOG_LEVEL}"
#         DISABLE_MODEL_SERVER       = "${DISABLE_MODEL_SERVER}"
#       }

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


      # Resources allocation
      resources {
        cpu    = 500
        memory = 4096
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
      user = "root"
      service {
        name = "index"
        port = "vespa_admin"
        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }

      config {
        # https://hub.docker.com/r/vespaengine/vespa/
        image = "vespaengine/vespa:8.277.17"

        privileged = true

        # Set the container to run in the background with the appropriate ports
        ports = ["vespa_admin", "vespa_http"]
      }

      vault {
        policies = ["nomad-cluster"]  # Specify the Vault policies to use
      }

      env {
        VESPA_PORT = 19071
        #VESPA_TMP="/opt/vespa/var"
      }

      # Resources for the Vespa task
      resources {
        cpu = 1000   # 1000 MHz (1 core)
        memory = 4096   # 2 GB of RAM
      }

      # Restart policy (always restart)
      restart {
        attempts = 2  # Unlimited restarts
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


