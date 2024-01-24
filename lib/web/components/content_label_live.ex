defmodule Bonfire.Label.Web.ContentLabelLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.OpenModalLive

  prop object_boundary, :any, default: nil
  prop object, :any

  def can_label?(context, object, object_boundary \\ nil) do
    Bonfire.Boundaries.can?(context, :label, :instance) &&
      Types.object_type(object) == Bonfire.Data.Social.Post
  end
end
