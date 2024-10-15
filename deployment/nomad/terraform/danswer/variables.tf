# Vault

# variable "vault_unseal_key" {
#   sensitive = true
# }
#
# variable "vault_root_token" {
#   sensitive = true
# }
#
# variable "nomad_token" {
#   sensitive = true
# }

# Misc Variables

variable "image_tag" {
  type        = string
  description = "Docker image tag for the application."
  default     = "latest"
}

variable "domain" {
  type        = string
  description = "Domain used for Nginx configuration."
  default     = "localhost"
}


# Authentication Settings

variable "auth_type" {
  type        = string
  description = "Authentication type for the application."
  default     = null
}

variable "session_expire_time_seconds" {
  type        = number
  description = "Session expiration time in seconds."
  default     = 86400  # Default to 24 hours
}

variable "encryption_key_secret" {
  type        = string
  description = "Secret key used for encryption."
  sensitive   = true
}

variable "valid_email_domains" {
  type        = list(string)
  description = "List of valid email domains for user registration."
  default     = []
}

variable "google_oauth_client_id" {
  type        = string
  description = "Google OAuth client ID."
  default = null
}

variable "google_oauth_client_secret" {
  type        = string
  description = "Google OAuth client secret."
  default = null
  sensitive   = true
}

variable "require_email_verification" {
  type        = bool
  description = "Whether to require email verification for new users."
  default     = false
}

variable "smtp_server" {
  type        = string
  description = "SMTP server address for email notifications."
  default     = "smtp.gmail.com"
}

variable "smtp_port" {
  type        = number
  description = "SMTP server port."
  default     = 587
}

variable "smtp_user" {
  type        = string
  description = "SMTP username for authentication."
  default = null
}

variable "smtp_pass" {
  type        = string
  description = "SMTP password for authentication."
  default = null
  sensitive   = true
}

variable "email_from" {
  type        = string
  description = "Email address used in the 'From' field of emails sent."
  default = null
}

variable "oauth_client_id" {
  type        = string
  description = "OAuth client ID for OpenID Connect."
  default = null
}

variable "oauth_client_secret" {
  type        = string
  description = "OAuth client secret for OpenID Connect."
  sensitive   = true
  default = null
}

variable "openid_config_url" {
  type        = string
  description = "OpenID configuration URL."
  default = null
}

variable "track_external_idp_expiry" {
  type        = bool
  description = "Track external Identity Provider token expiry."
  default     = false
}


# Gen AI Settings

variable "gen_ai_max_tokens" {
  type        = number
  description = "Maximum tokens for generative AI responses."
  default     = 2048
}

variable "qa_timeout" {
  type        = number
  description = "Timeout for QA processes in seconds."
  default     = 60
}

variable "max_chunks_fed_to_chat" {
  type        = number
  description = "Maximum number of data chunks fed to the chat model."
  default     = 10
}

variable "disable_llm_choose_search" {
  type        = bool
  description = "Disable LLM's ability to choose search results."
  default     = false
}

variable "disable_llm_query_rephrase" {
  type        = bool
  description = "Disable LLM query rephrasing."
  default     = false
}

variable "disable_generative_ai" {
  type        = bool
  description = "Completely disable generative AI functionalities."
  default     = false
}

variable "disable_litellm_streaming" {
  type        = bool
  description = "Disable streaming responses from LiteLLM."
  default     = false
}

variable "litellm_extra_headers" {
  type        = map(string)
  description = "Extra headers to pass to LiteLLM API requests."
  default     = {}
}

variable "bing_api_key" {
  type        = string
  description = "API key for Bing services."
  sensitive   = true
  default = null
}

variable "disable_llm_doc_relevance" {
  type        = bool
  description = "Disable LLM document relevance ranking."
  default     = false
}

variable "token_budget_globally_enabled" {
  type        = bool
  description = "Enable token budget system globally."
  default     = false
}

variable "aws_access_key_id" {
  type        = string
  description = "AWS Access Key ID for Bedrock models."
  sensitive   = true
  default = null
}

variable "aws_secret_access_key" {
  type        = string
  description = "AWS Secret Access Key for Bedrock models."
  sensitive   = true
  default = null
}

variable "aws_region_name" {
  type        = string
  description = "AWS region name for Bedrock services."
  default     = "us-east-1"
}

variable "generative_model_access_check_freq" {
  type        = number
  description = "Frequency in seconds to check generative model access."
  default     = 600
}

# Query Options
variable "doc_time_decay" {
  type        = number
  description = "Recency bias for search results (decay factor)."
  default     = 0.0
}

variable "hybrid_alpha" {
  type        = number
  description = "Hybrid Search Alpha value (0 for keyword, 1 for vector)."
  default     = 0.5
}

variable "edit_keyword_query" {
  type        = bool
  description = "Allow editing of keyword queries."
  default     = false
}

variable "multilingual_query_expansion" {
  type        = bool
  description = "Enable multilingual query expansion."
  default     = false
}

variable "language_hint" {
  type        = string
  description = "Language hint for processing queries."
  default     = "en"
}

variable "language_chat_naming_hint" {
  type        = string
  description = "Language hint for naming chat sessions."
  default     = "en"
}

variable "qa_prompt_override" {
  type        = string
  description = "Override the default QA prompt."
  default     = null
}


# Other Services
variable "web_domain" {
  type        = string
  description = "Web domain for frontend redirect purposes."
  default     = null
}

variable "document_encoder_model" {
  type        = string
  description = "Model used for document encoding."
  default     = "default_encoder_model"
}

variable "doc_embedding_dim" {
  type        = number
  description = "Dimension of document embeddings."
  default     = 768
}

variable "normalize_embeddings" {
  type        = bool
  description = "Whether to normalize embeddings."
  default     = false
}

variable "asym_query_prefix" {
  type        = string
  description = "Asymmetric query prefix for encoding."
  default     = null
}

variable "asym_passage_prefix" {
  type        = string
  description = "Asymmetric passage prefix for encoding."
  default     = null
}

variable "disable_rerank_for_streaming" {
  type        = bool
  description = "Disable reranking when streaming responses."
  default     = false
}

variable "model_server_host" {
  type        = string
  description = "Host address for the model server."
  default     = "localhost"
}

variable "model_server_port" {
  type        = number
  description = "Port for the model server."
  default     = 9000
}

variable "indexing_model_server_host" {
  type        = string
  description = "Host address for the indexing model server."
  default     = "localhost"
}

# Logging and Telemetry
variable "disable_telemetry" {
  type        = bool
  description = "Disable telemetry data collection."
  default     = false
}

variable "log_level" {
  type        = string
  description = "Logging level (e.g., debug, info, warn, error)."
  default     = "info"
}

variable "log_all_model_interactions" {
  type        = bool
  description = "Enable verbose logging for all model interactions."
  default     = false
}

variable "log_danswer_model_interactions" {
  type        = bool
  description = "Log all prompts and interactions with the LLM."
  default     = false
}

variable "log_vespa_timing_information" {
  type        = bool
  description = "Log Vespa query performance metrics."
  default     = false
}

variable "log_endpoint_latency" {
  type        = bool
  description = "Log latency information for endpoints."
  default     = false
}

variable "log_postgres_latency" {
  type        = bool
  description = "Log latency information for Postgres operations."
  default     = false
}

variable "log_postgres_conn_counts" {
  type        = bool
  description = "Log Postgres connection counts."
  default     = false
}

# Enterprise Edition
variable "enable_paid_enterprise_edition_features" {
  type        = bool
  description = "Enable features exclusive to the paid enterprise edition."
  default     = false
}

variable "api_key_hash_rounds" {
  type        = number
  description = "Number of hash rounds for API key security."
  default     = 10000
}

variable "env_seed_configuration" {
  type        = string
  description = "Seed configuration for the environment."
  default     = null
}

# Frontend Settings

variable "next_public_disable_streaming" {
  type        = bool
  description = "Disable streaming in the frontend application."
  default     = false
}

variable "next_public_new_chat_directs_to_same_persona" {
  type        = bool
  description = "New chat sessions direct to the same persona."
  default     = false
}

variable "next_public_positive_predefined_feedback_options" {
  type        = list(string)
  description = "Positive feedback options in the frontend."
  default     = []
}

variable "next_public_negative_predefined_feedback_options" {
  type        = list(string)
  description = "Negative feedback options in the frontend."
  default     = []
}

variable "next_public_disable_logout" {
  type        = bool
  description = "Disable the logout functionality in the frontend."
  default     = false
}

variable "next_public_default_sidebar_open" {
  type        = bool
  description = "Set the default state of the sidebar to open."
  default     = true
}

variable "next_public_theme" {
  type        = string
  description = "Theme setting for the frontend (e.g., light, dark)."
  default     = "light"
}

variable "next_public_do_not_use_toggle_off_danswer_powered" {
  type        = bool
  description = "Disable the toggle to turn off 'Danswer Powered' branding."
  default     = false
}

variable "theme_is_dark" {
  type        = bool
  description = "Indicates if the default theme is dark."
  default     = false
}

# Database Settings
variable "postgres_user" {
  type        = string
  description = "Username for the Postgres database."
  default     = "postgres"
}

variable "postgres_password" {
  type        = string
  description = "Password for the Postgres database." 
  default = null
  sensitive   = true
}

variable "postgres_db" {
  type        = string
  description = "Database name for Postgres."
  default     = "postgres"
}

# Indexing Configurations
variable "num_indexing_workers" {
  type        = number
  description = "Number of workers for indexing operations."
  default     = 1
}

variable "enabled_connector_types" {
  type        = list(string)
  description = "Types of connectors enabled for indexing."
  default     = []
}

variable "disable_index_update_on_swap" {
  type        = bool
  description = "Disable index updates when swapping."
  default     = false
}

variable "dask_job_client_enabled" {
  type        = bool
  description = "Enable Dask job client for distributed tasks."
  default     = false
}

variable "continue_on_connector_failure" {
  type        = bool
  description = "Continue indexing even if a connector fails."
  default     = false
}

variable "experimental_checkpointing_enabled" {
  type        = bool
  description = "Enable experimental checkpointing features."
  default     = false
}

variable "confluence_connector_labels_to_skip" {
  type        = list(string)
  description = "Labels to skip in the Confluence connector."
  default     = []
}

variable "jira_connector_labels_to_skip" {
  type        = list(string)
  description = "Labels to skip in the JIRA connector."
  default     = []
}

variable "web_connector_validate_urls" {
  type        = bool
  description = "Validate URLs in the web connector."
  default     = true
}

variable "jira_api_version" {
  type        = string
  description = "API version to use with JIRA."
  default     = "2"
}

variable "gong_connector_start_time" {
  type        = string
  description = "Start time for the Gong connector data fetch."
  default     = null
}

variable "notion_connector_enable_recursive_page_lookup" {
  type        = bool
  description = "Enable recursive page lookup in Notion connector."
  default     = false
}

variable "github_connector_base_url" {
  type        = string
  description = "Base URL for the GitHub connector API."
  default     = "https://api.github.com"
}

# SlackBot Configurations

variable "danswer_bot_slack_app_token" {
  type        = string
  description = "Slack App Token for Danswer Bot."
  sensitive   = true
  default = null
}

variable "danswer_bot_slack_bot_token" {
  type        = string
  description = "Slack Bot Token for Danswer Bot."
  sensitive   = true
  default = null
}

variable "danswer_bot_disable_docs_only_answer" {
  type        = bool
  description = "Disable document-only answers in Danswer Bot."
  default     = false
}

variable "danswer_bot_feedback_visibility" {
  type        = string
  description = "Feedback visibility setting for Danswer Bot."
  default     = "public"
}

variable "danswer_bot_display_error_msgs" {
  type        = bool
  description = "Display error messages in Danswer Bot."
  default     = false
}

variable "danswer_bot_respond_every_channel" {
  type        = bool
  description = "Allow Danswer Bot to respond in every channel."
  default     = false
}

variable "danswer_bot_disable_cot" {
  type        = bool
  description = "Disable Chain-of-Thought in Danswer Bot."
  default     = false
}

variable "notify_slackbot_no_answer" {
  type        = bool
  description = "Notify via Slackbot when no answer is found."
  default     = false
}

variable "danswer_bot_max_qpm" {
  type        = number
  description = "Maximum queries per minute for Danswer Bot."
  default     = 60
}

variable "danswer_bot_max_wait_time" {
  type        = number
  description = "Maximum wait time in seconds for Danswer Bot responses."
  default     = 30
}

# Model Server Settings

variable "min_threads_ml_models" {
  type        = number
  description = "Minimum number of threads for ML models."
  default     = 1
}

variable "disable_model_server" {
  type        = bool
  description = "Disable the model server."
  default     = false
}


# Define locals with references to variables
locals {
  namespace_meta = {
 # Authentication Settings
    AUTH_TYPE                   = var.auth_type
    SESSION_EXPIRE_TIME_SECONDS = var.session_expire_time_seconds
    ENCRYPTION_KEY_SECRET       = var.encryption_key_secret
    VALID_EMAIL_DOMAINS         = jsonencode(var.valid_email_domains)
    GOOGLE_OAUTH_CLIENT_ID      = var.google_oauth_client_id
    GOOGLE_OAUTH_CLIENT_SECRET  = var.google_oauth_client_secret
    REQUIRE_EMAIL_VERIFICATION  = var.require_email_verification
    SMTP_SERVER                 = var.smtp_server
    SMTP_PORT                   = var.smtp_port
    SMTP_USER                   = var.smtp_user
    SMTP_PASS                   = var.smtp_pass
    EMAIL_FROM                  = var.email_from
    OAUTH_CLIENT_ID             = var.oauth_client_id
    OAUTH_CLIENT_SECRET         = var.oauth_client_secret
    OPENID_CONFIG_URL           = var.openid_config_url
    TRACK_EXTERNAL_IDP_EXPIRY   = var.track_external_idp_expiry

    # Gen AI Settings
    GEN_AI_MAX_TOKENS                 = var.gen_ai_max_tokens
    QA_TIMEOUT                        = var.qa_timeout
    MAX_CHUNKS_FED_TO_CHAT            = var.max_chunks_fed_to_chat
    DISABLE_LLM_CHOOSE_SEARCH         = var.disable_llm_choose_search
    DISABLE_LLM_QUERY_REPHRASE        = var.disable_llm_query_rephrase
    DISABLE_GENERATIVE_AI             = var.disable_generative_ai
    DISABLE_LITELLM_STREAMING         = var.disable_litellm_streaming
    LITELLM_EXTRA_HEADERS             = jsonencode(var.litellm_extra_headers)
    BING_API_KEY                      = var.bing_api_key
    DISABLE_LLM_DOC_RELEVANCE         = var.disable_llm_doc_relevance
    TOKEN_BUDGET_GLOBALLY_ENABLED     = var.token_budget_globally_enabled
    AWS_ACCESS_KEY_ID                 = var.aws_access_key_id
    AWS_SECRET_ACCESS_KEY             = var.aws_secret_access_key
    AWS_REGION_NAME                   = var.aws_region_name
    GENERATIVE_MODEL_ACCESS_CHECK_FREQ = var.generative_model_access_check_freq

    # Query Options
    DOC_TIME_DECAY                   = var.doc_time_decay
    HYBRID_ALPHA                     = var.hybrid_alpha
    EDIT_KEYWORD_QUERY               = var.edit_keyword_query
    MULTILINGUAL_QUERY_EXPANSION     = var.multilingual_query_expansion
    LANGUAGE_HINT                    = var.language_hint
    LANGUAGE_CHAT_NAMING_HINT        = var.language_chat_naming_hint
    QA_PROMPT_OVERRIDE               = var.qa_prompt_override

    # Other Services
    WEB_DOMAIN                       = var.web_domain
    DOCUMENT_ENCODER_MODEL           = var.document_encoder_model
    DOC_EMBEDDING_DIM                = var.doc_embedding_dim
    NORMALIZE_EMBEDDINGS             = var.normalize_embeddings
    ASYM_QUERY_PREFIX                = var.asym_query_prefix
    ASYM_PASSAGE_PREFIX              = var.asym_passage_prefix
    DISABLE_RERANK_FOR_STREAMING     = var.disable_rerank_for_streaming
    MODEL_SERVER_HOST                = var.model_server_host
    MODEL_SERVER_PORT                = var.model_server_port
    INDEXING_MODEL_SERVER_HOST       = var.indexing_model_server_host

    # Logging and Telemetry
    DISABLE_TELEMETRY                = var.disable_telemetry
    LOG_LEVEL                        = var.log_level
    LOG_ALL_MODEL_INTERACTIONS       = var.log_all_model_interactions
    LOG_DANSWER_MODEL_INTERACTIONS   = var.log_danswer_model_interactions
    LOG_VESPA_TIMING_INFORMATION     = var.log_vespa_timing_information
    LOG_ENDPOINT_LATENCY             = var.log_endpoint_latency
    LOG_POSTGRES_LATENCY             = var.log_postgres_latency
    LOG_POSTGRES_CONN_COUNTS         = var.log_postgres_conn_counts

    # Enterprise Edition
    ENABLE_PAID_ENTERPRISE_EDITION_FEATURES = var.enable_paid_enterprise_edition_features
    API_KEY_HASH_ROUNDS                     = var.api_key_hash_rounds
    ENV_SEED_CONFIGURATION                  = var.env_seed_configuration

    # Frontend Settings
    NEXT_PUBLIC_DISABLE_STREAMING                     = var.next_public_disable_streaming
    NEXT_PUBLIC_NEW_CHAT_DIRECTS_TO_SAME_PERSONA      = var.next_public_new_chat_directs_to_same_persona
    NEXT_PUBLIC_POSITIVE_PREDEFINED_FEEDBACK_OPTIONS  = jsonencode(var.next_public_positive_predefined_feedback_options)
    NEXT_PUBLIC_NEGATIVE_PREDEFINED_FEEDBACK_OPTIONS  = jsonencode(var.next_public_negative_predefined_feedback_options)
    NEXT_PUBLIC_DISABLE_LOGOUT                        = var.next_public_disable_logout
    NEXT_PUBLIC_DEFAULT_SIDEBAR_OPEN                  = var.next_public_default_sidebar_open
    NEXT_PUBLIC_THEME                                 = var.next_public_theme
    NEXT_PUBLIC_DO_NOT_USE_TOGGLE_OFF_DANSWER_POWERED = var.next_public_do_not_use_toggle_off_danswer_powered
    THEME_IS_DARK                                     = var.theme_is_dark

    # Database Settings
    POSTGRES_USER     = var.postgres_user
    POSTGRES_PASSWORD = var.postgres_password
    POSTGRES_DB       = var.postgres_db

    # Indexing Configurations
    NUM_INDEXING_WORKERS                          = var.num_indexing_workers
    ENABLED_CONNECTOR_TYPES                       = jsonencode(var.enabled_connector_types)
    DISABLE_INDEX_UPDATE_ON_SWAP                  = var.disable_index_update_on_swap
    DASK_JOB_CLIENT_ENABLED                       = var.dask_job_client_enabled
    CONTINUE_ON_CONNECTOR_FAILURE                 = var.continue_on_connector_failure
    EXPERIMENTAL_CHECKPOINTING_ENABLED            = var.experimental_checkpointing_enabled
    CONFLUENCE_CONNECTOR_LABELS_TO_SKIP           = jsonencode(var.confluence_connector_labels_to_skip)
    JIRA_CONNECTOR_LABELS_TO_SKIP                 = jsonencode(var.jira_connector_labels_to_skip)
    WEB_CONNECTOR_VALIDATE_URLS                   = var.web_connector_validate_urls
    JIRA_API_VERSION                              = var.jira_api_version
    GONG_CONNECTOR_START_TIME                     = var.gong_connector_start_time
    NOTION_CONNECTOR_ENABLE_RECURSIVE_PAGE_LOOKUP = var.notion_connector_enable_recursive_page_lookup
    GITHUB_CONNECTOR_BASE_URL                     = var.github_connector_base_url

    # SlackBot Configurations
    DANSWER_BOT_SLACK_APP_TOKEN          = var.danswer_bot_slack_app_token
    DANSWER_BOT_SLACK_BOT_TOKEN          = var.danswer_bot_slack_bot_token
    DANSWER_BOT_DISABLE_DOCS_ONLY_ANSWER = var.danswer_bot_disable_docs_only_answer
    DANSWER_BOT_FEEDBACK_VISIBILITY      = var.danswer_bot_feedback_visibility
    DANSWER_BOT_DISPLAY_ERROR_MSGS       = var.danswer_bot_display_error_msgs
    DANSWER_BOT_RESPOND_EVERY_CHANNEL    = var.danswer_bot_respond_every_channel
    DANSWER_BOT_DISABLE_COT              = var.danswer_bot_disable_cot
    NOTIFY_SLACKBOT_NO_ANSWER            = var.notify_slackbot_no_answer
    DANSWER_BOT_MAX_QPM                  = var.danswer_bot_max_qpm
    DANSWER_BOT_MAX_WAIT_TIME            = var.danswer_bot_max_wait_time

    # Model Server Settings
    MIN_THREADS_ML_MODELS = var.min_threads_ml_models
    DISABLE_MODEL_SERVER  = var.disable_model_server

    # Additional Variables
    IMAGE_TAG = var.image_tag
    DOMAIN    = var.domain
  }
}