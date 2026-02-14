defmodule Mortar.Repo.Migrations.TransformEvents do
  use Ecto.Migration

  def up do
    Mortar.Repo.transaction(fn ->
      changes =
        Mortar.Repo.all(Mortar.Event.Schema)
        |> Enum.map(fn
          %Mortar.Event.Schema{kind: kind} = ev when kind in ["add_tag", "remove_tag"] ->
            payload = %{"media_id" => ev.subject}
            {ev, [payload: payload, subject: ev.payload["tag"]]}

          otherwise ->
            {otherwise, []}
        end)

      for {ev, change} <- changes do
        Ecto.Changeset.change(ev, change)
        |> Mortar.Repo.update!()
      end
    end)
  end

  def down do
    Mortar.Repo.transaction(fn ->
      changes =
        Mortar.Repo.all(Mortar.Event.Schema)
        |> Enum.map(fn
          %Mortar.Event.Schema{kind: kind} = ev when kind in ["add_tag", "remove_tag"] ->
            payload = %{"tag" => ev.subject}
            {ev, [payload: payload, subject: ev.payload["media_id"]]}

          otherwise ->
            {otherwise, []}
        end)

      for {ev, changes} <- changes do
        Ecto.Changeset.change(ev, changes)
        |> Mortar.Repo.update!()
      end
    end)
  end
end
