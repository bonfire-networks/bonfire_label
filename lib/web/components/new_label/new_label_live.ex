defmodule Bonfire.Label.Web.NewLabelLive do
  use Bonfire.UI.Common.Web, :stateless_component

  def label_id, do: "1ABE1SC1ASS1FYC00RD1NAT10N"

  prop category, :any, default: nil
  # prop object, :any, default: nil
  prop context_id, :any, default: nil

  prop smart_input_opts, :map, default: %{}
  prop textarea_class, :css_class, required: false
  # unused but workaround surface "invalid value for property" issue
  prop textarea_container_class, :css_class
  prop to_boundaries, :any, default: nil
  prop open_boundaries, :boolean, default: false
  prop to_circles, :list, default: []
  prop exclude_circles, :list, default: []
  prop showing_within, :atom, default: nil
  prop uploads, :any, default: nil
  prop uploaded_files, :list, default: nil

  slot header

  @behaviour Bonfire.UI.Common.SmartInputModule
  def smart_input_module, do: [:label]
end
