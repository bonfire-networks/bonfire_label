defmodule Bonfire.Label.Acts.LabelObject do
  @moduledoc """
  Takes an object and label and returns a changeset for labeling that object. 
  Implements `Bonfire.Epics.Act`.

  Epic Options:
    * `:current_user` - user that will create the page, required.

  Act Options:
    * `:as` - key to where we find the label(s) to add, and then assign changeset to, default: `:label`.
    * `:object` (configurable) - id to use for the thing to label
    * `:attrs` - epic options key to find the attributes at, default: `:attrs`.
  """

  alias Bonfire.Ecto.Acts.Work
  # alias Bonfire.Epics.Act
  alias Bonfire.Epics.Epic
  alias Bonfire.Label

  alias Ecto.Changeset
  use Arrows
  import Bonfire.Epics
  # import Untangle

  # see module documentation
  @doc false
  def run(epic, act) do
    current_user = epic.assigns[:options][:current_user]

    cond do
      epic.errors != [] ->
        maybe_debug(
          epic,
          act,
          length(epic.errors),
          "Skipping due to epic errors"
        )

        epic

      not (is_struct(current_user) or is_binary(current_user)) ->
        maybe_debug(
          epic,
          act,
          current_user,
          "Skipping due to missing current_user"
        )

        epic

      true ->
        as = Keyword.get(act.options, :as) || Keyword.get(act.options, :on, :label)
        object_key = Keyword.get(act.options, :object, :object)
        # attrs_key = Keyword.get(act.options, :attrs, :page_attrs)

        label = Keyword.get(epic.assigns[:options], as, [])
        object = Keyword.get(epic.assigns[:options], object_key, nil)
        # attrs = Keyword.get(epic.assigns[:options], attrs_key, %{})
        # boundary = epic.assigns[:options][:boundary]

        # maybe_debug(
        #   epic,
        #   act,
        #   attrs_key,
        #   "Assigning changeset to :#{as} using attrs"
        # )

        # maybe_debug(epic, act, attrs, "Post attrs")
        # if attrs == %{}, do: maybe_debug(act, attrs, "empty attrs")

        Bonfire.Label.Labelling.label_object(label, object,
          return: :changeset,
          current_user: current_user
        )
        |> Map.put(:action, :insert)
        |> Epic.assign(epic, as, ...)
        |> Work.add(:label)
    end
  end
end
