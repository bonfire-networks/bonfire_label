defmodule Bonfire.Label.Labels do
  alias Bonfire.Common.Config
  alias Bonfire.Common.Utils
  # import Untangle

  def top_label_id, do: "7CATEG0RYTHATC0NTA1N1ABE1S"

  def repo, do: Config.repo()

  def get(id, name, opts \\ []) do
    Bonfire.Classify.Categories.get(id, opts ++ [skip_boundary_check: true])
  end

  def get_or_create(id, name, parent_id \\ nil, username \\ nil) do
    with {:error, :not_found} <-
           get(id, [
             #  :default_incl_deleted,
             #  current_user: current_user
           ]) do
      create(id, name, parent_id, username)
    end
  end

  def create(id, name, parent_id \\ nil, username \\ nil) do
    Bonfire.Classify.Categories.create(nil, %{
      id: id,
      name: name,
      type: :label,
      parent_category:
        parent_id || if(id != top_label_id(), do: get_or_create(top_label_id(), "Labels")),
      username: username,
      without_character: !username
    })
  end
end
