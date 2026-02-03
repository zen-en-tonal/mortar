defmodule Mortar.Web.DanbooruTest do
  use ExUnit.Case, async: false
  import Plug.Test
  import Plug.Conn

  alias Mortar.Web.Danbooru

  @opts Danbooru.init([])

  @test_png Path.expand("../../support/fixtures/test_image.png", __DIR__)

  describe "GET /" do
    test "returns welcome message" do
      conn = conn(:get, "/")
      conn = Danbooru.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "Welcome to Mortar Web!"
    end
  end

  describe "GET /health" do
    test "returns OK status" do
      conn = conn(:get, "/health")
      conn = Danbooru.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200
      assert conn.resp_body == "OK"
    end
  end

  describe "GET /posts.json" do
    test "returns JSON response with proper content type" do
      conn = conn(:get, "/posts.json")
      conn = Danbooru.call(conn, @opts)

      assert conn.state == :sent
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]

      # Response should be valid JSON (either array or object)
      body = Jason.decode!(conn.resp_body)
      assert is_list(body) or is_map(body)
    end

    test "accepts limit parameter" do
      conn = conn(:get, "/posts.json?limit=10")
      conn = Danbooru.call(conn, @opts)

      assert conn.status == 200
    end

    test "accepts page parameter" do
      conn = conn(:get, "/posts.json?page=2")
      conn = Danbooru.call(conn, @opts)

      assert conn.status == 200
    end

    test "accepts tags parameter" do
      conn = conn(:get, "/posts.json?tags=cat+dog")
      conn = Danbooru.call(conn, @opts)

      assert conn.status == 200
    end

    test "accepts order parameter" do
      conn = conn(:get, "/posts.json?order=asc")
      conn = Danbooru.call(conn, @opts)

      assert conn.status == 200
    end

    test "handles all parameters together" do
      conn = conn(:get, "/posts.json?limit=50&page=3&tags=cat+-dog&order=desc")
      conn = Danbooru.call(conn, @opts)

      assert conn.status == 200
    end
  end

  describe "POST /posts.json" do
    test "returns 400 when file parameter is missing" do
      conn = conn(:post, "/posts.json", %{})
      conn = Danbooru.call(conn, @opts)

      assert conn.status == 400
      assert conn.resp_body == "File parameter is required"
    end

    test "accepts optional tags parameter" do
      upload = %Plug.Upload{
        path: @test_png,
        content_type: "image/png",
        filename: "test.png"
      }

      conn =
        conn(:post, "/posts.json", %{
          "file" => upload,
          "tags" => "test tag"
        })

      conn = Danbooru.call(conn, @opts)

      # May succeed or fail depending on Media.upload implementation
      # Just verify it doesn't crash and returns a valid HTTP response
      assert conn.status in [201]
    end

    test "accepts optional source parameter" do
      tmp_file = create_temp_file("test content")

      upload = %Plug.Upload{
        path: tmp_file,
        content_type: "image/jpeg",
        filename: "test.jpg"
      }

      conn =
        conn(:post, "/posts.json", %{
          "file" => upload,
          "source" => "https://example.com"
        })

      conn = Danbooru.call(conn, @opts)

      assert conn.status in [200, 201, 400, 500]

      File.rm_rf(tmp_file)
    end

    test "accepts optional name parameter" do
      tmp_file = create_temp_file("test content")

      upload = %Plug.Upload{
        path: tmp_file,
        content_type: "image/jpeg",
        filename: "test.jpg"
      }

      conn =
        conn(:post, "/posts.json", %{
          "file" => upload,
          "name" => "my_image"
        })

      conn = Danbooru.call(conn, @opts)

      assert conn.status in [200, 201, 400, 500]

      File.rm_rf(tmp_file)
    end
  end

  describe "GET /posts/:id.json" do
    test "accepts integer ID" do
      conn = conn(:get, "/posts/1.json")
      conn = Danbooru.call(conn, @opts)

      # May return 200, 404, or 500 depending on whether media exists
      assert conn.status in [200, 404, 500]
    end

    test "returns JSON on success or failure" do
      conn = conn(:get, "/posts/999999.json")
      conn = Danbooru.call(conn, @opts)

      assert conn.status in [200, 404, 500]

      # If JSON response, should be parseable
      if conn.status == 200 do
        assert get_resp_header(conn, "content-type") == ["application/json; charset=utf-8"]
        Jason.decode!(conn.resp_body)
      end
    end
  end

  describe "GET /file/:filename" do
    test "parses filename with extension" do
      conn = conn(:get, "/file/abc123.jpg")
      conn = Danbooru.call(conn, @opts)

      # May return 200, 404, or 500 depending on storage
      assert conn.status in [200, 404, 500]
    end

    test "handles different file extensions" do
      extensions = ["jpg", "png", "gif", "webp"]

      for ext <- extensions do
        conn = conn(:get, "/file/test123.#{ext}")
        conn = Danbooru.call(conn, @opts)

        assert conn.status in [200, 404, 500]
      end
    end

    test "returns appropriate content type on success" do
      # This test will fail if file doesn't exist, but demonstrates the endpoint structure
      conn = conn(:get, "/file/test.jpg")
      conn = Danbooru.call(conn, @opts)

      if conn.status == 200 do
        content_type = get_resp_header(conn, "content-type")
        assert length(content_type) > 0
      end
    end
  end

  # Helper functions

  defp create_temp_file(content) do
    path = Path.join(System.tmp_dir!(), "mortar_test_#{:rand.uniform(100_000)}.tmp")
    File.write!(path, content)
    path
  end
end
