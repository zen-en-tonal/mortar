# Mortar

A media management and tagging system built with Elixir and Ecto, featuring advanced tag indexing, media storage, and web scraping capabilities.

## Features

- **Media Management**: Store and manage media files with metadata extraction
- **Tag System**: Advanced tag indexing with full-text search capabilities using Roaring bitmaps
- **Storage Abstraction**: Pluggable storage backends (local filesystem support included)
- **FFprobe Integration**: Extract metadata from video/audio files
- **Event System**: Track and manage media-related events
- **Snapshot Support**: Create and manage media snapshots
- **Query Builder**: Flexible query API for media and tags

## Requirements

- Elixir ~> 1.19
- PostgreSQL
- FFmpeg/FFprobe (for media processing)

## Installation

### Local Development

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd mortar
   ```

2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Set up the database:
   ```bash
   mix ecto.create
   mix ecto.migrate
   ```

4. Start the application:
   ```bash
   mix run --no-halt
   ```

### Docker

1. Build and run with Docker Compose:
   ```bash
   docker-compose up
   ```

## Configuration

Configure the application in `config/`:

- `config.exs` - Base configuration
- `dev.exs` - Development environment
- `test.exs` - Test environment
- `runtime.exs` - Runtime configuration

### Storage Adapter

Configure the storage backend in `config/config.exs`:

```elixir
config :mortar, storage_adapter: Mortar.Storage.Local
```

### Database

Configure your database connection in the environment-specific config files:

```elixir
config :mortar, Mortar.Repo,
  username: "postgres",
  password: "postgres",
  database: "mortar_dev",
  hostname: "localhost"
```

## Development

### Running Tests

Tests automatically reset the database before running:

```bash
mix test
```

### Code Formatting

```bash
mix format
```

### Generate Documentation

```bash
mix docs
```

Documentation will be available in the `doc/` directory.

## Architecture

The project follows Elixir best practices with a clear separation of concerns:

- **Domain Logic**: Pure business logic in context modules
- **Persistence**: Ecto schemas, changesets, and repositories
- **Storage**: Abstracted storage layer with pluggable backends
- **Indexing**: Tag search using Trie and Roaring bitmap data structures

### Key Dependencies

- **Ecto** - Database wrapper and query language
- **Postgrex** - PostgreSQL driver
- **Roaring** - Compressed bitmap indexing
- **Trie** - Prefix tree for efficient tag searching
- **Bandit** - HTTP server
- **Rambo** - External command execution
- **Hume** - Utilities
- **Infer** - Type inference

## Project Structure

```
├── lib/
│   └── mortar/
│       ├── application.ex      # Application supervisor
│       ├── repo.ex            # Ecto repository
│       ├── media.ex           # Media context
│       ├── tag.ex             # Tag context
│       ├── storage.ex         # Storage abstraction
│       ├── web.ex             # Web integration
│       ├── event.ex           # Event tracking
│       ├── snapshot.ex        # Snapshot management
│       └── query.ex           # Query builder
├── priv/
│   └── repo/
│       └── migrations/        # Database migrations
├── test/                      # Test files
├── config/                    # Configuration files
└── mix.exs                    # Project configuration
```

## Contributing

1. Follow the guidelines in `AGENTS.md` for code conventions
2. Ensure tests pass with `mix test`
3. Format code with `mix format`
4. Keep changes focused and well-documented

## License

[Add your license here]

