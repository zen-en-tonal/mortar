defmodule Mortar.Media do
  alias Mortar.Event
  alias Mortar.Repo
  alias Mortar.Storage
  alias Mortar.Query
  alias Mortar.Tag
  alias Mortar.FFProbe
  alias Mortar.Error

  import Ecto.Query

  defstruct [
    :id,
    :md5,
    :type,
    :size,
    :ext,
    tags: [],
    source: nil,
    name: nil,
    metadata: %{},
    created_at: nil,
    updated_at: nil
  ]

  @type t :: %__MODULE__{
          id: integer(),
          md5: String.t(),
          type: atom(),
          size: integer(),
          tags: [String.t()],
          ext: binary(),
          source: String.t() | nil,
          name: String.t() | nil,
          metadata: map(),
          created_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  defmodule Schema do
    use Ecto.Schema

    schema "medias" do
      field :md5, :string
      field :file_type, :string
      field :file_size, :integer
      field :source, :string
      field :file_name, :string
      field :tag_strings, :string
      field :ext, :string
      field :metadata, :map, default: %{}

      timestamps()
    end

    def changeset(schema, attrs) do
      schema
      |> Ecto.Changeset.cast(attrs, [
        :md5,
        :file_type,
        :file_size,
        :source,
        :file_name,
        :tag_strings,
        :ext,
        :metadata
      ])
      |> Ecto.Changeset.validate_required([:md5, :file_type, :file_size, :ext])
      |> Ecto.Changeset.unique_constraint(:md5)
    end
  end

  @doc """
  Uploads a binary as media with the given attributes.
  """
  def upload(binary, attrs \\ []) do
    case identify(binary) do
      {:error, reason} ->
        {:error, reason}

      {:ok, info} ->
        attrs =
          attrs
          |> put_in([:type], info[:type])
          |> put_in([:ext], info[:ext])
          |> put_in([:metadata], info[:metadata])

        do_upload(binary, attrs)
    end
  end

  defp do_upload(binary, attrs) do
    set = %{
      md5: :crypto.hash(:md5, binary) |> Base.encode16(case: :lower),
      file_type: to_string(attrs[:type]),
      file_size: byte_size(binary),
      source: attrs[:source],
      file_name: attrs[:name],
      metadata: attrs[:metadata] || %{},
      ext: attrs[:ext]
    }

    tags =
      ((attrs[:tags] || []) ++ compose_metatags(set))
      |> Enum.map(&String.trim/1)
      |> Enum.uniq()
      |> Enum.filter(&(&1 != ""))

    set = put_in(set, [:tag_strings], Enum.join(tags, " "))

    with :ok <- Storage.put(set.md5, binary),
         {:ok, record} <- Schema.changeset(%Schema{}, set) |> Repo.insert() do
      media =
        %__MODULE__{
          id: record.id,
          md5: record.md5,
          type: record.file_type,
          size: record.file_size,
          source: record.source,
          name: record.file_name,
          ext: record.ext,
          metadata: record.metadata,
          created_at: record.inserted_at,
          updated_at: record.updated_at
        }
        |> put_tags(tags)

      Event.compose(:upload_media, media.id, %{})
      |> Event.publish()

      {:ok, media}
    else
      {:error, %Ecto.Changeset{} = set} ->
        {:error, Error.invalid("Failed to upload media", details: set.errors)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Updates the media with the given attributes.
  """
  def update(%__MODULE__{} = media, attrs) do
    tags =
      case attrs[:tags] do
        nil -> media.tags
        ts -> ts |> Enum.map(&String.trim/1) |> Enum.uniq() |> Enum.filter(&(&1 != ""))
      end

    media
    |> put_tags(tags)

    res =
      Repo.get(Schema, media.id)
      |> Schema.changeset(%{
        source: attrs[:source] || media.source,
        file_name: attrs[:name] || media.name,
        tag_strings: Enum.join(tags, " ")
      })
      |> Repo.update()

    case res do
      {:ok, record} ->
        {:ok,
         %__MODULE__{
           id: record.id,
           md5: record.md5,
           type: record.file_type,
           size: record.file_size,
           ext: record.ext,
           source: record.source,
           name: record.file_name,
           metadata: record.metadata,
           tags: String.split(record.tag_strings, " ", trim: true),
           created_at: record.inserted_at,
           updated_at: record.updated_at
         }}

      {:error, %Ecto.Changeset{} = set} ->
        {:error, Error.invalid("Failed to update media", details: set.errors)}
    end
  end

  defp compose_metatags(set) do
    [
      "type:#{set.file_type}",
      "ext:#{set.ext}"
    ]
  end

  defp put_tags(media, tags) do
    tags =
      tags
      |> Enum.map(&String.trim/1)
      |> Enum.uniq()
      |> Enum.filter(&(&1 != ""))

    to_add =
      (tags -- media.tags)
      |> Enum.map(&Event.compose(:add_tag, media.id, %{"tag" => &1}))

    to_remove =
      (media.tags -- tags)
      |> Enum.map(&Event.compose(:remove_tag, media.id, %{"tag" => &1}))

    Event.publish(to_add ++ to_remove)

    Tag.queue_warm(tags)

    %{media | tags: tags}
  end

  @doc """
  Infers the media type from the given binary.
  """
  @spec infer_type(binary()) :: {:image | :audio | :video, binary()} | :unknown
  def infer_type(binary) do
    case Infer.get(binary) do
      %Infer.Type{} = type ->
        {type.matcher_type, type.extension}

      _ ->
        :unknown
    end
  end

  @spec identify(binary()) :: {:ok, info :: keyword()} | {:error, term()}
  def identify(bin) do
    case infer_type(bin) do
      {type, ext} when type in [:image, :audio, :video] ->
        case FFProbe.extract(bin) do
          {:ok, data} ->
            data = put_in(data, ["size"], byte_size(bin))

            info = [
              type: type,
              ext: ext,
              size: byte_size(bin),
              metadata: extract_metadata(type, data)
            ]

            {:ok, info}

          {:error, _reason} ->
            info = [
              type: type,
              ext: ext,
              size: byte_size(bin),
              metadata: %{}
            ]

            {:ok, info}
        end

      _ ->
        {:error, Error.invalid("Unsupported media type")}
    end
  end

  defp extract_metadata(:image, data) do
    streams = data["streams"] || []
    width = get_in(streams, [Access.at(0), "width"]) |> parse_number()
    height = get_in(streams, [Access.at(0), "height"]) |> parse_number()

    %{
      "width" => width,
      "height" => height
    }
    |> Map.merge(data)
  end

  defp extract_metadata(:audio, data) do
    streams = data["streams"] || []
    format = data["format"] || %{}

    bitrate = parse_number(get_in(format, ["bit_rate"]))
    bit_depth = parse_number(get_in(streams, [Access.at(0), "bits_per_sample"]))
    channels = parse_number(get_in(streams, [Access.at(0), "channels"]))
    sample_rate = parse_number(get_in(streams, [Access.at(0), "sample_rate"]))

    duration = data["size"] * 8 / (bitrate |> max(1))

    %{
      "bitrate" => bitrate,
      "bit_depth" => bit_depth,
      "channels" => channels,
      "sample_rate" => sample_rate,
      "duration" => duration
    }
    |> Map.merge(data)
  end

  defp extract_metadata(:video, data) do
    streams = data["streams"] || []
    format = data["format"] || %{}
    width = get_in(streams, [Access.at(0), "width"]) || 0
    height = get_in(streams, [Access.at(0), "height"]) || 0
    bitrate = parse_number(get_in(format, ["bit_rate"])) || 0
    framerate_str = get_in(streams, [Access.at(0), "r_frame_rate"]) || "0/1"
    [num_str, denom_str] = String.split(framerate_str, "/")
    framerate = (parse_number(num_str) || 0) / (parse_number(denom_str) || 1)
    duration = parse_number(format["duration"]) || data["size"] * 8 / (bitrate |> max(1))

    %{
      "width" => width,
      "height" => height,
      "bitrate" => bitrate,
      "framerate" => framerate,
      "duration" => duration
    }
    |> Map.merge(data)
  end

  @doc """
  Fetches the media with the given ID.
  """
  def get(id) when is_integer(id) do
    case Repo.get(Schema, id) do
      nil ->
        {:error, :not_found}

      %Schema{} = rec ->
        {:ok,
         %__MODULE__{
           id: rec.id,
           md5: rec.md5,
           type: rec.file_type,
           size: rec.file_size,
           ext: rec.ext,
           source: rec.source,
           name: rec.file_name,
           metadata: rec.metadata,
           tags: String.split(rec.tag_strings, " ", trim: true),
           created_at: rec.inserted_at,
           updated_at: rec.updated_at
         }}
    end
  end

  @doc """
  Queries media matching the given query.

  Options:
    * `:offset` - The offset to start from (default: `0`).
    * `:limit` - The maximum number of results to return (default: `25`).
    * `:order` - The order of results, either `:asc` or `:desc` (default: `:desc`).
  """
  @spec query(Query.t(), keyword()) :: {:ok, [t()]} | {:error, term()}
  def query(q, opts \\ [])

  def query("", opts) do
    query("__all__", opts)
  end

  def query(query, opts) do
    offset = opts[:offset] || 0
    limit = opts[:limit] || 25
    order = opts[:order] || :desc

    tags =
      Query.require_tags(query)
      |> Enum.map(&Tag.fetch/1)

    case Query.eval(query, tags) do
      {:ok, ids} ->
        ids =
          case order do
            :asc -> ids |> Enum.sort(&<=/2)
            :desc -> ids |> Enum.sort(&>=/2)
            :random -> ids |> Enum.shuffle()
          end
          |> Enum.slice(offset, limit)

        medias =
          Repo.all(from m in Schema, where: m.id in ^ids)
          |> Enum.map(fn
            %Schema{} = rec ->
              %__MODULE__{
                id: rec.id,
                md5: rec.md5,
                type: rec.file_type,
                size: rec.file_size,
                ext: rec.ext,
                source: rec.source,
                name: rec.file_name,
                metadata: rec.metadata,
                tags: String.split(rec.tag_strings, " ", trim: true),
                created_at: rec.inserted_at,
                updated_at: rec.updated_at
              }
          end)

        medias =
          case order do
            :asc -> medias |> Enum.sort_by(& &1.id, &<=/2)
            :desc -> medias |> Enum.sort_by(& &1.id, &>=/2)
            :random -> medias
          end

        {:ok, medias}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_number(x, default \\ 0)
  defp parse_number("", default), do: default
  defp parse_number(nil, default), do: default
  defp parse_number(num, _default) when is_number(num), do: num

  defp parse_number(str, default) when is_binary(str) do
    case Float.parse(str) do
      {num, _} -> num
      :error -> default
    end
  end
end
