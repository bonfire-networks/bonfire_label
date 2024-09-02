defmodule Bonfire.Label.ContentLabels do
  use Bonfire.Common.Utils

  def parent_label_id, do: "1ABE1SF0RC0NTENTM0DERAT10N"

  def can_label?(context, object, object_boundary \\ nil) do
    # && Types.object_type(object) == Bonfire.Data.Social.Post
    Bonfire.Boundaries.can?(context, :moderate, :instance)
  end

  def built_ins do
    [
      {
        "1ABE10VTDATEDGET1ATESTNEWS",
        "Get the latest",
        "outdated"
      },
      {"1ABE1M1S1NF0RMEDGETZEFACTS", "Stay informed", "misinformed"},
      {
        "1ABE1M1S1EAD1NGBACK2S0VRCE",
        "Misleading",
        "misleading"
      }
    ]
  end

  def built_in_ids do
    [parent_label_id()] ++ Enum.map(built_ins(), &elem(&1, 0))
  end

  def labels do
    with {:ok, parent_label} <-
           Bonfire.Label.Labels.get_or_create(parent_label_id(), "Content Moderation Labels"),
         %{edges: []} <- labels_under(parent_label) do
      # if no labels exists, create some defaults
      Enum.map(built_ins(), fn {id, label, slug} ->
        Bonfire.Label.Labels.get_or_create(
          id,
          "Get the latest",
          label,
          slug
        )
      end)

      labels_under(parent_label)
    end
  end

  def labels_under(parent_label \\ parent_label_id()),
    do:
      Bonfire.Classify.Categories.list([parent_category: parent_label], skip_boundary_check: true)
end
