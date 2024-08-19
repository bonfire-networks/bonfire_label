defmodule Bonfire.Label.Labelling do
  # alias Bonfire.Data.Identity.User
  alias Bonfire.Label
  # alias Bonfire.Boundaries.Verbs

  alias Bonfire.Epics.Epic

  alias Bonfire.Social.Activities
  alias Bonfire.Social.Edges
  alias Bonfire.Social.Feeds
  # alias Bonfire.Social.FeedActivities
  alias Bonfire.Social

  alias Bonfire.Social.Objects

  # alias Bonfire.Data.Edges.Edge

  use Bonfire.Common.Repo,
    searchable_fields: [:labeler_id, :labelled_id]

  # import Bonfire.Social
  use Bonfire.Common.Utils

  @behaviour Bonfire.Common.QueryModule
  @behaviour Bonfire.Common.ContextModule
  def schema_module, do: Label
  def query_module, do: __MODULE__

  def run_epic(type, options, module \\ __MODULE__, on \\ :page) do
    Bonfire.Epics.run_epic(module, type, Keyword.put(options, :on, on))
  end

  def labelled?(%{} = user, object),
    do: Edges.exists?(__MODULE__, user, object, skip_boundary_check: true)

  def count(filters \\ [], opts \\ [])

  def count(filters, opts) when is_list(filters) and is_list(opts) do
    Edges.count(__MODULE__, filters, opts)
  end

  def count(%{} = user, object) when is_struct(object) or is_binary(object),
    do: Edges.count_for_subject(__MODULE__, user, object, skip_boundary_check: true)

  def count(object, _) when is_struct(object),
    do: Edges.count(:label, object, skip_boundary_check: true)

  def date_last_labelled(%{} = user, object),
    do: Edges.last_date(__MODULE__, user, object, skip_boundary_check: true)

  def get(subject, object, opts \\ []),
    do: Edges.get(__MODULE__, subject, object, opts)

  def get!(subject, object, opts \\ []),
    do: Edges.get!(__MODULE__, subject, object, opts)

  def label_object(label, object, opts \\ [])

  def label_object(%{} = label, %{} = object, opts) do
    # if Bonfire.Boundaries.can?(label, :label, object, opts) do
    do_label(label, object, opts)
    # else
    #   error(l("Sorry, you cannot label this"))
    # end
  end

  def label_object(label, object, opts) when is_binary(object) do
    with {:ok, object} <-
           Bonfire.Common.Needles.get(
             object,
             opts ++
               [
                 current_user: label,
                 #  verbs: [:label]
                 verbs: [:read]
               ]
           ) do
      label_object(label, object, opts ++ [skip_boundary_check: true])
    else
      _ ->
        error(l("Sorry, you cannot label this"))
    end
  end

  def label_object(label, object, opts) when is_binary(label) do
    with {:ok, label} <-
           Bonfire.Label.Labels.get(
             label,
             opts ++
               [
                 skip_boundary_check: true
               ]
           ) do
      label_object(label, object, opts)
    else
      _ ->
        error(l("Sorry, could not find the desired label"))
    end
  end

  def label_object(labels, object, opts) when is_list(labels) do
    labels
    |> Enum.each(&label_object(&1, object, opts))
  end

  defp do_label(%{} = label, %{} = object, opts \\ []) do
    object = Objects.preload_creator(object)
    object_creator = Objects.object_creator(object)

    opts =
      opts ++
        [
          # TODO: get the preset for labeling from config and/or user's settings
          boundary: "public",
          to_circles: [id(object_creator)],
          to_feeds:
            [outbox: label] ++
              if(e(opts, :notify_creator, true),
                do: Feeds.maybe_creator_notification(label, object_creator, opts),
                else: []
              )
        ]

    # TODO: try to insert Tagged using changeset/transaction instead
    with {:ok, object} <- Bonfire.Tag.tag_something(current_user(opts), object, label) do
      if opts[:return] == :changeset do
        changeset(label, object, opts)
      else
        with {:ok, labelled} <- create(label, object, opts) do
          # LivePush will need a list of feed IDs we published to
          # feed_ids = for fp <- label.feed_publishes, do: fp.feed_id
          # maybe_apply(Bonfire.UI.Social.LivePush, :push_activity_object, [feed_ids, label, labelled,
          #   [push_to_thread: false,
          #   notify: true]
          # ])

          Social.maybe_federate_and_gift_wrap_activity(label, labelled)
          |> debug("maybe_federated the label (as a boost for now)")
        end
      end
    end
  end

  def unlabel(labeler, labelled, opts \\ [])

  def unlabel(labeler, %{} = labelled, _opts) do
    # delete the Label
    Edges.delete_by_both(labeler, Label, labelled)
    # delete the label activity & feed entries
    {:ok, Activities.delete_by_subject_verb_object(labeler, :label, labelled)}
  end

  def unlabel(labeler, labelled, opts) when is_binary(labelled) do
    with {:ok, labelled} <-
           Bonfire.Common.Needles.get(labelled, opts ++ [current_user: labeler]) do
      # debug(liked)
      unlabel(labeler, labelled)
    end
  end

  @doc "List current user's labels"
  def list_my(opts) do
    list_by(current_user_required!(opts), opts)
  end

  @doc "List labels by the user "
  def list_by(by_user, opts \\ [])
      when is_binary(by_user) or is_list(by_user) or is_map(by_user) do
    # query FeedPublish
    # [preload: [object: [created: [:creator]]]])
    list_paginated(
      [subject: by_user],
      to_options(opts) ++ [preload: :object_with_creator, subject_user: by_user]
    )
  end

  @doc "List label of an object"
  def list_of(id, opts \\ []) when is_binary(id) or is_list(id) or is_map(id) do
    opts = to_options(opts)
    # query FeedPublish
    list_paginated([object: id], opts ++ [preload: :subject])
  end

  def list_paginated(filters, opts \\ []) do
    filters
    |> query(opts)
    # |> debug()
    |> repo().many_paginated(opts)

    # TODO: activity preloads
  end

  defp query_base(filters, opts) do
    Edges.query_parent(Label, filters, opts)

    # |> proload(edge: [
    #   # subject: {"labeler_", [:profile, :character]},
    #   # object: {"labelled_", [:profile, :character, :post_content]}
    #   ])
    # |> query_filter(filters)
  end

  def query([my: :labels], opts),
    do: query([subject: current_user_required!(opts)], opts)

  def query(filters, opts) do
    query_base(filters, opts)
  end

  defp changeset(labeler, labelled, opts) do
    Edges.changeset_without_caretaker(Label, labeler, :label, labelled, opts)
  end

  defp create(labeler, labelled, opts) do
    Edges.insert(Label, labeler, :label, labelled, opts)
  end

  def ap_publish_activity(subject, :delete, label) do
    with {:ok, labeler} <-
           ActivityPub.Actor.get_cached(
             pointer: subject || e(label.edge, :subject, nil) || e(label.edge, :subject_id, nil)
           ),
         {:ok, object} <-
           ActivityPub.Object.get_cached(
             pointer: e(label.edge, :object, nil) || e(label.edge, :object_id, nil)
           ) do
      ActivityPub.unannounce(%{actor: labeler, object: object})
    end
  end

  def ap_publish_activity(subject, _verb, label) do
    label = repo().maybe_preload(label, :edge)

    with {:ok, labeler} <-
           ActivityPub.Actor.get_cached(
             pointer:
               subject || e(label, :edge, :subject, nil) || e(label, :edge, :subject_id, nil)
           ),
         {:ok, object} <-
           ActivityPub.Object.get_cached(
             pointer: e(label, :edge, :object, nil) || e(label, :edge, :object_id, nil)
           ) do
      ActivityPub.announce(%{actor: labeler, object: object, pointer: ulid(label)})
    else
      e ->
        error(e, "Could not find the federated actor or object to label.")
    end
  end
end
