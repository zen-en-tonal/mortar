defmodule Mortar.Web.Danbooru do
  use Plug.Router

  alias Mortar.Storage
  alias Mortar.Media

  plug(Plug.Parsers,
    parsers: [:json, :urlencoded, :multipart],
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
    order = parse_order(conn.params["order"])

    case Media.query(query, limit: limit, offset: offset, order: order) do
      {:ok, medias} ->
        body =
          medias
          |> Enum.map(&parse_media/1)
          |> Jason.encode!()

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, body)

      {:error, reason} ->
        conn
        |> send_resp(500, "Error fetching medias: #{reason}")
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
      case Media.upload(File.read!(file.path), attrs) do
        {:ok, media} ->
          body =
            media
            |> parse_media()
            |> Jason.encode!()

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(201, body)

        {:error, reason} ->
          conn
          |> send_resp(500, "Error creating media: #{inspect(reason)}")
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

      {:error, reason} ->
        conn
        |> send_resp(500, "Error fetching media: #{reason}")
    end
  end

  get "/file/:filename" do
    [md5, ext] = conn.params["filename"] |> String.split(".")

    case Storage.get(md5) do
      {:ok, bin} ->
        conn
        |> put_resp_content_type(MIME.type(ext))
        |> send_resp(200, bin)

      {:error, :not_found} ->
        conn
        |> send_resp(404, "File not found")

      {:error, reason} ->
        conn
        |> send_resp(500, "Error fetching file: #{reason}")
    end
  end

  defp tags_to_query(""), do: "__all__"
  defp tags_to_query(nil), do: "__all__"

  defp tags_to_query(tags) when is_binary(tags) do
    String.split(tags, " ", trim: true)
    |> Enum.reduce("__all__", fn
      "-" <> tag, acc ->
        {:and, acc, {:not, tag}}

      tag, acc ->
        {:and, acc, tag}
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
      large_file_url: make_url(media),
      preview_file_url: make_url(media),
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
end
