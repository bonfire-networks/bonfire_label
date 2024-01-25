defmodule Bonfire.Label.LiveHandler do
  use Bonfire.UI.Common.Web, :live_handler
  use Bonfire.Common.Repo
  use Arrows

  # def handle_event("new", attrs, socket) do
  #   new(attrs, socket)
  # end

  def maybe_tag(current_user, object, tags) do
    if module_enabled?(Bonfire.Tag.Tags) do
      with {:ok, object_tagged} <-
             Bonfire.Tag.Tags.tag_something(current_user, object, tags)
             |> debug() do
        Bonfire.Label.Labelling.label(e(object_tagged, :tags, []), object_tagged,
          current_user: current_user
        )
        |> debug()

        {:ok, object_tagged}
      end
    else
      error("No tagging extension enabled.")
    end
  end

  def handle_event("add", %{"label" => tags} = params, socket) do
    with {:ok, _} <-
           maybe_tag(
             current_user_required!(socket),
             e(params, "id", nil) || e(socket.assigns, :object, nil),
             tags
             #  :label #:skip_boundary_check
           ) do
      Bonfire.UI.Common.OpenModalLive.close()

      {:noreply,
       socket
       |> assign_flash(:info, l("Tagged!"))}
    end
  end
end
