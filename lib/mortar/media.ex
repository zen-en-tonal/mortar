defmodule Mortar.Media do
  alias Mortar.Event
  alias Mortar.Repo
  alias Mortar.Storage

  defstruct [
    :id,
    :md5,
    :type,
    :size,
    :ext,
    tags: [],
    source: nil,
    name: nil,
    metadata: %{}
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
          metadata: map()
        }

  @supported_types ~w(image/jpeg image/png image/gif image/webp audio/mpeg audio/ogg video/mp4 video/webm)

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
    case infer_type(binary) do
      :unknown ->
        {:error, :unsupported_media_type}

      {type, ext} ->
        attrs =
          attrs
          |> put_in([:type], type)
          |> put_in([:ext], ext)

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

    set = put_in(set, [:tag_strings], Enum.join(compose_metatags(set) ++ tags, " "))

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
          ext: record.ext
        }
        |> put_tags(tags)

      {:ok, media}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp compose_metatags(set) do
    [
      "md5:#{set.md5}",
      "type:#{set.file_type}",
      "ext:#{set.ext}"
    ]
  end

  defp put_tags(media, tags) do
    to_add =
      (tags -- media.tags)
      |> Enum.map(&Event.compose(:add_tag, media.id, %{"tag" => &1}))

    to_remove =
      (media.tags -- tags)
      |> Enum.map(&Event.compose(:remove_tag, media.id, %{"tag" => &1}))

    Event.publish(to_add ++ to_remove)

    %{media | tags: tags}
  end

  @doc """
  Infers the media type from the given binary.
  """
  def infer_type(binary) do
    case Infer.get(binary) do
      %Infer.Type{mime_type: mime} = type when mime in @supported_types ->
        {type.matcher_type, type.extension}

      _ ->
        :unknown
    end
  end
end
