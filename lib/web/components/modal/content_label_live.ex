defmodule Bonfire.Label.Web.ContentLabelLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.OpenModalLive

  prop object, :any, required: true
  prop object_boundary, :any, default: nil
  prop btn_label, :string, default: nil
  prop target, :any, default: nil

  def label_id, do: "1ABE1SF0RC0NTENTM0DERAT10N"

  def can_label?(context, object, object_boundary \\ nil) do
    # && Types.object_type(object) == Bonfire.Data.Social.Post
    Bonfire.Boundaries.can?(context, :moderate, :instance)
  end

  def labels do
    with {:ok, parent_label} <-
           Bonfire.Label.Labels.get_or_create(label_id(), "Content Moderation Labels"),
         %{edges: []} <- labels_under(parent_label) do
      # if no labels exists, create some defaults
      Bonfire.Label.Labels.get_or_create(
        "1ABE10VTDATEDGET1ATESTNEWS",
        "Get the latest",
        parent_label,
        "outdated"
      )

      Bonfire.Label.Labels.get_or_create(
        "1ABE1M1S1NF0RMEDGETZEFACTS",
        "Stay informed",
        parent_label,
        "misinformed"
      )

      Bonfire.Label.Labels.get_or_create(
        "1ABE1M1S1EAD1NGBACK2S0VRCE",
        "Misleading",
        parent_label,
        "misleading"
      )

      labels_under(parent_label)
    end
  end

  def labels_under(parent_label \\ label_id()),
    do:
      Bonfire.Classify.Categories.list([parent_category: parent_label], skip_boundary_check: true)
end
