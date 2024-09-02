defmodule Bonfire.Label.Web.ContentLabelLive do
  use Bonfire.UI.Common.Web, :stateless_component
  alias Bonfire.UI.Common.OpenModalLive
  alias Bonfire.Label.ContentLabels

  prop object, :any, required: true
  prop object_boundary, :any, default: nil
  prop btn_label, :string, default: nil
  prop target, :any, default: nil
end
