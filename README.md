# Mortar

A media management and tagging system built with Elixir and Ecto, featuring advanced tag indexing and media storage.

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

## License

[Add your license here]

