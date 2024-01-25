defmodule Bonfire.Label do
  use Needle.Virtual,
    otp_app: :bonfire_label,
    table_id: "71ABE1SADDED0NT0S0METH1NGS",
    source: "bonfire_label_labelled"

  alias Bonfire.Data.Edges.Edge
  alias Bonfire.Label
  alias Needle.Changesets

  virtual_schema do
    has_one(:edge, Edge, foreign_key: :id)
  end

  def changeset(label \\ %Label{}, params),
    do: Changesets.cast(label, params, [])
end

defmodule Bonfire.Label.Migration do
  @moduledoc false
  import Ecto.Migration
  import Needle.Migration
  import Bonfire.Data.Edges.EdgeTotal.Migration
  alias Bonfire.Label

  def migrate_label_view(), do: migrate_virtual(Label)

  # def migrate_label_total_view(), do: migrate_edge_total_view(Label)

  def migrate_label(dir \\ direction())

  def migrate_label(:up) do
    migrate_label_view()
    # migrate_label_total_view()
  end

  def migrate_label(:down) do
    # migrate_label_total_view()
    migrate_label_view()
  end
end
