defmodule Mortar.Web.Danbooru do
  use Plug.Router

  alias Mortar.Tag
  alias Mortar.Storage
  alias Mortar.Media
  alias Mortar.Error

  plug(Plug.Parsers,
    parsers: [
      :json,
      :urlencoded,
      # 1 GB max upload size
      {:multipart, length: 1_000_000_000}
    ],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> send_resp(200, "Welcome to Mortar Web!")
  end

  get "/health" do
    conn
    |> send_resp(200, "OK")
  end

  get "/posts.json" do
    limit = parse_limit(conn.params["limit"])
    page = parse_page(conn.params["page"])
    offset = (page - 1) * limit
    query = tags_to_query(conn.params["tags"])

    case Media.query(query[:q], limit: limit, offset: offset, order: query[:order]) do
      {:ok, medias} ->
        body =
          medias
          |> Enum.map(&parse_media/1)
          |> Jason.encode!()

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, body)

      {:error, %Error{type: :invalid} = err} ->
        conn
        |> send_resp(400, "Invalid query: #{err.message}")
    end
  end

  post "/posts.json" do
    file = conn.params["file"]
    tags = (conn.params["tags"] || "") |> String.split(" ")
    source = conn.params["source"] || ""
    name = conn.params["name"] || ""

    attrs = [
      file: file,
      tags: tags,
      source: source,
      name: name
    ]

    if is_nil(file) do
      conn
      |> send_resp(400, "File parameter is required")
    else
      case Media.upload(File.stream!(file.path, 1024), attrs) do
        {:ok, media} ->
          body =
            media
            |> parse_media()
            |> Jason.encode!()

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(201, body)

        {:error, %Error{type: :invalid} = err} ->
          conn
          |> send_resp(400, "Invalid request: #{err.message}")
      end
    end
  end

  get "/posts/:id.json" do
    id = String.to_integer(conn.params["id"])

    case Media.get(id) do
      {:ok, media} ->
        body =
          media
          |> parse_media()
          |> Jason.encode!()

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, body)

      {:error, :not_found} ->
        conn
        |> send_resp(404, "Media not found")
    end
  end

  put "/posts/:id.json" do
    id = String.to_integer(conn.params["id"])

    case Media.get(id) do
      {:ok, media = %Media{}} ->
        new_tags =
          case conn.params["tags"] do
            nil -> media.tags
            tags when is_binary(tags) -> String.split(tags, " ", trim: true)
          end

        new_source =
          case conn.params["source"] do
            nil -> media.source
            source when is_binary(source) -> source
          end

        new_name =
          case conn.params["name"] do
            nil -> media.name
            name when is_binary(name) -> name
          end

        case Media.update(media, tags: new_tags, name: new_name, source: new_source) do
          {:ok, updated_media} ->
            body =
              updated_media
              |> parse_media()
              |> Jason.encode!()

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, body)

          {:error, %Error{type: :invalid} = err} ->
            conn
            |> send_resp(400, "Invalid request: #{err.message}")
        end

      {:error, :not_found} ->
        conn
        |> send_resp(404, "Media not found")
    end
  end

  get "/file/:filename" do
    [md5, ext] = conn.params["filename"] |> String.split(".")

    case Storage.get(md5) do
      {:ok, stream} ->
        conn =
          conn
          |> put_resp_content_type(MIME.type(ext))
          |> send_chunked(200)

        Enum.reduce_while(stream, conn, fn chunk, conn ->
          case Plug.Conn.chunk(conn, chunk) do
            {:ok, conn} ->
              {:cont, conn}

            {:error, :closed} ->
              {:halt, conn}
          end
        end)

      {:error, :not_found} ->
        conn
        |> send_resp(404, "File not found")
    end
  end

  get "/tags.json" do
    limit = parse_limit(conn.params["limit"])

    matches =
      (conn.params["search%5Bname_matches%5D"] || "")
      |> String.trim("*")

    body =
      Tag.suggest(matches)
      |> Enum.sort_by(fn {_name, count} -> -count end)
      |> Enum.reject(fn {name, _count} ->
        # Exclude meta-tags starting or ending with underscore
        String.starts_with?(name, "_") or String.ends_with?(name, "_")
      end)
      |> Enum.take(limit)
      |> Enum.map(fn {name, count} ->
        %{
          id: 0,
          name: name,
          post_count: count,
          category: 1,
          is_deprecated: false,
          words: []
        }
      end)
      |> Jason.encode!()

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, body)
  end

  def tags_to_query(nil), do: [q: "__all__", order: :desc]
  def tags_to_query([]), do: [q: "__all__", order: :desc]

  def tags_to_query(tags) when is_binary(tags) do
    String.split(tags, " ", trim: true)
    |> Enum.reduce([q: "__all__", order: :desc], fn
      "order:" <> order, acc ->
        put_in(acc, [:order], parse_order(order))

      "-" <> tag, acc ->
        put_in(acc, [:q], {:and, {:not, tag}, acc[:q]})

      tag, acc ->
        put_in(acc, [:q], {:and, tag, acc[:q]})
    end)
  end

  defp parse_page(""), do: 1
  defp parse_page(nil), do: 1
  defp parse_page(pg) when is_binary(pg), do: String.to_integer(pg) |> max(1)

  defp parse_limit(""), do: 20
  defp parse_limit(nil), do: 20
  defp parse_limit(lim) when is_binary(lim), do: String.to_integer(lim) |> min(100) |> max(1)

  defp parse_order("asc"), do: :asc
  defp parse_order("desc"), do: :desc
  defp parse_order("random"), do: :random
  defp parse_order(_), do: :desc

  defp parse_media(%Media{} = media) do
    %{
      id: media.id,
      tag_string: media.tags |> Enum.join(" "),
      file_url: make_url(media),
      created_at: media.created_at,
      updated_at: media.updated_at,
      uploader_id: nil,
      approver_id: nil,
      tag_string_general: media.tags |> Enum.join(" "),
      tag_string_artist: "",
      tag_string_character: "",
      tag_string_copyright: "",
      rating: "s",
      parent_id: nil,
      pixiv_id: nil,
      source: media.source,
      md5: media.md5,
      large_file_url: with_image_proxy(media, "sample"),
      preview_file_url: with_image_proxy(media, "360x360"),
      file_ext: media.ext,
      file_size: media.size,
      width: media.metadata["width"] || 0,
      height: media.metadata["height"] || 0,
      score: 0,
      up_score: 0,
      down_score: 0,
      fav_count: 0,
      tag_count_general: media.tags |> length(),
      tag_count_artist: 0,
      tag_count_character: 0,
      tag_count_copyright: 0,
      last_comment_bumped_at: nil,
      last_noted_at: nil,
      has_large: true,
      has_children: false,
      has_visible_children: false,
      has_active_children: false,
      is_banned: false,
      is_deleted: false,
      is_flagged: false,
      is_pending: false,
      bit_flags: 0,
      media_asset: %{
        id: media.id,
        created_at: media.created_at,
        updated_at: media.updated_at,
        md5: media.md5,
        file_ext: media.ext,
        file_size: media.size,
        image_width: media.metadata["width"] || 0,
        image_height: media.metadata["height"] || 0,
        duration: media.metadata["duration"] || 0,
        status: "active",
        file_key: "bbD6k0WiU",
        is_public: true,
        pixel_hash: media.md5,
        variants: [
          %{
            variant_type: "180x180",
            url: with_image_proxy(media, "180x180"),
            width: 180,
            height: 180,
            file_ext: media.ext
          },
          %{
            variant_type: "360x360",
            url: with_image_proxy(media, "360x360"),
            width: 360,
            height: 360,
            file_ext: media.ext
          },
          %{
            variant_type: "720x720",
            url: with_image_proxy(media, "720x720"),
            width: 720,
            height: 720,
            file_ext: media.ext
          },
          %{
            variant_type: "sample",
            url: with_image_proxy(media, "sample"),
            width: 850,
            height: 850,
            file_ext: media.ext
          },
          %{
            variant_type: "original",
            url: make_url(media),
            width: media.metadata["width"] || 0,
            height: media.metadata["height"] || 0,
            file_ext: media.ext
          }
        ]
      }
    }
  end

  defp make_url(%Media{} = media) do
    "#{Mortar.Web.host() |> URI.to_string()}/file/#{media.md5}.#{media.ext}"
  end

  defp with_image_proxy(%Media{} = media, variant) do
    image_proxy =
      (Application.get_env(:mortar, __MODULE__)[:image_proxy_url] || Mortar.Web.host())
      |> URI.to_string()

    "#{image_proxy}/#{variant}/#{media.md5}.#{media.ext}"
  end
end
