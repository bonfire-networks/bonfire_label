defmodule Bonfire.Label.Web.LabelsLive do
  use Bonfire.UI.Common.Web, :surface_live_view

  alias Bonfire.UI.Topics.CategoryLive.SubcategoriesLive
  alias Bonfire.Classify.Web.CommunityLive.CommunityCollectionsLive
  alias Bonfire.Classify.Web.CollectionLive.CollectionResourcesLive

  on_mount {LivePlugs, [Bonfire.UI.Me.LivePlugs.LoadCurrentUser]}

  def mount(params, _session, socket) do
    current_user = current_user(socket.assigns)

    label_category = Bonfire.Label.Labels.top_label_id()

    id =
      if not is_nil(params["id"]) and params["id"] != "" do
        params["id"]
      else
        if not is_nil(params["username"]) and params["username"] != "" do
          params["username"]
        else
          label_category
        end
      end

    {:ok, category} =
      with {:error, :not_found} <-
             Bonfire.Classify.Categories.get(id, [
               :default_incl_deleted,
               current_user: current_user(socket.assigns)
             ]) do
        if id == label_category,
          do: Bonfire.Label.Labels.create(label_category, "Labels"),
          else: Bonfire.Label.Labels.get_or_create(label_category, "Labels")
      end

    # TODO: (query without GraphQL?)
    # subcategories = %{edges: []}
    subcategories =
      Bonfire.Classify.Categories.list([parent_category: category], skip_boundary_check: true)

    # {:ok, subcategories} =
    #   Bonfire.Classify.GraphQL.CategoryResolver.category_children(
    #     %{id: ulid!(category)},
    #     %{limit: 15},
    #     %{context: %{current_user: current_user}}
    #   )
    #   |> debug("subcategories")

    name = e(category, :profile, :name, l("Untitled topic"))
    object_boundary = Bonfire.Boundaries.Controlleds.get_preset_on_object(category)

    {:ok,
     assign(
       socket,
       page: "topics",
       object_type: nil,
       feed: nil,
       without_sidebar: false,
       page_header_aside: [
         {
           Bonfire.Classify.Web.CategoryHeaderAsideLive,
           [category: category]
         }
       ],
       selected_tab: :timeline,
       tab_id: nil,
       #  custom_page_header:
       #    {Bonfire.Classify.Web.CategoryHeaderLive,
       #     category: category, object_boundary: object_boundary},
       category: category,
       canonical_url: canonical_url(category),
       name: name,
       page_title: name,
       interaction_type: l("follow"),
       subcategories: subcategories.edges,
       #  current_context: category,
       #  context_id: ulid(category),
       #  reply_to_id: category,
       object_boundary: object_boundary,
       #  create_object_type: :category,
       sidebar_widgets: [
         users: [
           secondary: [
             {Bonfire.Tag.Web.WidgetTagsLive, []}
           ]
         ],
         guests: [
           secondary: [
             {Bonfire.Tag.Web.WidgetTagsLive, []}
           ]
         ]
       ]
     )}
  end

  def tab(selected_tab) do
    case maybe_to_atom(selected_tab) do
      tab when is_atom(tab) -> tab
      _ -> :timeline
    end

    # |> debug
  end

  def handle_params(%{"tab" => tab, "tab_id" => tab_id}, _url, socket) do
    # debug(id)
    {:noreply,
     assign(socket,
       selected_tab: tab,
       tab_id: tab_id
     )}
  end

  def handle_params(%{"tab" => tab}, _url, socket) do
    {:noreply,
     assign(socket,
       selected_tab: tab
     )}

    # nothing defined
  end

  def handle_params(params, _url, socket) do
    # default tab
    handle_params(
      Map.merge(params || %{}, %{"tab" => "timeline"}),
      nil,
      socket
    )
  end
end
