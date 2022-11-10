Rails.application.reloader.to_prepare do
  defaults = {
    log: Rails.env.development?,
    transport_options: {
      ssl: {verify: false}
    }
  }

  exact_field = {
    exact: {
      type: "text",
      analyzer: "lower_exact"
    }
  }

  shared_settings = {
    index: {
      number_of_shards: "6",
    },
    analysis: {
      analyzer: {
        lower_exact: {
          type: "custom",
          tokenizer: "whitespace",
          filter: ["lowercase"]
        },
        stemmed: {
          type: "custom",
          tokenizer: "standard",
          filter: ["lowercase", "asciifolding", "english_stemmer"]
        }
      },
      filter: {
        english_stemmer: {
          type: "stemmer",
          name: "english"
        }
      }
    }
  }

  entries_mapping = {
    settings: shared_settings,
    mappings: {
      _source: {
        enabled: Rails.env.development? ? true : false
      },
      properties: {
        author: {
          analyzer: "stemmed",
          fields: exact_field,
          type: "text"
        },
        content: {
          analyzer: "stemmed",
          fields: exact_field,
          type: "text"
        },
        feed_id: {
          type: "keyword"
        },
        id: {
          type: "keyword"
        },
        link: {
          type: "keyword"
        },
        published: {
          type: "date"
        },
        title: {
          analyzer: "stemmed",
          fields: exact_field,
          type: "text"
        },
        twitter_image: {
          type: "boolean"
        },
        twitter_link: {
          type: "boolean"
        },
        twitter_media: {
          type: "boolean"
        },
        twitter_name: {
          type: "text",
          analyzer: "stemmed",
          fields: exact_field
        },
        twitter_retweet: {
          type: "boolean"
        },
        twitter_screen_name: {
          type: "text",
          analyzer: "stemmed",
          fields: exact_field
        },
        updated: {
          type: "date"
        },
        url: {
          type: "text",
          analyzer: "lower_exact"
        },
        type: {
          type: "text",
          analyzer: "keyword"
        },
        media_duration: {
          type: "long"
        },
        word_count: {
          type: "long"
        }
      }
    }
  }

  actions_mapping = {
    settings: shared_settings,
    mappings: {
      properties: entries_mapping[:mappings][:properties].merge({
        query: {
          type: "percolator"
        }
      })
    }
  }

  $search = {}.tap do |hash|
    hash[:servers] = {
      primary: ConnectionPool.new(size: ENV.fetch("DB_POOL", 1)) {
        Search::Client.new(ENV.fetch("ELASTICSEARCH_URL", "http://localhost:9200"),
          username: ENV["ELASTICSEARCH_USERNAME"],
          password: ENV["ELASTICSEARCH_PASSWORD"]
        )
      }
    }

    if ENV["ELASTICSEARCH_ALT_URL"]
      hash[:servers][:secondary] = ConnectionPool.new(size: ENV.fetch("DB_POOL", 1)) {
        Search::Client.new(ENV.fetch("ELASTICSEARCH_ALT_URL", "http://localhost:9200"),
          username: ENV["ELASTICSEARCH_ALT_USERNAME"],
          password: ENV["ELASTICSEARCH_ALT_PASSWORD"]
        )
      }
    end
    hash[:main] = hash[:servers][:primary]

    hash[:config] = {
      mappings: {
        entries: entries_mapping,
        actions: actions_mapping
      }
    }
  end

  unless Rails.env.production?
    $search[:main].with { _1.request(:put, Entry.table_name, json: entries_mapping) }
    $search[:main].with { _1.request(:put, Action.table_name, json: actions_mapping) }
  end
end

unless Rails.env.production?
  ActiveSupport::Notifications.subscribe("request.search") do |name, start, finish, id, payload|
    Rails.logger.info(search: "request", path: payload.dig(:response).request.uri.path, payload: payload.dig(:response)&.request&.body&.source)
    Rails.logger.info(search: "response", path: payload.dig(:response).request.uri.path, payload: payload.dig(:response)&.parse)
  end
end
