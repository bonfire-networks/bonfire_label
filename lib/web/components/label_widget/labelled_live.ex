defmodule Bonfire.Label.Web.LabelledLive do
  use Bonfire.UI.Common.Web, :stateless_component

  prop label, :any, default: nil
  prop label_id, :any, default: nil
  prop activity, :any, default: nil
  prop showing_within, :atom, default: nil
  prop viewing_main_object, :boolean, default: false
  prop class, :css_class, default: ["flex items-center -ml-6 justify-start pb-2 mb-2"]
end
