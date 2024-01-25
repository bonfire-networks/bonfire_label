defmodule Bonfire.Label.Labelling do
  # alias Bonfire.Data.Identity.User
  alias Bonfire.Label
  # alias Bonfire.Boundaries.Verbs

  alias Bonfire.Social.Activities
  alias Bonfire.Social.Edges
  alias Bonfire.Social.Feeds
  # alias Bonfire.Social.FeedActivities
  alias Bonfire.Social.Integration
  alias Bonfire.Social.LivePush
  alias Bonfire.Social.Objects

  # alias Bonfire.Data.Edges.Edge

  use Bonfire.Common.Repo,
    searchable_fields: [:labeler_id, :labelled_id]

  # import Bonfire.Social.Integration
  use Bonfire.Common.Utils

  @behaviour Bonfire.Common.QueryModule
  @behaviour Bonfire.Common.ContextModule
  def schema_module, do: Label
  def query_module, do: __MODULE__

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

  def label(labeler, labelled, opts \\ [])

  def label(%{} = labeler, %{} = object, opts) do
    # if Bonfire.Boundaries.can?(labeler, :label, object) do
    do_label(labeler, object, opts)
    # else
    #   error(l("Sorry, you cannot label this"))
    # end
  end

  def label(%{} = labeler, labelled, opts) when is_binary(labelled) do
    with {:ok, object} <-
           Bonfire.Common.Needles.get(
             labelled,
             opts ++
               [
                 current_user: labeler,
                 #  verbs: [:label]
                 verbs: [:read]
               ]
           ) do
      # debug(liked)
      do_label(labeler, object, opts)
    else
      _ ->
        error(l("Sorry, you cannot label this"))
    end
  end

  def label(labelers, object, opts) when is_list(labelers) do
    labelers
    |> Enum.each(&label(&1, object, opts))
  end

  defp do_label(%{} = labeler, %{} = labelled, opts \\ []) do
    labelled = Objects.preload_creator(labelled)
    labelled_creator = Objects.object_creator(labelled)

    opts = [
      # TODO: get the preset for labeling from config and/or user's settings
      boundary: "public",
      to_circles: [id(labelled_creator)],
      to_feeds:
        [outbox: labeler] ++
          if(e(opts, :notify_creator, true),
            do: Feeds.maybe_creator_notification(labeler, labelled_creator, opts),
            else: []
          )
    ]

    with {:ok, label} <- create(labeler, labelled, opts) do
      # livepush will need a list of feed IDs we published to
      feed_ids = for fp <- label.feed_publishes, do: fp.feed_id

      LivePush.push_activity_object(feed_ids, label, labelled,
        push_to_thread: false,
        notify: true
      )

      Integration.maybe_federate_and_gift_wrap_activity(labeler, label)
      |> debug("maybe_federated the label")
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
